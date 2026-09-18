param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc',
    [string]$FeedUrl = 'https://gtfs.vta.org/gtfs_vta.zip',
    [string]$SourceId = 'vta_gtfs_static_current'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$cacheRoot = Join-Path $repoRoot 'data\.cache\vta_gtfs'
$zipPath = Join-Path $cacheRoot 'gtfs_vta.zip'
$extractPath = Join-Path $cacheRoot 'extract'

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
Invoke-WebRequest -Uri $FeedUrl -OutFile $zipPath
if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

foreach ($requiredFile in 'routes.txt', 'trips.txt', 'stops.txt', 'shapes.txt') {
    if (-not (Test-Path -LiteralPath (Join-Path $extractPath $requiredFile))) { throw "Required GTFS file is missing: $requiredFile" }
}

function Get-CsvValue { param([object]$Row, [string]$Column) [void]($property = $Row.PSObject.Properties[$Column]); if ($null -eq $property) { return $null }; return $property.Value }
function To-NullableString { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [string]$Value }
function To-NullableInt { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [int]$Value }
function To-NullableDecimal { param([object]$Value) if ([string]::IsNullOrWhiteSpace([string]$Value)) { return [DBNull]::Value } return [decimal]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture) }

function New-RouteTable {
    [void]($table = [System.Data.DataTable]::new('RawGtfsRoute'))
    foreach ($column in @(@('SourceId',[string]),@('SourceUrl',[string]),@('RouteId',[string]),@('RouteShortName',[string]),@('RouteLongName',[string]),@('RouteType',[int]),@('RouteUrl',[string]),@('RouteColor',[string]),@('RouteTextColor',[string]))) { [void]($dataColumn = $table.Columns.Add($column[0], $column[1])); $dataColumn.AllowDBNull = $true }
    foreach ($row in Import-Csv (Join-Path $extractPath 'routes.txt')) {
        [void]($item = $table.NewRow()); [void]($item.SourceId = $SourceId); [void]($item.SourceUrl = $FeedUrl)
        [void]($item.RouteId = Get-CsvValue $row 'route_id'); [void]($item.RouteShortName = To-NullableString (Get-CsvValue $row 'route_short_name')); [void]($item.RouteLongName = To-NullableString (Get-CsvValue $row 'route_long_name'))
        [void]($item.RouteType = To-NullableInt (Get-CsvValue $row 'route_type')); [void]($item.RouteUrl = To-NullableString (Get-CsvValue $row 'route_url')); [void]($item.RouteColor = To-NullableString (Get-CsvValue $row 'route_color')); [void]($item.RouteTextColor = To-NullableString (Get-CsvValue $row 'route_text_color'))
        [void]$table.Rows.Add($item)
    }
    return ,$table
}

function New-TripTable {
    [void]($table = [System.Data.DataTable]::new('RawGtfsTrip'))
    foreach ($column in @(@('SourceId',[string]),@('SourceUrl',[string]),@('RouteId',[string]),@('ServiceId',[string]),@('TripId',[string]),@('TripHeadsign',[string]),@('DirectionId',[int]),@('ShapeId',[string]))) { [void]($dataColumn = $table.Columns.Add($column[0], $column[1])); $dataColumn.AllowDBNull = $true }
    foreach ($row in Import-Csv (Join-Path $extractPath 'trips.txt')) {
        [void]($item = $table.NewRow()); [void]($item.SourceId = $SourceId); [void]($item.SourceUrl = $FeedUrl)
        [void]($item.RouteId = Get-CsvValue $row 'route_id'); [void]($item.ServiceId = To-NullableString (Get-CsvValue $row 'service_id')); [void]($item.TripId = Get-CsvValue $row 'trip_id'); [void]($item.TripHeadsign = To-NullableString (Get-CsvValue $row 'trip_headsign'))
        [void]($item.DirectionId = To-NullableInt (Get-CsvValue $row 'direction_id')); [void]($item.ShapeId = To-NullableString (Get-CsvValue $row 'shape_id'))
        [void]$table.Rows.Add($item)
    }
    return ,$table
}

function New-StopTable {
    [void]($table = [System.Data.DataTable]::new('RawGtfsStop'))
    foreach ($column in @(@('SourceId',[string]),@('SourceUrl',[string]),@('StopId',[string]),@('StopCode',[string]),@('StopName',[string]),@('StopLat',[decimal]),@('StopLon',[decimal]),@('LocationType',[int]),@('ParentStation',[string]),@('WheelchairBoarding',[int]))) { [void]($dataColumn = $table.Columns.Add($column[0], $column[1])); $dataColumn.AllowDBNull = $true }
    foreach ($row in Import-Csv (Join-Path $extractPath 'stops.txt')) {
        [void]($item = $table.NewRow()); [void]($item.SourceId = $SourceId); [void]($item.SourceUrl = $FeedUrl)
        [void]($item.StopId = Get-CsvValue $row 'stop_id'); [void]($item.StopCode = To-NullableString (Get-CsvValue $row 'stop_code')); [void]($item.StopName = To-NullableString (Get-CsvValue $row 'stop_name')); [void]($item.StopLat = To-NullableDecimal (Get-CsvValue $row 'stop_lat')); [void]($item.StopLon = To-NullableDecimal (Get-CsvValue $row 'stop_lon'))
        [void]($item.LocationType = To-NullableInt (Get-CsvValue $row 'location_type')); [void]($item.ParentStation = To-NullableString (Get-CsvValue $row 'parent_station')); [void]($item.WheelchairBoarding = To-NullableInt (Get-CsvValue $row 'wheelchair_boarding'))
        [void]$table.Rows.Add($item)
    }
    return ,$table
}

