# Dimensional model

The SQL Server project uses a three-layer shape:

1. `staging.RawTransitData` preserves the normalized CSV rows as landed.
2. `warehouse` contains conformed dimensions and facts.
3. `mart` exposes dashboard-friendly views.

## Fact grains

- `warehouse.FactTransitMetric`: one source row for a ridership metric by record type, period, operator, service, route, line type, day type, and source.
- `warehouse.FactGtfsSnapshot`: one GTFS snapshot metric by validity window, operator, service, and source.
- `warehouse.FactWeatherDaily`: one daily weather observation per station and source, with numeric measurements and a derived human-perception class.
- `warehouse.DimGtfsStop` and `mart.vw_GtfsStops`: stop locations and accessibility-related GTFS attributes.
- `warehouse.FactGtfsShapePoint` and `mart.vw_GtfsRouteShapes`: ordered route geometry for mapping.
- `warehouse.FactVehiclePosition` and `mart.vw_VehiclePositionsLatest`: real-time vehicle coordinates, not rider-level GPS.
- `warehouse.FactGtfsTripUpdate` and `mart.vw_TripPerformance`: observed arrival/departure updates and delay seconds.
- `warehouse.FactGtfsServiceAlert` and `mart.vw_ServiceAlerts`: disruptions, detours, cancellations, and stop/route alerts.
- `warehouse.FactCalendarEvent`, `FactTrafficIncident`, and `FactAirQualityDaily`: optional contextual drivers for ridership analysis.

## Weather classification

`warehouse.usp_ClassifyWeatherData` assigns a small ordered class set: heavy rain/storm, foggy/low visibility, damp/light rain, rainy, cold and breezy, cold and calm, cool/comfortable, warm and breezy, warm/comfortable, hot and dry, and unknown. Severe precipitation, storms, and low visibility take precedence over temperature-based labels.

Load NOAA-style rows into `staging.RawWeatherData`, then run:

```powershell
pwsh -File scripts/classify_weather.ps1
```

The dashboard view is `mart.vw_WeatherDaily`. Raw measurements remain in the fact table so the thresholds can be revised without losing the source values.

## Important POC assumptions

- The 2026 ridership rows are partial-year data and retain their `DataStatus`.
- VTA ArcGIS route-level values are preserved as published; validate their aggregation semantics before using them as executive KPIs.
- `SYSTEM` and `UNKNOWN` are intentional dimension members for dashboard filtering and incomplete source rows.
