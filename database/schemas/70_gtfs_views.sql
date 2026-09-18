CREATE VIEW mart.vw_GtfsStops
AS
SELECT
    src.SourceId,
    src.SourceUrl,
    r.StopId,
    r.StopCode,
    r.StopName,
    r.StopLat,
    r.StopLon,
    r.LocationType,
    r.ParentStation,
    r.WheelchairBoarding
FROM warehouse.DimGtfsStop AS r
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = r.DataSourceKey;
GO

CREATE VIEW mart.vw_GtfsRouteShapes
AS
SELECT
    src.SourceId,
    src.SourceUrl,
    r.RouteId,
    r.RouteShortName,
    r.RouteLongName,
    r.RouteType,
    f.ShapeId,
    f.ShapePointSequence,
    f.ShapePointLat,
    f.ShapePointLon,
    f.ShapeDistTraveled
FROM warehouse.FactGtfsShapePoint AS f
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey
LEFT JOIN warehouse.DimGtfsRoute AS r ON r.GtfsRouteKey = f.GtfsRouteKey;
GO

CREATE VIEW mart.vw_VehiclePositionsLatest
AS
WITH RankedPositions AS
(
    SELECT
        f.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY f.DataSourceKey, f.VehicleId
            ORDER BY f.ObservedAtUtc DESC, f.FactVehiclePositionKey DESC
        ) AS PositionRank
    FROM warehouse.FactVehiclePosition AS f
)
SELECT
    f.ObservedAtUtc,
    f.VehicleId,
    f.TripId,
    f.RouteId,
    r.RouteShortName,
    r.RouteLongName,
    f.Latitude,
    f.Longitude,
    f.Bearing,
    f.SpeedMph,
    f.CurrentStopSequence,
    f.CurrentStatus,
    f.OccupancyStatus,
    src.SourceId,
    src.SourceUrl,
    f.Notes
FROM RankedPositions AS f
JOIN warehouse.DimDataSource AS src ON src.DataSourceKey = f.DataSourceKey
LEFT JOIN warehouse.DimGtfsRoute AS r ON r.GtfsRouteKey = f.GtfsRouteKey
WHERE f.PositionRank = 1;
GO
