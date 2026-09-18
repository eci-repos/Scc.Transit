INSERT INTO warehouse.FactTransitMetric
(
    RecordType, PeriodStartDateKey, PeriodEndDateKey, OperatorKey, ServiceKey,
    RouteKey, LineTypeKey, DayTypeKey, DataSourceKey, MetricName, MetricValue,
    UnitName, DataStatus, Notes
)
SELECT
    s.RecordType,
    CONVERT(int, CONVERT(char(8), s.PeriodStart, 112)),
    CONVERT(int, CONVERT(char(8), s.PeriodEnd, 112)),
    o.OperatorKey,
    sv.ServiceKey,
    r.RouteKey,
    lt.LineTypeKey,
    dt.DayTypeKey,
    src.DataSourceKey,
    COALESCE(NULLIF(s.MetricName, N''), N'unknown'),
    s.MetricValue,
    s.UnitName,
    s.DataStatus,
    s.Notes
FROM staging.RawTransitData AS s
JOIN warehouse.DimOperator AS o ON o.OperatorCode = COALESCE(NULLIF(s.OperatorName, N''), N'UNKNOWN')
JOIN warehouse.DimService AS sv ON sv.ServiceName = COALESCE(NULLIF(s.ServiceName, N''), N'Unknown service')
JOIN warehouse.DimRoute AS r ON r.RouteNaturalKey = COALESCE(NULLIF(s.RouteId, N''), N'UNKNOWN')
JOIN warehouse.DimLineType AS lt ON lt.LineTypeName = COALESCE(NULLIF(s.LineType, N''), N'Unknown line type')
JOIN warehouse.DimDayType AS dt ON dt.DayTypeName = COALESCE(NULLIF(s.DayType, N''), N'Unknown day type')
JOIN warehouse.DimDataSource AS src ON src.SourceId = COALESCE(NULLIF(s.SourceId, N''), N'UNKNOWN')
WHERE s.RecordType IN (N'route_month_daytype', N'route_year_daytype', N'system_ridership');
GO

INSERT INTO warehouse.FactGtfsSnapshot
(
    PeriodStartDateKey, PeriodEndDateKey, OperatorKey, ServiceKey, DataSourceKey,
    MetricName, MetricValue, UnitName, DataStatus, Notes
)
SELECT
    CONVERT(int, CONVERT(char(8), s.PeriodStart, 112)),
    CONVERT(int, CONVERT(char(8), s.PeriodEnd, 112)),
    o.OperatorKey,
    sv.ServiceKey,
    src.DataSourceKey,
    s.MetricName,
    s.MetricValue,
    s.UnitName,
    s.DataStatus,
    s.Notes
FROM staging.RawTransitData AS s
JOIN warehouse.DimOperator AS o ON o.OperatorCode = COALESCE(NULLIF(s.OperatorName, N''), N'UNKNOWN')
JOIN warehouse.DimService AS sv ON sv.ServiceName = COALESCE(NULLIF(s.ServiceName, N''), N'Unknown service')
JOIN warehouse.DimDataSource AS src ON src.SourceId = COALESCE(NULLIF(s.SourceId, N''), N'UNKNOWN')
WHERE s.RecordType = N'gtfs_snapshot';
GO
