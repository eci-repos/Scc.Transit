DELETE FROM warehouse.FactGtfsSnapshot;
DELETE FROM warehouse.FactTransitMetric;
DELETE FROM warehouse.DimDataSource;
DELETE FROM warehouse.DimDayType;
DELETE FROM warehouse.DimLineType;
DELETE FROM warehouse.DimRoute;
DELETE FROM warehouse.DimService;
DELETE FROM warehouse.DimOperator;
DELETE FROM warehouse.DimDate;
TRUNCATE TABLE staging.RawTransitData;
GO
