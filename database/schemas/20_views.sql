CREATE VIEW mart.vw_RidershipSummary
AS
SELECT
    d.CalendarYear,
    d.FullDate AS PeriodStartDate,
    de.FullDate AS PeriodEndDate,
    o.OperatorName,
    s.ServiceName,
    r.RouteNaturalKey AS RouteId,
    lt.LineTypeName,
    dt.DayTypeName,
    f.RecordType,
    f.MetricName,
    f.MetricValue,
    f.UnitName,
    f.DataStatus,
    src.SourceId,
    src.SourceUrl,
    f.Notes
FROM warehouse.FactTransitMetric AS f
JOIN warehouse.DimDate AS d ON d.DateKey = f.PeriodStartDateKey
JOIN warehouse.DimDate AS de ON de.DateKey = f.PeriodEndDateKey
JOIN warehouse.DimOperator AS o ON o.OperatorKey = f.OperatorKey
JOIN warehouse.DimService AS s ON s.ServiceKey = f.ServiceKey
JOIN warehouse.DimRoute AS r ON r.RouteKey = f.RouteKey
JOIN warehouse.DimLineType AS lt ON lt.LineTypeKey = f.LineTypeKey
JOIN warehouse.DimDayType AS dt ON dt.DayTypeKey = f.DayTypeKey
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO

CREATE VIEW mart.vw_GtfsSnapshot
AS
SELECT
    d.CalendarYear,
    d.FullDate AS ServiceStartDate,
    de.FullDate AS ServiceEndDate,
    o.OperatorName,
    s.ServiceName,
    f.MetricName,
    f.MetricValue,
    f.UnitName,
    f.DataStatus,
    src.SourceId,
    src.SourceUrl,
    f.Notes
FROM warehouse.FactGtfsSnapshot AS f
JOIN warehouse.DimDate AS d ON d.DateKey = f.PeriodStartDateKey
JOIN warehouse.DimDate AS de ON de.DateKey = f.PeriodEndDateKey
JOIN warehouse.DimOperator AS o ON o.OperatorKey = f.OperatorKey
JOIN warehouse.DimService AS s ON s.ServiceKey = f.ServiceKey
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO

CREATE VIEW mart.vw_DataQuality
AS
SELECT
    RecordType,
    DataYear,
    COUNT_BIG(*) AS [RowCount],
    SUM(CASE WHEN MetricValue IS NULL THEN 1 ELSE 0 END) AS NullMetricValueCount,
    MIN(PeriodStart) AS MinPeriodStart,
    MAX(PeriodEnd) AS MaxPeriodEnd
FROM staging.RawTransitData
GROUP BY RecordType, DataYear;
GO
