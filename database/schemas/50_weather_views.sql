CREATE VIEW mart.vw_WeatherDaily
AS
SELECT
    d.FullDate AS ObservationDate,
    d.CalendarYear,
    ws.StationId,
    ws.StationName,
    p.ClassCode AS WeatherPerceptionCode,
    p.ClassName AS WeatherPerception,
    p.ClassPriority,
    f.TemperatureAvgF,
    f.TemperatureMinF,
    f.TemperatureMaxF,
    f.PrecipitationInches,
    f.WindSpeedMph,
    f.VisibilityMiles,
    f.WeatherCondition,
    src.SourceId,
    src.SourceUrl,
    f.ClassificationMethod,
    f.Notes
FROM warehouse.FactWeatherDaily AS f
JOIN warehouse.DimDate AS d ON d.DateKey = f.WeatherDateKey
JOIN warehouse.DimWeatherStation AS ws ON ws.WeatherStationKey = f.WeatherStationKey
JOIN warehouse.DimWeatherPerception AS p ON p.WeatherPerceptionKey = f.WeatherPerceptionKey
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO
