param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source

function Invoke-SqlFile {
    param([string]$Path)
    & $sqlcmd -S $Server -E -d $Database -b -i $Path
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed for $Path with exit code $LASTEXITCODE." }
}

& $sqlcmd -S $Server -E -b -i (Join-Path $repoRoot 'database\setup\CreateDatabase.sql')
if ($LASTEXITCODE -ne 0) { throw "Unable to create or locate database $Database." }

foreach ($file in Get-ChildItem (Join-Path $repoRoot 'database\schemas') -Filter '*.sql' | Sort-Object Name) {
    if ($file.Name -eq '00_schemas.sql') {
        $schemaCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN SCHEMA_ID(N'staging') IS NOT NULL AND SCHEMA_ID(N'warehouse') IS NOT NULL AND SCHEMA_ID(N'mart') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing database schemas.' }
        if (($schemaCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Database schemas already exist; skipping schema creation.'
            continue
        }
    }
    if ($file.Name -eq '10_tables.sql') {
        $tableCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'staging.RawTransitData', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.FactTransitMetric', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.FactGtfsSnapshot', N'U') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw "Unable to inspect existing database tables." }
        if (($tableCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Database tables already exist; skipping table creation.'
            continue
        }
    }
    if ($file.Name -eq '20_views.sql') {
        $viewCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'mart.vw_RidershipSummary', N'V') IS NOT NULL AND OBJECT_ID(N'mart.vw_GtfsSnapshot', N'V') IS NOT NULL AND OBJECT_ID(N'mart.vw_DataQuality', N'V') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing database views.' }
        if (($viewCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Database views already exist; skipping view creation.'
            continue
        }
    }
    if ($file.Name -eq '30_weather.sql') {
        $weatherTableCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'staging.RawWeatherData', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.FactWeatherDaily', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.DimWeatherPerception', N'U') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing weather tables.' }
        if (($weatherTableCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Weather tables already exist; skipping weather table creation.'
            continue
        }
    }
    if ($file.Name -eq '40_procedures.sql') {
        $procedureCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'warehouse.usp_ClassifyWeatherData', N'P') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing weather procedure.' }
        if (($procedureCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Weather procedure already exists; skipping procedure creation.'
            continue
        }
    }
    if ($file.Name -eq '50_weather_views.sql') {
        $weatherViewCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'mart.vw_WeatherDaily', N'V') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing weather view.' }
        if (($weatherViewCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Weather view already exists; skipping view creation.'
            continue
        }
    }
    if ($file.Name -eq '60_gtfs.sql') {
        $gtfsTableCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'staging.RawGtfsRoute', N'U') IS NOT NULL AND OBJECT_ID(N'staging.RawVehiclePosition', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.FactGtfsShapePoint', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.FactVehiclePosition', N'U') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing GTFS tables.' }
        if (($gtfsTableCheck | Out-String).Trim() -eq '1') {
            Write-Output 'GTFS tables already exist; skipping GTFS table creation.'
            continue
        }
    }
    if ($file.Name -eq '70_gtfs_views.sql') {
        $gtfsViewCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'mart.vw_GtfsStops', N'V') IS NOT NULL AND OBJECT_ID(N'mart.vw_GtfsRouteShapes', N'V') IS NOT NULL AND OBJECT_ID(N'mart.vw_VehiclePositionsLatest', N'V') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing GTFS views.' }
        if (($gtfsViewCheck | Out-String).Trim() -eq '1') {
            Write-Output 'GTFS views already exist; skipping GTFS view creation.'
            continue
        }
    }
    if ($file.Name -eq '80_gtfs_procedures.sql') {
        $gtfsProcedureCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'warehouse.usp_LoadGtfsStatic', N'P') IS NOT NULL AND OBJECT_ID(N'warehouse.usp_LoadVehiclePositions', N'P') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing GTFS procedures.' }
        if (($gtfsProcedureCheck | Out-String).Trim() -eq '1') {
            Write-Output 'GTFS procedures already exist; skipping procedure creation.'
            continue
        }
    }
    if ($file.Name -eq '90_realtime.sql') {
        $realtimeCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'staging.RawGtfsTripUpdate', N'U') IS NOT NULL AND OBJECT_ID(N'staging.RawGtfsServiceAlert', N'U') IS NOT NULL AND OBJECT_ID(N'warehouse.usp_LoadGtfsRealtime', N'P') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing realtime objects.' }
        if (($realtimeCheck | Out-String).Trim() -eq '1') {
            Write-Output 'GTFS-Realtime objects already exist; skipping realtime schema creation.'
            continue
        }
    }
    if ($file.Name -eq '95_context.sql') {
        $contextCheck = & $sqlcmd -S $Server -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN OBJECT_ID(N'staging.RawCalendarEvent', N'U') IS NOT NULL AND OBJECT_ID(N'staging.RawTrafficIncident', N'U') IS NOT NULL AND OBJECT_ID(N'staging.RawAirQualityDaily', N'U') IS NOT NULL THEN 1 ELSE 0 END;"
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect existing context objects.' }
        if (($contextCheck | Out-String).Trim() -eq '1') {
            Write-Output 'Calendar, traffic, and air-quality objects already exist; skipping context schema creation.'
            continue
        }
    }
    Invoke-SqlFile -Path $file.FullName
}

Write-Output "Database schema is ready: $Server/$Database"
