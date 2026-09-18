param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc',
    [string]$StationId = 'USW00023293',
    [string]$StationName = 'San Jose International Airport',
    [datetime]$StartDate = [datetime]'2024-01-01',
    [datetime]$EndDate = [datetime]::Today
)

$ErrorActionPreference = 'Stop'
$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
$startText = $StartDate.ToString('yyyy-MM-dd')
$endText = $EndDate.ToString('yyyy-MM-dd')
$sourceId = "noaa_daily_summaries_$($StationId.ToLowerInvariant())"
$url = "https://www.ncei.noaa.gov/access/services/data/v1?dataset=daily-summaries&stations=$StationId&startDate=$startText&endDate=$endText&format=json&units=standard&includeAttributes=false"

function Sql-Text([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'NULL' }
    return "N'" + $Value.Replace("'", "''") + "'"
}

function Sql-Number([object]$Value, [int]$Scale = 2) {
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'NULL' }
    $number = 0.0
    if (-not [double]::TryParse(([string]$Value).Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) { return 'NULL' }
    return $number.ToString("0.$(('0' * $Scale))", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-Value($Row, [string]$Name) {
    $property = $Row.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

Write-Output "Fetching NOAA daily summaries for $StationId from $startText through $endText..."
$response = Invoke-RestMethod -Uri $url -TimeoutSec 120
$rows = @($response | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-Value $_ 'DATE')) })
if ($rows.Count -eq 0) { throw 'NOAA returned no daily observations for the requested range.' }

$sql = [System.Collections.Generic.List[string]]::new()
$sql.Add('SET NOCOUNT ON;')
$sql.Add('SET XACT_ABORT ON;')
$sql.Add('BEGIN TRANSACTION;')
$sql.Add("DELETE FROM staging.RawWeatherData WHERE StationId = $(Sql-Text $StationId) AND ObservationDate BETWEEN '$startText' AND '$endText';")

foreach ($row in $rows) {
    $date = [datetime](Get-Value $row 'DATE')
    $dateText = $date.ToString('yyyy-MM-dd')
    $tmin = Get-Value $row 'TMIN'
    $tmax = Get-Value $row 'TMAX'
    $tavg = Get-Value $row 'TAVG'
    if ([string]::IsNullOrWhiteSpace([string]$tavg) -and $null -ne $tmin -and $null -ne $tmax) {
        $tavg = (([double]$tmin + [double]$tmax) / 2.0).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)
    }

    $thunder = if ([string]::IsNullOrWhiteSpace([string](Get-Value $row 'WT03'))) { 0 } else { 1 }
    $condition = if ($thunder -eq 1) { 'Thunderstorm' }
        elseif (-not [string]::IsNullOrWhiteSpace([string](Get-Value $row 'WT01'))) { 'Fog' }
        elseif (-not [string]::IsNullOrWhiteSpace([string](Get-Value $row 'WT08'))) { 'Smoke/haze' }
        elseif (([double]($(if ($null -eq (Get-Value $row 'PRCP')) { 0 } else { Get-Value $row 'PRCP' }))) -gt 0) { 'Rain' }
        else { 'Clear/other' }

    $sql.Add(("INSERT INTO staging.RawWeatherData (ObservationDate, StationId, StationName, TemperatureAvgF, TemperatureMinF, TemperatureMaxF, PrecipitationInches, WindSpeedMph, VisibilityMiles, WeatherCondition, IsThunderstorm, SourceId, SourceUrl, Notes) VALUES ('{0}', {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}, {10}, {11}, {12}, {13});" -f `
        $dateText,
        (Sql-Text $StationId),
        (Sql-Text $StationName),
        (Sql-Number $tavg 2),
        (Sql-Number $tmin 2),
        (Sql-Number $tmax 2),
        (Sql-Number (Get-Value $row 'PRCP') 3),
        (Sql-Number (Get-Value $row 'AWND') 2),
        (Sql-Number (Get-Value $row 'VISIB') 2),
        (Sql-Text $condition),
        $thunder,
        (Sql-Text $sourceId),
        (Sql-Text $url),
        (Sql-Text "NOAA NCEI daily summaries; station $StationId.")))
}

$sql.Add('EXEC warehouse.usp_ClassifyWeatherData @ReloadAll = 0;')
$sql.Add('COMMIT TRANSACTION;')
$sql.Add("SELECT 'RawWeatherData' AS ObjectName, COUNT_BIG(*) AS [Rows] FROM staging.RawWeatherData WHERE StationId = $(Sql-Text $StationId) AND ObservationDate BETWEEN '$startText' AND '$endText';")
$sql.Add("SELECT 'WeatherView' AS ObjectName, COUNT_BIG(*) AS [Rows] FROM mart.vw_WeatherDaily WHERE StationId = $(Sql-Text $StationId) AND ObservationDate BETWEEN '$startText' AND '$endText';")

$tempSql = Join-Path ([IO.Path]::GetTempPath()) ("scc-transit-noaa-weather-{0}.sql" -f [guid]::NewGuid().ToString('N'))
try {
    [IO.File]::WriteAllLines($tempSql, $sql)
    & $sqlcmd -S $Server -E -d $Database -b -W -s ' | ' -i $tempSql
    if ($LASTEXITCODE -ne 0) { throw "NOAA weather load failed with exit code $LASTEXITCODE." }
}
finally {
    if (Test-Path -LiteralPath $tempSql) { Remove-Item -LiteralPath $tempSql -Force }
}
