INSERT INTO warehouse.DimOperator (OperatorCode, OperatorName)
SELECT DISTINCT COALESCE(NULLIF(OperatorName, N''), N'UNKNOWN'), COALESCE(NULLIF(OperatorName, N''), N'Unknown operator')
FROM staging.RawTransitData AS s
WHERE NOT EXISTS
(
    SELECT 1 FROM warehouse.DimOperator AS d
    WHERE d.OperatorCode = COALESCE(NULLIF(s.OperatorName, N''), N'UNKNOWN')
);
GO

INSERT INTO warehouse.DimService (ServiceName)
SELECT DISTINCT COALESCE(NULLIF(ServiceName, N''), N'Unknown service')
FROM staging.RawTransitData AS s
WHERE NOT EXISTS
(
    SELECT 1 FROM warehouse.DimService AS d
    WHERE d.ServiceName = COALESCE(NULLIF(s.ServiceName, N''), N'Unknown service')
);
GO

INSERT INTO warehouse.DimRoute (RouteNaturalKey, RouteDisplayName)
SELECT DISTINCT COALESCE(NULLIF(RouteId, N''), N'UNKNOWN'), COALESCE(NULLIF(RouteId, N''), N'Unknown route')
FROM staging.RawTransitData AS s
WHERE NOT EXISTS
(
    SELECT 1 FROM warehouse.DimRoute AS d
    WHERE d.RouteNaturalKey = COALESCE(NULLIF(s.RouteId, N''), N'UNKNOWN')
);
GO

INSERT INTO warehouse.DimLineType (LineTypeName)
SELECT DISTINCT COALESCE(NULLIF(LineType, N''), N'Unknown line type')
FROM staging.RawTransitData AS s
WHERE NOT EXISTS
(
    SELECT 1 FROM warehouse.DimLineType AS d
    WHERE d.LineTypeName = COALESCE(NULLIF(s.LineType, N''), N'Unknown line type')
);
GO

INSERT INTO warehouse.DimDayType (DayTypeName)
SELECT DISTINCT COALESCE(NULLIF(DayType, N''), N'Unknown day type')
FROM staging.RawTransitData AS s
WHERE NOT EXISTS
(
    SELECT 1 FROM warehouse.DimDayType AS d
    WHERE d.DayTypeName = COALESCE(NULLIF(s.DayType, N''), N'Unknown day type')
);
GO

INSERT INTO warehouse.DimDataSource (SourceId, SourceUrl, SourceNotes)
SELECT SourceId, MAX(SourceUrl), MAX(Notes)
FROM
(
    SELECT
        COALESCE(NULLIF(SourceId, N''), N'UNKNOWN') AS SourceId,
        NULLIF(SourceUrl, N'') AS SourceUrl,
        Notes
    FROM staging.RawTransitData
) AS s
WHERE NOT EXISTS
(
    SELECT 1 FROM warehouse.DimDataSource AS d
    WHERE d.SourceId = s.SourceId
)
GROUP BY SourceId;
GO

DECLARE @MinDate date = (SELECT MIN(PeriodStart) FROM staging.RawTransitData WHERE PeriodStart IS NOT NULL);
DECLARE @MaxDate date = (SELECT MAX(PeriodEnd) FROM staging.RawTransitData WHERE PeriodEnd IS NOT NULL);

IF @MinDate IS NOT NULL AND @MaxDate IS NOT NULL
BEGIN
    ;WITH Dates AS
    (
        SELECT @MinDate AS FullDate
        UNION ALL
        SELECT DATEADD(day, 1, FullDate)
        FROM Dates
        WHERE FullDate < @MaxDate
    )
    INSERT INTO warehouse.DimDate
    (
        DateKey, FullDate, CalendarYear, CalendarQuarter, CalendarMonth,
        MonthName, DayOfMonth, DayOfWeekNumber, DayOfWeekName
    )
    SELECT
        CONVERT(int, CONVERT(char(8), FullDate, 112)),
        FullDate,
        DATEPART(year, FullDate),
        DATEPART(quarter, FullDate),
        DATEPART(month, FullDate),
        DATENAME(month, FullDate),
        DATEPART(day, FullDate),
        DATEPART(weekday, FullDate),
        DATENAME(weekday, FullDate)
    FROM Dates
    OPTION (MAXRECURSION 0);
END;
GO
