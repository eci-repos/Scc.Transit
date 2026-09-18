CREATE TABLE staging.RawGtfsTripUpdate
(
    RawGtfsTripUpdateKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawGtfsTripUpdate PRIMARY KEY,
    ObservedAtUtc datetime2(0) NOT NULL,
    TripId nvarchar(200) NULL,
    RouteId nvarchar(100) NULL,
    VehicleId nvarchar(200) NULL,
    StopId nvarchar(100) NULL,
    StopSequence int NULL,
    ArrivalTimeUtc datetime2(0) NULL,
    DepartureTimeUtc datetime2(0) NULL,
    ArrivalDelaySeconds int NULL,
    DepartureDelaySeconds int NULL,
    ScheduleRelationship nvarchar(100) NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawGtfsTripUpdate_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawGtfsServiceAlert
(
    RawGtfsServiceAlertKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawGtfsServiceAlert PRIMARY KEY,
    ObservedAtUtc datetime2(0) NOT NULL,
    AlertId nvarchar(200) NOT NULL,
    Cause nvarchar(100) NULL,
    Effect nvarchar(100) NULL,
    HeaderText nvarchar(1000) NULL,
    DescriptionText nvarchar(max) NULL,
    ActiveStartUtc datetime2(0) NULL,
    ActiveEndUtc datetime2(0) NULL,
    RouteId nvarchar(100) NULL,
    StopId nvarchar(100) NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawGtfsServiceAlert_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE warehouse.FactGtfsTripUpdate
(
    FactGtfsTripUpdateKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactGtfsTripUpdate PRIMARY KEY,
    RawGtfsTripUpdateKey bigint NOT NULL,
    ObservedAtUtc datetime2(0) NOT NULL,
    TripId nvarchar(200) NULL,
    RouteId nvarchar(100) NULL,
    VehicleId nvarchar(200) NULL,
    StopId nvarchar(100) NULL,
    StopSequence int NULL,
    ArrivalTimeUtc datetime2(0) NULL,
    DepartureTimeUtc datetime2(0) NULL,
    ArrivalDelaySeconds int NULL,
    DepartureDelaySeconds int NULL,
    ScheduleRelationship nvarchar(100) NULL,
    DataSourceKey int NOT NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactGtfsTripUpdate_Raw UNIQUE (RawGtfsTripUpdateKey),
    CONSTRAINT FK_FactGtfsTripUpdate_Raw FOREIGN KEY (RawGtfsTripUpdateKey) REFERENCES staging.RawGtfsTripUpdate(RawGtfsTripUpdateKey),
    CONSTRAINT FK_FactGtfsTripUpdate_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE TABLE warehouse.FactGtfsServiceAlert
(
    FactGtfsServiceAlertKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactGtfsServiceAlert PRIMARY KEY,
    RawGtfsServiceAlertKey bigint NOT NULL,
    ObservedAtUtc datetime2(0) NOT NULL,
    AlertId nvarchar(200) NOT NULL,
    Cause nvarchar(100) NULL,
    Effect nvarchar(100) NULL,
    HeaderText nvarchar(1000) NULL,
    DescriptionText nvarchar(max) NULL,
    ActiveStartUtc datetime2(0) NULL,
    ActiveEndUtc datetime2(0) NULL,
    RouteId nvarchar(100) NULL,
    StopId nvarchar(100) NULL,
    DataSourceKey int NOT NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactGtfsServiceAlert_Raw UNIQUE (RawGtfsServiceAlertKey),
    CONSTRAINT FK_FactGtfsServiceAlert_Raw FOREIGN KEY (RawGtfsServiceAlertKey) REFERENCES staging.RawGtfsServiceAlert(RawGtfsServiceAlertKey),
    CONSTRAINT FK_FactGtfsServiceAlert_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE INDEX IX_FactGtfsTripUpdate_RouteTime ON warehouse.FactGtfsTripUpdate(RouteId, ObservedAtUtc);
GO
CREATE INDEX IX_FactGtfsServiceAlert_Active ON warehouse.FactGtfsServiceAlert(ActiveStartUtc, ActiveEndUtc, RouteId);
GO

CREATE VIEW mart.vw_TripPerformance
AS
SELECT
    f.ObservedAtUtc,
    f.TripId,
    f.RouteId,
    f.VehicleId,
    f.StopId,
    f.StopSequence,
    f.ArrivalTimeUtc,
    f.DepartureTimeUtc,
    f.ArrivalDelaySeconds,
    f.DepartureDelaySeconds,
    f.ScheduleRelationship,
    src.SourceId,
    src.SourceUrl,
    f.Notes
FROM warehouse.FactGtfsTripUpdate AS f
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO

CREATE VIEW mart.vw_ServiceAlerts
AS
SELECT
    f.ObservedAtUtc,
    f.AlertId,
    f.Cause,
    f.Effect,
    f.HeaderText,
    f.DescriptionText,
    f.ActiveStartUtc,
    f.ActiveEndUtc,
    f.RouteId,
    f.StopId,
    src.SourceId,
    src.SourceUrl,
    f.Notes
FROM warehouse.FactGtfsServiceAlert AS f
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey;
GO

CREATE PROCEDURE warehouse.usp_LoadGtfsRealtime
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    INSERT INTO warehouse.DimDataSource (SourceId, SourceUrl, SourceNotes)
    SELECT SourceId, MAX(SourceUrl), N'GTFS-Realtime feed loaded from staging.'
    FROM
    (
        SELECT SourceId, SourceUrl FROM staging.RawGtfsTripUpdate
        UNION ALL SELECT SourceId, SourceUrl FROM staging.RawGtfsServiceAlert
    ) AS sources
    WHERE NOT EXISTS (SELECT 1 FROM warehouse.DimDataSource AS d WHERE d.SourceId = sources.SourceId)
    GROUP BY SourceId;

    DELETE f
    FROM warehouse.FactGtfsTripUpdate AS f
    JOIN staging.RawGtfsTripUpdate AS s ON s.RawGtfsTripUpdateKey = f.RawGtfsTripUpdateKey;

    DELETE f
    FROM warehouse.FactGtfsServiceAlert AS f
    JOIN staging.RawGtfsServiceAlert AS s ON s.RawGtfsServiceAlertKey = f.RawGtfsServiceAlertKey;

    INSERT INTO warehouse.FactGtfsTripUpdate
    (
        RawGtfsTripUpdateKey, ObservedAtUtc, TripId, RouteId, VehicleId, StopId,
        StopSequence, ArrivalTimeUtc, DepartureTimeUtc, ArrivalDelaySeconds,
        DepartureDelaySeconds, ScheduleRelationship, DataSourceKey, Notes
    )
    SELECT
        s.RawGtfsTripUpdateKey, s.ObservedAtUtc, s.TripId, s.RouteId, s.VehicleId, s.StopId,
        s.StopSequence, s.ArrivalTimeUtc, s.DepartureTimeUtc, s.ArrivalDelaySeconds,
        s.DepartureDelaySeconds, s.ScheduleRelationship, d.DataSourceKey, s.Notes
    FROM staging.RawGtfsTripUpdate AS s
    JOIN warehouse.DimDataSource AS d ON d.SourceId = s.SourceId;

    INSERT INTO warehouse.FactGtfsServiceAlert
    (
        RawGtfsServiceAlertKey, ObservedAtUtc, AlertId, Cause, Effect, HeaderText,
        DescriptionText, ActiveStartUtc, ActiveEndUtc, RouteId, StopId, DataSourceKey, Notes
    )
    SELECT
        s.RawGtfsServiceAlertKey, s.ObservedAtUtc, s.AlertId, s.Cause, s.Effect, s.HeaderText,
        s.DescriptionText, s.ActiveStartUtc, s.ActiveEndUtc, s.RouteId, s.StopId, d.DataSourceKey, s.Notes
    FROM staging.RawGtfsServiceAlert AS s
    JOIN warehouse.DimDataSource AS d ON d.SourceId = s.SourceId;

    COMMIT TRANSACTION;
END;
GO
