CREATE PROCEDURE warehouse.usp_ClassifyWeatherData
    @ReloadAll bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    INSERT INTO warehouse.DimWeatherPerception (ClassCode, ClassName, ClassPriority, Description)
    SELECT v.ClassCode, v.ClassName, v.ClassPriority, v.Description
    FROM
    (
        VALUES
            (N'HEAVY_RAIN_STORM', N'Heavy rain/storm', 1, N'Heavy precipitation, thunderstorm, or strong wind.'),
            (N'FOGGY_LOW_VISIBILITY', N'Foggy/low visibility', 2, N'Fog or visibility below two miles.'),
            (N'DAMP_LIGHT_RAIN', N'Damp/light rain', 3, N'Light precipitation greater than zero and up to 0.10 inches.'),
            (N'RAINY', N'Rainy', 4, N'Precipitation greater than 0.10 and up to 0.50 inches.'),
            (N'COLD_BREEZY', N'Cold and breezy', 5, N'Average temperature below 50°F with wind at or above 6 mph.'),
            (N'COLD_CALM', N'Cold and calm', 6, N'Average temperature below 50°F with wind below 6 mph.'),
            (N'COOL_COMFORTABLE', N'Cool/comfortable', 7, N'Average temperature from 50°F through 69°F and dry.'),
            (N'WARM_BREEZY', N'Warm and breezy', 8, N'Average temperature from 70°F through 79°F with wind at or above 6 mph.'),
            (N'WARM_COMFORTABLE', N'Warm/comfortable', 9, N'Average temperature from 70°F through 79°F and dry with light wind.'),
            (N'HOT_DRY', N'Hot and dry', 10, N'Average temperature at or above 80°F with no rain.'),
            (N'UNKNOWN', N'Unknown', 99, N'Insufficient or unsupported weather values.')
    ) AS v(ClassCode, ClassName, ClassPriority, Description)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM warehouse.DimWeatherPerception AS p
        WHERE p.ClassCode = v.ClassCode
    );

    INSERT INTO warehouse.DimWeatherStation (StationId, StationName)
    SELECT s.StationId, MAX(s.StationName)
    FROM staging.RawWeatherData AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM warehouse.DimWeatherStation AS d
        WHERE d.StationId = s.StationId
    )
    GROUP BY s.StationId;

    INSERT INTO warehouse.DimDataSource (SourceId, SourceUrl, SourceNotes)
    SELECT s.SourceId, MAX(s.SourceUrl), MAX(s.Notes)
    FROM staging.RawWeatherData AS s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM warehouse.DimDataSource AS d
        WHERE d.SourceId = s.SourceId
    )
    GROUP BY s.SourceId;

    DECLARE @MinDate date = (SELECT MIN(ObservationDate) FROM staging.RawWeatherData);
    DECLARE @MaxDate date = (SELECT MAX(ObservationDate) FROM staging.RawWeatherData);

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
        FROM Dates AS d
        WHERE NOT EXISTS
        (
            SELECT 1 FROM warehouse.DimDate AS existingDate WHERE existingDate.FullDate = d.FullDate
        )
        OPTION (MAXRECURSION 0);
    END;

    IF @ReloadAll = 1
    BEGIN
        DELETE FROM warehouse.FactWeatherDaily;
    END
    ELSE
    BEGIN
        DELETE f
        FROM warehouse.FactWeatherDaily AS f
        JOIN staging.RawWeatherData AS s ON s.RawWeatherDataKey = f.RawWeatherDataKey;
    END;

    INSERT INTO warehouse.FactWeatherDaily
    (
        RawWeatherDataKey, WeatherDateKey, WeatherStationKey, DataSourceKey,
        WeatherPerceptionKey, TemperatureAvgF, TemperatureMinF, TemperatureMaxF,
        PrecipitationInches, WindSpeedMph, VisibilityMiles, WeatherCondition,
        ClassificationMethod, Notes
    )
    SELECT
        s.RawWeatherDataKey,
        CONVERT(int, CONVERT(char(8), s.ObservationDate, 112)),
        ws.WeatherStationKey,
        src.DataSourceKey,
        p.WeatherPerceptionKey,
        s.TemperatureAvgF,
        s.TemperatureMinF,
        s.TemperatureMaxF,
        s.PrecipitationInches,
        s.WindSpeedMph,
        s.VisibilityMiles,
        s.WeatherCondition,
        N'warehouse.usp_ClassifyWeatherData:v1',
        s.Notes
    FROM staging.RawWeatherData AS s
    JOIN warehouse.DimWeatherStation AS ws ON ws.StationId = s.StationId
    JOIN warehouse.DimDataSource AS src ON src.SourceId = s.SourceId
    CROSS APPLY
    (
        SELECT CASE
            WHEN ISNULL(s.IsThunderstorm, 0) = 1
                OR LOWER(ISNULL(s.WeatherCondition, N'')) LIKE N'%thunder%'
                OR LOWER(ISNULL(s.WeatherCondition, N'')) LIKE N'%storm%'
                OR ISNULL(s.PrecipitationInches, 0) > 0.50
                OR ISNULL(s.WindSpeedMph, 0) > 25 THEN N'HEAVY_RAIN_STORM'
            WHEN ISNULL(s.VisibilityMiles, 99) < 2
                OR LOWER(ISNULL(s.WeatherCondition, N'')) LIKE N'%fog%' THEN N'FOGGY_LOW_VISIBILITY'
            WHEN ISNULL(s.PrecipitationInches, 0) > 0.10 THEN N'RAINY'
            WHEN ISNULL(s.PrecipitationInches, 0) > 0 THEN N'DAMP_LIGHT_RAIN'
            WHEN COALESCE(s.TemperatureAvgF, (s.TemperatureMinF + s.TemperatureMaxF) / 2.0) < 50
                AND ISNULL(s.WindSpeedMph, 0) >= 6 THEN N'COLD_BREEZY'
            WHEN COALESCE(s.TemperatureAvgF, (s.TemperatureMinF + s.TemperatureMaxF) / 2.0) < 50 THEN N'COLD_CALM'
            WHEN COALESCE(s.TemperatureAvgF, (s.TemperatureMinF + s.TemperatureMaxF) / 2.0) BETWEEN 50 AND 69 THEN N'COOL_COMFORTABLE'
            WHEN COALESCE(s.TemperatureAvgF, (s.TemperatureMinF + s.TemperatureMaxF) / 2.0) BETWEEN 70 AND 79
                AND ISNULL(s.WindSpeedMph, 0) >= 6 THEN N'WARM_BREEZY'
            WHEN COALESCE(s.TemperatureAvgF, (s.TemperatureMinF + s.TemperatureMaxF) / 2.0) BETWEEN 70 AND 79 THEN N'WARM_COMFORTABLE'
            WHEN COALESCE(s.TemperatureAvgF, (s.TemperatureMinF + s.TemperatureMaxF) / 2.0) >= 80 THEN N'HOT_DRY'
            ELSE N'UNKNOWN'
        END AS ClassCode
    ) AS classified
    JOIN warehouse.DimWeatherPerception AS p ON p.ClassCode = classified.ClassCode;

    COMMIT TRANSACTION;
END;
GO
