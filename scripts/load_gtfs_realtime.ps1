param(
    [ValidateSet('trip_updates','service_alerts')]
    [string]$FeedType = 'trip_updates',
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc',
    [string]$CsvPath = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CsvPath)) { $CsvPath = Join-Path $repoRoot "data\.cache\$FeedType.csv" }
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "GTFS-Realtime CSV not found: $CsvPath" }

function Get-Value { param([object]$Row, [string]$Name) $p = $Row.PSObject.Properties[$Name]; if ($null -eq $p) { return $null }; return $p.Value }
function To-DbString { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [string]$Value }
function To-DbInt { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [int]$Value }
function To-DbDateTime { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal) }

if ($FeedType -eq 'trip_updates') {
    $tableName = 'RawGtfsTripUpdate'; $targetTable = 'staging.RawGtfsTripUpdate'
    $columns = @(@('ObservedAtUtc',[datetime]),@('TripId',[string]),@('RouteId',[string]),@('VehicleId',[string]),@('StopId',[string]),@('StopSequence',[int]),@('ArrivalTimeUtc',[datetime]),@('DepartureTimeUtc',[datetime]),@('ArrivalDelaySeconds',[int]),@('DepartureDelaySeconds',[int]),@('ScheduleRelationship',[string]),@('SourceId',[string]),@('SourceUrl',[string]),@('Notes',[string]))
} else {
    $tableName = 'RawGtfsServiceAlert'; $targetTable = 'staging.RawGtfsServiceAlert'
    $columns = @(@('ObservedAtUtc',[datetime]),@('AlertId',[string]),@('Cause',[string]),@('Effect',[string]),@('HeaderText',[string]),@('DescriptionText',[string]),@('ActiveStartUtc',[datetime]),@('ActiveEndUtc',[datetime]),@('RouteId',[string]),@('StopId',[string]),@('SourceId',[string]),@('SourceUrl',[string]),@('Notes',[string]))
}

[void]($table = [System.Data.DataTable]::new($tableName))
foreach ($column in $columns) { [void]($dataColumn = $table.Columns.Add($column[0], $column[1])); $dataColumn.AllowDBNull = $true }
foreach ($row in Import-Csv -LiteralPath $CsvPath) {
    [void]($item = $table.NewRow())
    if ($FeedType -eq 'trip_updates') {
        [void]($item.ObservedAtUtc = To-DbDateTime (Get-Value $row 'observed_at_utc')); [void]($item.TripId = To-DbString (Get-Value $row 'trip_id')); [void]($item.RouteId = To-DbString (Get-Value $row 'route_id')); [void]($item.VehicleId = To-DbString (Get-Value $row 'vehicle_id')); [void]($item.StopId = To-DbString (Get-Value $row 'stop_id')); [void]($item.StopSequence = To-DbInt (Get-Value $row 'stop_sequence'))
        [void]($item.ArrivalTimeUtc = To-DbDateTime (Get-Value $row 'arrival_time_utc')); [void]($item.DepartureTimeUtc = To-DbDateTime (Get-Value $row 'departure_time_utc')); [void]($item.ArrivalDelaySeconds = To-DbInt (Get-Value $row 'arrival_delay_seconds')); [void]($item.DepartureDelaySeconds = To-DbInt (Get-Value $row 'departure_delay_seconds')); [void]($item.ScheduleRelationship = To-DbString (Get-Value $row 'schedule_relationship'))
    } else {
        [void]($item.ObservedAtUtc = To-DbDateTime (Get-Value $row 'observed_at_utc')); [void]($item.AlertId = Get-Value $row 'alert_id'); [void]($item.Cause = To-DbString (Get-Value $row 'cause')); [void]($item.Effect = To-DbString (Get-Value $row 'effect')); [void]($item.HeaderText = To-DbString (Get-Value $row 'header_text')); [void]($item.DescriptionText = To-DbString (Get-Value $row 'description_text'))
        [void]($item.ActiveStartUtc = To-DbDateTime (Get-Value $row 'active_start_utc')); [void]($item.ActiveEndUtc = To-DbDateTime (Get-Value $row 'active_end_utc')); [void]($item.RouteId = To-DbString (Get-Value $row 'route_id')); [void]($item.StopId = To-DbString (Get-Value $row 'stop_id'))
    }
    [void]($item.SourceId = Get-Value $row 'source_id'); [void]($item.SourceUrl = To-DbString (Get-Value $row 'source_url')); [void]($item.Notes = To-DbString (Get-Value $row 'notes')); [void]$table.Rows.Add($item)
}

$connectionString = "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString); $connection.Open()
try {
    $bulk = [System.Data.SqlClient.SqlBulkCopy]::new($connection); $bulk.DestinationTableName = $targetTable; $bulk.BatchSize = 1000
    foreach ($column in $table.Columns) { [void]$bulk.ColumnMappings.Add($column.ColumnName, $column.ColumnName) }
    $bulk.WriteToServer($table); $bulk.Close()
}
finally { $connection.Close() }

$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
& $sqlcmd -S $Server -E -d $Database -b -Q 'EXEC warehouse.usp_LoadGtfsRealtime;'
if ($LASTEXITCODE -ne 0) { throw "GTFS-Realtime transform failed with exit code $LASTEXITCODE." }
Write-Output "Loaded $($table.Rows.Count) $FeedType rows."
