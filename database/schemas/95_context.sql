CREATE TABLE staging.RawCalendarEvent
(
    RawCalendarEventKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawCalendarEvent PRIMARY KEY,
    EventDate date NOT NULL,
    EventName nvarchar(300) NOT NULL,
    EventType nvarchar(100) NULL,
    LocationName nvarchar(300) NULL,
    Latitude decimal(10, 7) NULL,
    Longitude decimal(10, 7) NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawCalendarEvent_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawTrafficIncident
(
    RawTrafficIncidentKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawTrafficIncident PRIMARY KEY,
    IncidentId nvarchar(200) NOT NULL,
    ObservedAtUtc datetime2(0) NOT NULL,
    IncidentStartUtc datetime2(0) NULL,
    IncidentEndUtc datetime2(0) NULL,
    IncidentType nvarchar(100) NULL,
    Severity nvarchar(100) NULL,
    Status nvarchar(100) NULL,
    RoadName nvarchar(300) NULL,
    Latitude decimal(10, 7) NULL,
    Longitude decimal(10, 7) NULL,
    DescriptionText nvarchar(max) NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawTrafficIncident_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawAirQualityDaily
(
    RawAirQualityDailyKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawAirQualityDaily PRIMARY KEY,
    ObservationDate date NOT NULL,
    StationId nvarchar(100) NOT NULL,
    StationName nvarchar(200) NULL,
    AirQualityIndex int NULL,
    PrimaryPollutant nvarchar(100) NULL,
    Category nvarchar(100) NULL,
    SmokeFlag bit NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawAirQualityDaily_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE warehouse.FactCalendarEvent
(
    FactCalendarEventKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactCalendarEvent PRIMARY KEY,
    RawCalendarEventKey bigint NOT NULL,
    EventDateKey int NOT NULL,
    EventName nvarchar(300) NOT NULL,
    EventType nvarchar(100) NULL,
    LocationName nvarchar(300) NULL,
    Latitude decimal(10, 7) NULL,
    Longitude decimal(10, 7) NULL,
    DataSourceKey int NOT NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactCalendarEvent_Raw UNIQUE (RawCalendarEventKey),
    CONSTRAINT FK_FactCalendarEvent_Raw FOREIGN KEY (RawCalendarEventKey) REFERENCES staging.RawCalendarEvent(RawCalendarEventKey),
    CONSTRAINT FK_FactCalendarEvent_Date FOREIGN KEY (EventDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactCalendarEvent_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE TABLE warehouse.FactTrafficIncident
(
    FactTrafficIncidentKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactTrafficIncident PRIMARY KEY,
    RawTrafficIncidentKey bigint NOT NULL,
    ObservedAtUtc datetime2(0) NOT NULL,
    IncidentId nvarchar(200) NOT NULL,
    IncidentStartUtc datetime2(0) NULL,
    IncidentEndUtc datetime2(0) NULL,
    IncidentType nvarchar(100) NULL,
    Severity nvarchar(100) NULL,
    Status nvarchar(100) NULL,
    RoadName nvarchar(300) NULL,
    Latitude decimal(10, 7) NULL,
    Longitude decimal(10, 7) NULL,
    DescriptionText nvarchar(max) NULL,
    DataSourceKey int NOT NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactTrafficIncident_Raw UNIQUE (RawTrafficIncidentKey),
    CONSTRAINT FK_FactTrafficIncident_Raw FOREIGN KEY (RawTrafficIncidentKey) REFERENCES staging.RawTrafficIncident(RawTrafficIncidentKey),
    CONSTRAINT FK_FactTrafficIncident_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE TABLE warehouse.FactAirQualityDaily
(
    FactAirQualityDailyKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactAirQualityDaily PRIMARY KEY,
    RawAirQualityDailyKey bigint NOT NULL,
    ObservationDateKey int NOT NULL,
    StationId nvarchar(100) NOT NULL,
    StationName nvarchar(200) NULL,
    AirQualityIndex int NULL,
    PrimaryPollutant nvarchar(100) NULL,
    Category nvarchar(100) NULL,
    SmokeFlag bit NULL,
    DataSourceKey int NOT NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactAirQualityDaily_Raw UNIQUE (RawAirQualityDailyKey),
    CONSTRAINT FK_FactAirQualityDaily_Raw FOREIGN KEY (RawAirQualityDailyKey) REFERENCES staging.RawAirQualityDaily(RawAirQualityDailyKey),
    CONSTRAINT FK_FactAirQualityDaily_Date FOREIGN KEY (ObservationDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactAirQualityDaily_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE VIEW mart.vw_CalendarEvents
AS
SELECT d.FullDate AS EventDate, f.EventName, f.EventType, f.LocationName, f.Latitude, f.Longitude, src.SourceId, src.SourceUrl, f.Notes
FROM warehouse.FactCalendarEvent AS f
JOIN warehouse.DimDate AS d ON d.DateKey = f.EventDateKey
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO

CREATE VIEW mart.vw_TrafficIncidents
AS
SELECT f.ObservedAtUtc, f.IncidentId, f.IncidentStartUtc, f.IncidentEndUtc, f.IncidentType, f.Severity, f.Status, f.RoadName, f.Latitude, f.Longitude, f.DescriptionText, src.SourceId, src.SourceUrl, f.Notes
FROM warehouse.FactTrafficIncident AS f
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO

CREATE VIEW mart.vw_AirQualityDaily
AS
SELECT d.FullDate AS ObservationDate, f.StationId, f.StationName, f.AirQualityIndex, f.PrimaryPollutant, f.Category, f.SmokeFlag, src.SourceId, src.SourceUrl, f.Notes
FROM warehouse.FactAirQualityDaily AS f
JOIN warehouse.DimDate AS d ON d.DateKey = f.ObservationDateKey
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO
