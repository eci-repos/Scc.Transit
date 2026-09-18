CREATE OR ALTER VIEW mart.vw_ContextDataStatus
AS
SELECT N'Weather' AS DatasetName, COUNT_BIG(*) AS [RowCount],
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Loaded' ELSE N'Not loaded' END AS Status,
       N'NOAA daily summaries' AS SourceName,
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Available for analysis' ELSE N'Run scripts/load_noaa_weather.ps1' END AS NextAction
FROM mart.vw_WeatherDaily
UNION ALL
SELECT N'Trip performance' AS DatasetName, COUNT_BIG(*) AS [RowCount],
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Loaded' ELSE N'Not loaded' END AS Status,
       N'511 GTFS-Realtime trip updates' AS SourceName,
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Available for analysis' ELSE N'Run fetch_gtfs_realtime.py and load_gtfs_realtime.ps1' END AS NextAction
FROM mart.vw_TripPerformance
UNION ALL
SELECT N'Service alerts' AS DatasetName, COUNT_BIG(*) AS [RowCount],
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Loaded' ELSE N'Not loaded' END AS Status,
       N'511 GTFS-Realtime alerts' AS SourceName,
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Available for analysis' ELSE N'Run fetch_gtfs_realtime.py and load_gtfs_realtime.ps1' END AS NextAction
FROM mart.vw_ServiceAlerts
UNION ALL
SELECT N'Calendar events' AS DatasetName, COUNT_BIG(*) AS [RowCount],
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Loaded' ELSE N'Not loaded' END AS Status,
       N'Calendar event feed' AS SourceName,
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Available for analysis' ELSE N'Load staging.RawCalendarEvent and classify it' END AS NextAction
FROM mart.vw_CalendarEvents
UNION ALL
SELECT N'Traffic incidents' AS DatasetName, COUNT_BIG(*) AS [RowCount],
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Loaded' ELSE N'Not loaded' END AS Status,
       N'Traffic incident feed' AS SourceName,
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Available for analysis' ELSE N'Load staging.RawTrafficIncident and classify it' END AS NextAction
FROM mart.vw_TrafficIncidents
UNION ALL
SELECT N'Air quality' AS DatasetName, COUNT_BIG(*) AS [RowCount],
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Loaded' ELSE N'Not loaded' END AS Status,
       N'Air quality feed' AS SourceName,
       CASE WHEN COUNT_BIG(*) > 0 THEN N'Available for analysis' ELSE N'Load staging.RawAirQualityDaily and classify it' END AS NextAction
FROM mart.vw_AirQualityDaily;
GO
