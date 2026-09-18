CREATE TABLE staging.RawTransitData
(
    RawTransitDataKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_RawTransitData PRIMARY KEY,
    RecordType nvarchar(64) NOT NULL,
    DataYear int NULL,
    PeriodStart date NULL,
    PeriodEnd date NULL,
    OperatorName nvarchar(200) NULL,
    ServiceName nvarchar(200) NULL,
    RouteId nvarchar(100) NULL,
    LineType nvarchar(100) NULL,
    DayType nvarchar(100) NULL,
    MetricName nvarchar(100) NULL,
    MetricValue decimal(19, 4) NULL,
    UnitName nvarchar(100) NULL,
    DataStatus nvarchar(100) NULL,
    SourceUrl nvarchar(2048) NULL,
    SourceId nvarchar(200) NULL,
    Notes nvarchar(max) NULL,
    LoadedAt datetime2(0) NOT NULL CONSTRAINT DF_RawTransitData_LoadedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE warehouse.DimDate
(
    DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
    FullDate date NOT NULL CONSTRAINT UQ_DimDate_FullDate UNIQUE,
    CalendarYear smallint NOT NULL,
    CalendarQuarter tinyint NOT NULL,
    CalendarMonth tinyint NOT NULL,
    MonthName nvarchar(20) NOT NULL,
    DayOfMonth tinyint NOT NULL,
    DayOfWeekNumber tinyint NOT NULL,
    DayOfWeekName nvarchar(20) NOT NULL
);
GO

CREATE TABLE warehouse.DimOperator
(
    OperatorKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimOperator PRIMARY KEY,
    OperatorCode nvarchar(200) NOT NULL CONSTRAINT UQ_DimOperator_Code UNIQUE,
    OperatorName nvarchar(200) NOT NULL
);
GO

CREATE TABLE warehouse.DimService
(
    ServiceKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimService PRIMARY KEY,
    ServiceName nvarchar(200) NOT NULL CONSTRAINT UQ_DimService_Name UNIQUE
);
GO

CREATE TABLE warehouse.DimRoute
(
    RouteKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimRoute PRIMARY KEY,
    RouteNaturalKey nvarchar(100) NOT NULL CONSTRAINT UQ_DimRoute_NaturalKey UNIQUE,
    RouteDisplayName nvarchar(200) NOT NULL
);
GO

CREATE TABLE warehouse.DimLineType
(
    LineTypeKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimLineType PRIMARY KEY,
    LineTypeName nvarchar(100) NOT NULL CONSTRAINT UQ_DimLineType_Name UNIQUE
);
GO

CREATE TABLE warehouse.DimDayType
(
    DayTypeKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimDayType PRIMARY KEY,
    DayTypeName nvarchar(100) NOT NULL CONSTRAINT UQ_DimDayType_Name UNIQUE
);
GO

CREATE TABLE warehouse.DimDataSource
(
    DataSourceKey int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_DimDataSource PRIMARY KEY,
    SourceId nvarchar(200) NOT NULL CONSTRAINT UQ_DimDataSource_SourceId UNIQUE,
    SourceUrl nvarchar(2048) NULL,
    SourceNotes nvarchar(max) NULL
);
GO

CREATE TABLE warehouse.FactTransitMetric
(
    FactTransitMetricKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactTransitMetric PRIMARY KEY,
    RecordType nvarchar(64) NOT NULL,
    PeriodStartDateKey int NULL,
    PeriodEndDateKey int NULL,
    OperatorKey int NOT NULL,
    ServiceKey int NOT NULL,
    RouteKey int NOT NULL,
    LineTypeKey int NOT NULL,
    DayTypeKey int NOT NULL,
    DataSourceKey int NOT NULL,
    MetricName nvarchar(100) NOT NULL,
    MetricValue decimal(19, 4) NULL,
    UnitName nvarchar(100) NULL,
    DataStatus nvarchar(100) NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT FK_FactTransitMetric_StartDate FOREIGN KEY (PeriodStartDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactTransitMetric_EndDate FOREIGN KEY (PeriodEndDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactTransitMetric_Operator FOREIGN KEY (OperatorKey) REFERENCES warehouse.DimOperator(OperatorKey),
    CONSTRAINT FK_FactTransitMetric_Service FOREIGN KEY (ServiceKey) REFERENCES warehouse.DimService(ServiceKey),
    CONSTRAINT FK_FactTransitMetric_Route FOREIGN KEY (RouteKey) REFERENCES warehouse.DimRoute(RouteKey),
    CONSTRAINT FK_FactTransitMetric_LineType FOREIGN KEY (LineTypeKey) REFERENCES warehouse.DimLineType(LineTypeKey),
    CONSTRAINT FK_FactTransitMetric_DayType FOREIGN KEY (DayTypeKey) REFERENCES warehouse.DimDayType(DayTypeKey),
    CONSTRAINT FK_FactTransitMetric_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE TABLE warehouse.FactGtfsSnapshot
(
    FactGtfsSnapshotKey bigint IDENTITY(1, 1) NOT NULL CONSTRAINT PK_FactGtfsSnapshot PRIMARY KEY,
    PeriodStartDateKey int NULL,
    PeriodEndDateKey int NULL,
    OperatorKey int NOT NULL,
    ServiceKey int NOT NULL,
    DataSourceKey int NOT NULL,
    MetricName nvarchar(100) NOT NULL,
    MetricValue decimal(19, 4) NULL,
    UnitName nvarchar(100) NULL,
    DataStatus nvarchar(100) NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT FK_FactGtfsSnapshot_StartDate FOREIGN KEY (PeriodStartDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactGtfsSnapshot_EndDate FOREIGN KEY (PeriodEndDateKey) REFERENCES warehouse.DimDate(DateKey),
    CONSTRAINT FK_FactGtfsSnapshot_Operator FOREIGN KEY (OperatorKey) REFERENCES warehouse.DimOperator(OperatorKey),
    CONSTRAINT FK_FactGtfsSnapshot_Service FOREIGN KEY (ServiceKey) REFERENCES warehouse.DimService(ServiceKey),
    CONSTRAINT FK_FactGtfsSnapshot_Source FOREIGN KEY (DataSourceKey) REFERENCES warehouse.DimDataSource(DataSourceKey)
);
GO

CREATE INDEX IX_FactTransitMetric_Period ON warehouse.FactTransitMetric(PeriodStartDateKey, PeriodEndDateKey);
GO
CREATE INDEX IX_FactTransitMetric_ServiceRoute ON warehouse.FactTransitMetric(ServiceKey, RouteKey, MetricName);
GO
CREATE INDEX IX_FactGtfsSnapshot_Period ON warehouse.FactGtfsSnapshot(PeriodStartDateKey, PeriodEndDateKey);
GO
