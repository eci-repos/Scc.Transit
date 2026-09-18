CREATE TABLE staging.RawGtfsRoute
(
    RawGtfsRouteKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawGtfsRoute PRIMARY KEY,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    RouteId nvarchar(100) NOT NULL,
    RouteShortName nvarchar(100) NULL,
    RouteLongName nvarchar(300) NULL,
    RouteType int NULL,
    RouteUrl nvarchar(2048) NULL,
    RouteColor nvarchar(20) NULL,
    RouteTextColor nvarchar(20) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawGtfsRoute_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawGtfsTrip
(
    RawGtfsTripKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawGtfsTrip PRIMARY KEY,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    RouteId nvarchar(100) NOT NULL,
    ServiceId nvarchar(100) NULL,
    TripId nvarchar(200) NOT NULL,
    TripHeadsign nvarchar(300) NULL,
    DirectionId int NULL,
    ShapeId nvarchar(200) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawGtfsTrip_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawGtfsStop
(
    RawGtfsStopKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawGtfsStop PRIMARY KEY,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    StopId nvarchar(100) NOT NULL,
    StopCode nvarchar(100) NULL,
    StopName nvarchar(300) NULL,
    StopLat decimal(10, 7) NULL,
    StopLon decimal(10, 7) NULL,
    LocationType int NULL,
    ParentStation nvarchar(100) NULL,
    WheelchairBoarding int NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawGtfsStop_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawGtfsShapePoint
(
    RawGtfsShapePointKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawGtfsShapePoint PRIMARY KEY,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    ShapeId nvarchar(200) NOT NULL,
    ShapePointLat decimal(10, 7) NULL,
    ShapePointLon decimal(10, 7) NULL,
    ShapePointSequence int NOT NULL,
    ShapeDistTraveled decimal(12, 3) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawGtfsShapePoint_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE staging.RawVehiclePosition
(
    RawVehiclePositionKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawVehiclePosition PRIMARY KEY,
    ObservedAtUtc datetime2(0) NOT NULL,
    VehicleId nvarchar(200) NOT NULL,
    TripId nvarchar(200) NULL,
    RouteId nvarchar(100) NULL,
    Latitude decimal(10, 7) NOT NULL,
    Longitude decimal(10, 7) NOT NULL,
    Bearing decimal(7, 2) NULL,
    SpeedMph decimal(7, 2) NULL,
    CurrentStopSequence int NULL,
    CurrentStatus nvarchar(100) NULL,
    OccupancyStatus nvarchar(100) NULL,
    SourceId nvarchar(200) NOT NULL,
    SourceUrl nvarchar(2048) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawVehiclePosition_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE warehouse.DimGtfsRoute
(
    GtfsRouteKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimGtfsRoute PRIMARY KEY,
    DataSourceKey int NOT NULL,
    RouteId nvarchar(100) NOT NULL,
    RouteShortName nvarchar(100) NULL,
    RouteLongName nvarchar(300) NULL,
    RouteType int NULL,
    RouteUrl nvarchar(2048) NULL,
    RouteColor nvarchar(20) NULL,
    RouteTextColor nvarchar(20) NULL,
    CONSTRAINT UQ_DimGtfsRoute_SourceRoute UNIQUE (DataSourceKey, RouteId),
    CONSTRAINT FK_DimGtfsRoute_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE TABLE warehouse.DimGtfsStop
(
    GtfsStopKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimGtfsStop PRIMARY KEY,
    DataSourceKey int NOT NULL,
    StopId nvarchar(100) NOT NULL,
    StopCode nvarchar(100) NULL,
    StopName nvarchar(300) NULL,
    StopLat decimal(10, 7) NULL,
    StopLon decimal(10, 7) NULL,
    LocationType int NULL,
    ParentStation nvarchar(100) NULL,
    WheelchairBoarding int NULL,
    CONSTRAINT UQ_DimGtfsStop_SourceStop UNIQUE (DataSourceKey, StopId),
    CONSTRAINT FK_DimGtfsStop_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE TABLE warehouse.FactGtfsShapePoint
(
    FactGtfsShapePointKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactGtfsShapePoint PRIMARY KEY,
    DataSourceKey int NOT NULL,
    GtfsRouteKey int NULL,
    ShapeId nvarchar(200) NOT NULL,
    ShapePointSequence int NOT NULL,
    ShapePointLat decimal(10, 7) NULL,
    ShapePointLon decimal(10, 7) NULL,
    ShapeDistTraveled decimal(12, 3) NULL,
    CONSTRAINT UQ_FactGtfsShapePoint_SourceShapeSequence UNIQUE (DataSourceKey, ShapeId, ShapePointSequence),
    CONSTRAINT FK_FactGtfsShapePoint_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey),
    CONSTRAINT FK_FactGtfsShapePoint_Route FOREIGN KEY (GtfsRouteKey) REFERENCES warehouse.DimGtfsRoute(GtfsRouteKey)
);
GO

CREATE TABLE warehouse.FactVehiclePosition
(
    FactVehiclePositionKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactVehiclePosition PRIMARY KEY,
    RawVehiclePositionKey bigint NOT NULL,
    ObservedAtUtc datetime2(0) NOT NULL,
    VehicleId nvarchar(200) NOT NULL,
    TripId nvarchar(200) NULL,
    RouteId nvarchar(100) NULL,
    GtfsRouteKey int NULL,
    Latitude decimal(10, 7) NOT NULL,
    Longitude decimal(10, 7) NOT NULL,
    Bearing decimal(7, 2) NULL,
    SpeedMph decimal(7, 2) NULL,
    CurrentStopSequence int NULL,
    CurrentStatus nvarchar(100) NULL,
    OccupancyStatus nvarchar(100) NULL,
    DataSourceKey int NOT NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT UQ_FactVehiclePosition_Raw UNIQUE (RawVehiclePositionKey),
    CONSTRAINT FK_FactVehiclePosition_Raw FOREIGN KEY (RawVehiclePositionKey) REFERENCES staging.RawVehiclePosition(RawVehiclePositionKey),
    CONSTRAINT FK_FactVehiclePosition_Route FOREIGN KEY (GtfsRouteKey) REFERENCES warehouse.DimGtfsRoute(GtfsRouteKey),
    CONSTRAINT FK_FactVehiclePosition_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE INDEX IX_FactGtfsShapePoint_Map ON warehouse.FactGtfsShapePoint(DataSourceKey, GtfsRouteKey, ShapeId, ShapePointSequence);
GO
CREATE INDEX IX_FactVehiclePosition_Latest ON warehouse.FactVehiclePosition(VehicleId, ObservedAtUtc DESC);
GO
