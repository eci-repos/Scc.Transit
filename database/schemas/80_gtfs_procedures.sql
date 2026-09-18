CREATE PROCEDURE warehouse.usp_LoadGtfsStatic
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    INSERT INTO warehouse.DimDataSource (SourceId, SourceUrl, SourceNotes)
    SELECT SourceId, MAX(SourceUrl), N'VTA GTFS static feed loaded from staging.'
    FROM
    (
        SELECT SourceId, SourceUrl FROM staging.RawGtfsRoute
        UNION ALL SELECT SourceId, SourceUrl FROM staging.RawGtfsTrip
        UNION ALL SELECT SourceId, SourceUrl FROM staging.RawGtfsStop
        UNION ALL SELECT SourceId, SourceUrl FROM staging.RawGtfsShapePoint
    ) AS sources
    WHERE NOT EXISTS
    (
        SELECT 1 FROM warehouse.DimDataSource AS d WHERE d.SourceId = sources.SourceId
    )
    GROUP BY SourceId;

    DELETE f
    FROM warehouse.FactGtfsShapePoint AS f
    JOIN warehouse.DimDataSource AS d ON d.DataSourceKey = f.DataSourceKey
    WHERE EXISTS (SELECT 1 FROM staging.RawGtfsShapePoint AS s WHERE s.SourceId = d.SourceId);

    DELETE r
    FROM warehouse.DimGtfsRoute AS r
    JOIN warehouse.DimDataSource AS d ON d.DataSourceKey = r.DataSourceKey
    WHERE EXISTS (SELECT 1 FROM staging.RawGtfsRoute AS s WHERE s.SourceId = d.SourceId);

    DELETE s
    FROM warehouse.DimGtfsStop AS s
    JOIN warehouse.DimDataSource AS d ON d.DataSourceKey = s.DataSourceKey
    WHERE EXISTS (SELECT 1 FROM staging.RawGtfsStop AS rawStop WHERE rawStop.SourceId = d.SourceId);

    INSERT INTO warehouse.DimGtfsRoute
    (DataSourceKey, RouteId, RouteShortName, RouteLongName, RouteType, RouteUrl, RouteColor, RouteTextColor)
    SELECT d.DataSourceKey, r.RouteId, r.RouteShortName, r.RouteLongName, r.RouteType, r.RouteUrl, r.RouteColor, r.RouteTextColor
    FROM staging.RawGtfsRoute AS r
    JOIN warehouse.DimDataSource AS d ON d.SourceId = r.SourceId;

    INSERT INTO warehouse.DimGtfsStop
    (DataSourceKey, StopId, StopCode, StopName, StopLat, StopLon, LocationType, ParentStation, WheelchairBoarding)
    SELECT d.DataSourceKey, s.StopId, s.StopCode, s.StopName, s.StopLat, s.StopLon, s.LocationType, s.ParentStation, s.WheelchairBoarding
    FROM staging.RawGtfsStop AS s
    JOIN warehouse.DimDataSource AS d ON d.SourceId = s.SourceId;

    INSERT INTO warehouse.FactGtfsShapePoint
    (DataSourceKey, GtfsRouteKey, ShapeId, ShapePointSequence, ShapePointLat, ShapePointLon, ShapeDistTraveled)
    SELECT
        d.DataSourceKey,
        r.GtfsRouteKey,
        s.ShapeId,
        s.ShapePointSequence,
        s.ShapePointLat,
        s.ShapePointLon,
        s.ShapeDistTraveled
    FROM staging.RawGtfsShapePoint AS s
    JOIN warehouse.DimDataSource AS d ON d.SourceId = s.SourceId
    OUTER APPLY
    (
        SELECT TOP (1) rt.RouteId
        FROM staging.RawGtfsTrip AS rt
        WHERE rt.SourceId = s.SourceId AND rt.ShapeId = s.ShapeId
        ORDER BY rt.TripId
    ) AS trip
    LEFT JOIN warehouse.DimGtfsRoute AS r ON r.DataSourceKey = d.DataSourceKey AND r.RouteId = trip.RouteId;

    COMMIT TRANSACTION;
END;
GO

CREATE PROCEDURE warehouse.usp_LoadVehiclePositions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    INSERT INTO warehouse.DimDataSource (SourceId, SourceUrl, SourceNotes)
    SELECT SourceId, MAX(SourceUrl), N'VTA GTFS-Realtime vehicle positions.'
    FROM staging.RawVehiclePosition AS s
    WHERE NOT EXISTS
    (
        SELECT 1 FROM warehouse.DimDataSource AS d WHERE d.SourceId = s.SourceId
    )
    GROUP BY SourceId;

    DELETE f
    FROM warehouse.FactVehiclePosition AS f
    JOIN staging.RawVehiclePosition AS s ON s.RawVehiclePositionKey = f.RawVehiclePositionKey;

    INSERT INTO warehouse.FactVehiclePosition
    (
        RawVehiclePositionKey, ObservedAtUtc, VehicleId, TripId, RouteId, GtfsRouteKey,
        Latitude, Longitude, Bearing, SpeedMph, CurrentStopSequence, CurrentStatus,
        OccupancyStatus, DataSourceKey, Notes
    )
    SELECT
        s.RawVehiclePositionKey,
        s.ObservedAtUtc,
        s.VehicleId,
        s.TripId,
        s.RouteId,
        r.GtfsRouteKey,
        s.Latitude,
        s.Longitude,
        s.Bearing,
        s.SpeedMph,
        s.CurrentStopSequence,
        s.CurrentStatus,
        s.OccupancyStatus,
        d.DataSourceKey,
        s.Notes
    FROM staging.RawVehiclePosition AS s
    JOIN warehouse.DimDataSource AS d ON d.SourceId = s.SourceId
    LEFT JOIN warehouse.DimGtfsRoute AS r ON r.DataSourceKey = d.DataSourceKey AND r.RouteId = s.RouteId;

    COMMIT TRANSACTION;
END;
GO
