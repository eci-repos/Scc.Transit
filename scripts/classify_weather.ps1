param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc',
    [switch]$ReloadAll
)

$ErrorActionPreference = 'Stop'
$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
$reloadValue = if ($ReloadAll) { 1 } else { 0 }
$query = "EXEC warehouse.usp_ClassifyWeatherData @ReloadAll = $reloadValue; SELECT COUNT_BIG(*) AS WeatherFactCount FROM warehouse.FactWeatherDaily;"

& $sqlcmd -S $Server -E -d $Database -b -W -s ' | ' -Q $query
if ($LASTEXITCODE -ne 0) { throw "Weather classification failed with exit code $LASTEXITCODE." }
