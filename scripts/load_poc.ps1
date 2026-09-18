param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc',
    [string]$CsvPath = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CsvPath)) {
    $CsvPath = Join-Path $repoRoot 'data\scc_transit_poc_2024_2026.csv'
}
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "CSV not found: $CsvPath" }

& (Join-Path $PSScriptRoot 'bootstrap_database.ps1') -Server $Server -Database $Database

$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
$connectionString = "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
$connection.Open()
try {
    $reset = $connection.CreateCommand()
    $reset.CommandText = @'
DELETE FROM warehouse.FactGtfsSnapshot;
DELETE FROM warehouse.FactTransitMetric;
DELETE FROM warehouse.DimDataSource;
DELETE FROM warehouse.DimDayType;
DELETE FROM warehouse.DimLineType;
DELETE FROM warehouse.DimRoute;
DELETE FROM warehouse.DimService;
DELETE FROM warehouse.DimOperator;
DELETE FROM warehouse.DimDate;
TRUNCATE TABLE staging.RawTransitData;
'@
    [void]$reset.ExecuteNonQuery()

    $table = [System.Data.DataTable]::new('RawTransitData')
    $columnTypes = [ordered]@{
        RecordType = [string]
        DataYear = [int]
        PeriodStart = [datetime]
        PeriodEnd = [datetime]
        OperatorName = [string]
        ServiceName = [string]
        RouteId = [string]
        LineType = [string]
        DayType = [string]
        MetricName = [string]
        MetricValue = [decimal]
        UnitName = [string]
        DataStatus = [string]
        SourceUrl = [string]
        SourceId = [string]
        Notes = [string]
    }
    foreach ($entry in $columnTypes.GetEnumerator()) {
        $dataColumn = $table.Columns.Add($entry.Key, $entry.Value)
        $dataColumn.AllowDBNull = $true
    }

    foreach ($csvRow in Import-Csv -LiteralPath $CsvPath) {
        $dataRow = $table.NewRow()
        $dataRow.RecordType = $csvRow.record_type
        $dataRow.DataYear = if ([string]::IsNullOrWhiteSpace($csvRow.year)) { [DBNull]::Value } else { [int]$csvRow.year }
        $dataRow.PeriodStart = if ([string]::IsNullOrWhiteSpace($csvRow.period_start)) { [DBNull]::Value } else { [datetime]$csvRow.period_start }
        $dataRow.PeriodEnd = if ([string]::IsNullOrWhiteSpace($csvRow.period_end)) { [DBNull]::Value } else { [datetime]$csvRow.period_end }
        $csvColumnByDataColumn = @{
            OperatorName = 'operator'
            ServiceName = 'service'
            RouteId = 'route_id'
            LineType = 'line_type'
            DayType = 'day_type'
            MetricName = 'metric'
            UnitName = 'unit'
            DataStatus = 'data_status'
            SourceUrl = 'source_url'
            SourceId = 'source_id'
            Notes = 'notes'
        }
        foreach ($name in $csvColumnByDataColumn.Keys) {
            $sourceName = $csvColumnByDataColumn[$name]
            $sourceValue = $csvRow.PSObject.Properties[$sourceName].Value
            $dataRow.$name = if ([string]::IsNullOrWhiteSpace($sourceValue)) { [DBNull]::Value } else { $sourceValue }
        }
        $dataRow.MetricValue = if ([string]::IsNullOrWhiteSpace($csvRow.metric_value)) { [DBNull]::Value } else { [decimal]$csvRow.metric_value }
        $table.Rows.Add($dataRow)
    }

    $bulkCopy = [System.Data.SqlClient.SqlBulkCopy]::new($connection)
    $bulkCopy.DestinationTableName = 'staging.RawTransitData'
    $bulkCopy.BatchSize = 1000
    foreach ($column in $columnTypes.Keys) { [void]$bulkCopy.ColumnMappings.Add($column, $column) }
    $bulkCopy.WriteToServer($table)
    $bulkCopy.Close()
    Write-Output "Loaded $($table.Rows.Count) rows into staging.RawTransitData."
}
finally {
    $connection.Close()
}

foreach ($fileName in '10_load_dimensions.sql', '20_load_facts.sql') {
    $filePath = Join-Path $repoRoot "database\etl\$fileName"
    & $sqlcmd -S $Server -E -d $Database -b -i $filePath
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed for $fileName with exit code $LASTEXITCODE." }
}

Write-Output "POC database load completed: $Server/$Database"
