# SCC Transit POC database

SQL Server dimensional-model POC for Santa Clara County transit data. The project is designed for Visual Studio Code with the SQL Server and SQL Database Projects extensions, and targets the host's default SQL Server instance through Windows authentication.

## Prerequisites

- SQL Server default instance running locally.
- `sqlcmd` available on `PATH`.
- VS Code extensions recommended in `.vscode/extensions.json`.
- PowerShell 7 (`pwsh`).

The defaults are `localhost` and database `SccTransitPoc`. Override them when needed:

```powershell
pwsh -File scripts/load_poc.ps1 -Server 'localhost' -Database 'SccTransitPoc'
```

## Quick start

```powershell
code .
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/load_poc.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate_poc.ps1
```

The load script creates the database if needed, creates the schema, bulk-loads the CSV into staging, and populates the dimensional model. The main dashboard views are:

- `mart.vw_RidershipSummary`
- `mart.vw_GtfsSnapshot`
- `mart.vw_DataQuality`
- `mart.vw_WeatherDaily`

## Weather extension

NOAA-style daily observations can be loaded into `staging.RawWeatherData`. Run `scripts/classify_weather.ps1` to populate `warehouse.FactWeatherDaily` and assign the ordered weather perception class through `warehouse.usp_ClassifyWeatherData`.

For the San José NOAA seed used by the Power BI POC, run `pwsh -File scripts/load_noaa_weather.ps1`. It loads 2024 through the current date from station `USW00023293` and then runs the classifier.

## Transit coordinates and vehicle GPS

The static GTFS loader downloads VTA routes, trips, stops, and shape points into the database:

```powershell
pwsh -File scripts/load_gtfs_static.ps1
```

The resulting dashboard views are `mart.vw_GtfsStops` and `mart.vw_GtfsRouteShapes`.

For live vehicle positions, install the optional parser dependency and fetch the GTFS-Realtime feed:

```powershell
python -m pip install -r requirements-gtfs.txt
python scripts/fetch_vehicle_positions.py --api-key '<511_API_KEY>'
pwsh -File scripts/load_vehicle_positions.ps1
```

The latest vehicle location view is `mart.vw_VehiclePositionsLatest`. These are vehicle coordinates, not individual rider GPS traces.

GTFS-Realtime trip updates and service alerts can be fetched with a 511 API key:

```powershell
python scripts/fetch_gtfs_realtime.py --feed-type trip_updates --api-key '<511_API_KEY>'
pwsh -File scripts/load_gtfs_realtime.ps1 -FeedType trip_updates
python scripts/fetch_gtfs_realtime.py --feed-type service_alerts --api-key '<511_API_KEY>'
pwsh -File scripts/load_gtfs_realtime.ps1 -FeedType service_alerts
```

The dashboard views are `mart.vw_TripPerformance` and `mart.vw_ServiceAlerts`.

The model also includes optional context views for future loads: `mart.vw_CalendarEvents`, `mart.vw_TrafficIncidents`, and `mart.vw_AirQualityDaily`.

## Project layout

```text
Scc.Transit.Database.sqlproj  SQL Database Project schema entry point
database/schemas/             Schemas, tables, dimensions, facts, and views
database/etl/                 Repeatable reset and transformation SQL
database/setup/               Local database bootstrap SQL
data/                         POC input data and refresh instructions
docs/                         Data model notes
scripts/                      CSV refresh, database load, and validation scripts
.vscode/                      Recommended extensions, settings, and tasks
```

The SQL project intentionally includes only deployable schema objects. ETL and local bootstrap scripts remain separate so a future CI/CD pipeline can control them explicitly.
