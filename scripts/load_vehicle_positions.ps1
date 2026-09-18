param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc',
    [string]$CsvPath = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CsvPath)) { $CsvPath = Join-Path $repoRoot 'data\.cache\vehicle_positions.csv' }
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "Vehicle position CSV not found: $CsvPath" }

function Get-Value { param([object]$Row, [string]$Name) $p = $Row.PSObject.Properties[$Name]; if ($null -eq $p) { return $null }; return $p.Value }
function To-DbString { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [string]$Value }
function To-DbInt { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [int]$Value }
function To-DbDecimal { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [decimal]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture) }
function To-DbDateTime { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal) }

$table = [System.Data.DataTable]::new('RawVehiclePosition')
foreach ($column in @(@('ObservedAtUtc',[datetime]),@('VehicleId',[string]),@('TripId',[string]),@('RouteId',[string]),@('Latitude',[decimal]),@('Longitude',[decimal]),@('Bearing',[decimal]),@('SpeedMph',[decimal]),@('CurrentStopSequence',[int]),@('CurrentStatus',[string]),@('OccupancyStatus',[string]),@('SourceId',[string]),@('SourceUrl',[string]),@('Notes',[string]))) { $dataColumn = $table.Columns.Add($column[0], $column[1]); $dataColumn.AllowDBNull = $true }
foreach ($row in Import-Csv -LiteralPath $CsvPath) {
    $item = $table.NewRow()
    $item.ObservedAtUtc = To-DbDateTime (Get-Value $row 'observed_at_utc'); $item.VehicleId = Get-Value $row 'vehicle_id'; $item.TripId = To-DbString (Get-Value $row 'trip_id'); $item.RouteId = To-DbString (Get-Value $row 'route_id')
    $item.Latitude = To-DbDecimal (Get-Value $row 'latitude'); $item.Longitude = To-DbDecimal (Get-Value $row 'longitude'); $item.Bearing = To-DbDecimal (Get-Value $row 'bearing'); $item.SpeedMph = To-DbDecimal (Get-Value $row 'speed_mph')
    $item.CurrentStopSequence = To-DbInt (Get-Value $row 'current_stop_sequence'); $item.CurrentStatus = To-DbString (Get-Value $row 'current_status'); $item.OccupancyStatus = To-DbString (Get-Value $row 'occupancy_status')
    $item.SourceId = Get-Value $row 'source_id'; $item.SourceUrl = To-DbString (Get-Value $row 'source_url'); $item.Notes = To-DbString (Get-Value $row 'notes')
    $table.Rows.Add($item)
}

$connectionString = "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
$connection.Open()
try {
    $bulk = [System.Data.SqlClient.SqlBulkCopy]::new($connection)
    $bulk.DestinationTableName = 'staging.RawVehiclePosition'; $bulk.BatchSize = 1000
    foreach ($column in $table.Columns) { [void]$bulk.ColumnMappings.Add($column.ColumnName, $column.ColumnName) }
    $bulk.WriteToServer($table); $bulk.Close()
}
finally { $connection.Close() }

$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
& $sqlcmd -S $Server -E -d $Database -b -Q 'EXEC warehouse.usp_LoadVehiclePositions;'
if ($LASTEXITCODE -ne 0) { throw "Vehicle position transform failed with exit code $LASTEXITCODE." }
Write-Output "Loaded $($table.Rows.Count) vehicle positions."
