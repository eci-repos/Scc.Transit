CREATE TABLE staging.RawWeatherData
(
    RawWeatherDataKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawWeatherData PRIMARY KEY,
    ObservationDate date NOT NULL,
    StationId nvarchar(100) NOT NULL,
    StationName nvarchar(200) NULL,
    TemperatureAvgF decimal(6, 2) NULL,
    TemperatureMinF decimal(6, 2) NULL,
    TemperatureMaxF decimal(6, 2) NULL,
    PrecipitationInches decimal(8, 3) NULL,
    WindSpeedMph decimal(6, 2) NULL,
    VisibilityMiles decimal(6, 2) NULL,
    WeatherCondition nvarchar(200) NULL,
    IsThunderstorm bit NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawWeatherData_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE warehouse.DimWeatherStation
(
    WeatherStationKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimWeatherStation PRIMARY KEY,
    StationId nvarchar(100) NOT NULL CONSTRAINT UQ_DimWeatherStation_StationId UNIQUE,
    StationName nvarchar(200) NULL
);
GO

CREATE TABLE warehouse.DimWeatherPerception
(
    WeatherPerceptionKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimWeatherPerception PRIMARY KEY,
    ClassCode nvarchar(50) NOT NULL CONSTRAINT UQ_DimWeatherPerception_ClassCode UNIQUE,
    ClassName nvarchar(100) NOT NULL,
    ClassPriority tinyint NOT NULL,
    Description nvarchar(300) NOT NULL
);
GO

CREATE TABLE warehouse.FactWeatherDaily
(
    FactWeatherDailyKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactWeatherDaily PRIMARY KEY,
    RawWeatherDataKey bigint NOT NULL,
    WeatherDateKey int NOT NULL,
    WeatherStationKey int NOT NULL,
    DataSourceKey int NOT NULL,
    WeatherPerceptionKey int NOT NULL,
    TemperatureAvgF decimal(6, 2) NULL,
    TemperatureMinF decimal(6, 2) NULL,
    TemperatureMaxF decimal(6, 2) NULL,
    PrecipitationInches decimal(8, 3) NULL,
    WindSpeedMph decimal(6, 2) NULL,
    VisibilityMiles decimal(6, 2) NULL,
    WeatherCondition nvarchar(200) NULL,
    ClassificationMethod nvarchar(100) NOT NULL,
    ClassifiedAtUtc datetime2(0) NOT NULL CONSTRAINT DF_FactWeatherDaily_ClassifiedAtUtc DEFAULT SYSUTCDATETIME(),
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactWeatherDaily_SourceStationDate UNIQUE (RawWeatherDataKey, WeatherStationKey, WeatherDateKey),
    CONSTRAINT FK_FactWeatherDaily_Raw FOREIGN KEY (RawWeatherDataKey) REFERENCES staging.RawWeatherData(RawWeatherDataKey),
    CONSTRAINT FK_FactWeatherDaily_Date FOREIGN KEY (WeatherDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactWeatherDaily_Station FOREIGN KEY (WeatherStationKey) REFERENCES warehouse.DimWeatherStation(WeatherStationKey),
    CONSTRAINT FK_FactWeatherDaily_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey),
    CONSTRAINT FK_FactWeatherDaily_Perception FOREIGN KEY (WeatherPerceptionKey) REFERENCES warehouse.DimWeatherPerception(WeatherPerceptionKey)
);
GO

CREATE INDEX IX_FactWeatherDaily_Date ON warehouse.FactWeatherDaily(WeatherDateKey, WeatherStationKey);
GO
CREATE INDEX IX_FactWeatherDaily_Perception ON warehouse.FactWeatherDaily(WeatherPerceptionKey, WeatherDateKey);
GO