function New-ShapeTable {
    [void]($table = [System.Data.DataTable]::new('RawGtfsShapePoint'))
    foreach ($column in @(@('SourceId',[string]),@('SourceUrl',[string]),@('ShapeId',[string]),@('ShapePointLat',[decimal]),@('ShapePointLon',[decimal]),@('ShapePointSequence',[int]),@('ShapeDistTraveled',[decimal]))) { [void]($dataColumn = $table.Columns.Add($column[0], $column[1])); $dataColumn.AllowDBNull = $true }
    foreach ($row in Import-Csv (Join-Path $extractPath 'shapes.txt')) {
        [void]($item = $table.NewRow()); [void]($item.SourceId = $SourceId); [void]($item.SourceUrl = $FeedUrl)
        [void]($item.ShapeId = Get-CsvValue $row 'shape_id'); [void]($item.ShapePointLat = To-NullableDecimal (Get-CsvValue $row 'shape_pt_lat')); [void]($item.ShapePointLon = To-NullableDecimal (Get-CsvValue $row 'shape_pt_lon')); [void]($item.ShapePointSequence = To-NullableInt (Get-CsvValue $row 'shape_pt_sequence')); [void]($item.ShapeDistTraveled = To-NullableDecimal (Get-CsvValue $row 'shape_dist_traveled'))
        [void]$table.Rows.Add($item)
    }
    return ,$table
}

$connectionString = "Server=$Server;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
$connection.Open()
try {
    $cleanup = $connection.CreateCommand()
    $cleanup.CommandText = @'
DELETE f FROM warehouse.FactGtfsShapePoint AS f JOIN warehouse.DimDataSource AS d ON d.DataSourceKey = f.DataSourceKey WHERE d.SourceId = @SourceId;
DELETE FROM warehouse.DimGtfsRoute WHERE DataSourceKey IN (SELECT DataSourceKey FROM warehouse.DimDataSource WHERE SourceId = @SourceId);
DELETE FROM warehouse.DimGtfsStop WHERE DataSourceKey IN (SELECT DataSourceKey FROM warehouse.DimDataSource WHERE SourceId = @SourceId);
DELETE FROM staging.RawGtfsRoute WHERE SourceId = @SourceId;
DELETE FROM staging.RawGtfsTrip WHERE SourceId = @SourceId;
DELETE FROM staging.RawGtfsStop WHERE SourceId = @SourceId;
DELETE FROM staging.RawGtfsShapePoint WHERE SourceId = @SourceId;
'@
    [void]$cleanup.Parameters.Add('@SourceId', [System.Data.SqlDbType]::NVarChar, 200)
    $cleanup.Parameters['@SourceId'].Value = $SourceId
    [void]$cleanup.ExecuteNonQuery()

    $tables = @((New-RouteTable), (New-TripTable), (New-StopTable), (New-ShapeTable))
    foreach ($table in $tables) {
        $bulk = [System.Data.SqlClient.SqlBulkCopy]::new($connection)
        $bulk.DestinationTableName = "staging.$($table.TableName)"
        $bulk.BatchSize = 2000
        foreach ($column in $table.Columns) { [void]$bulk.ColumnMappings.Add($column.ColumnName, $column.ColumnName) }
        $bulk.WriteToServer($table)
        Write-Output "Loaded $($table.Rows.Count) rows into staging.$($table.TableName)."
        $bulk.Close()
    }
}
finally { $connection.Close() }

$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
& $sqlcmd -S $Server -E -d $Database -b -Q 'EXEC warehouse.usp_LoadGtfsStatic;'
if ($LASTEXITCODE -ne 0) { throw "GTFS static transform failed with exit code $LASTEXITCODE." }

& $sqlcmd -S $Server -E -d $Database -b -W -s ' | ' -Q "SELECT '$SourceId' AS SourceId, (SELECT COUNT_BIG(*) FROM warehouse.DimGtfsStop AS s JOIN warehouse.DimDataSource AS d ON d.DataSourceKey = s.DataSourceKey WHERE d.SourceId = '$SourceId') AS StopCount, (SELECT COUNT_BIG(*) FROM warehouse.FactGtfsShapePoint AS p JOIN warehouse.DimDataSource AS d ON d.DataSourceKey = p.DataSourceKey WHERE d.SourceId = '$SourceId') AS ShapePointCount;"
if ($LASTEXITCODE -ne 0) { throw "GTFS static validation failed with exit code $LASTEXITCODE." }
