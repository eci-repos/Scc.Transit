import argparse
import csv
import datetime as dt
import urllib.parse
import urllib.request

from google.transit import gtfs_realtime_pb2


def timestamp_to_utc(value):
    if not value:
        return ""
    return dt.datetime.fromtimestamp(value, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def main():
    parser = argparse.ArgumentParser(description="Fetch VTA GTFS-Realtime vehicle positions into CSV.")
    parser.add_argument("--url", default="https://api.511.org/transit/vehiclepositions?agency=SC")
    parser.add_argument("--api-key", default="", help="511.org API key, if required by the feed.")
    parser.add_argument("--output", default="data/.cache/vehicle_positions.csv")
    parser.add_argument("--source-id", default="vta_gtfsrt_vehicle_positions")
    args = parser.parse_args()

    request_url = args.url
    if args.api_key:
        separator = "&" if "?" in request_url else "?"
        request_url = f"{request_url}{separator}{urllib.parse.urlencode({'api_key': args.api_key})}"
    with urllib.request.urlopen(request_url, timeout=30) as response:
        payload = response.read()

    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(payload)

    fieldnames = [
        "observed_at_utc", "vehicle_id", "trip_id", "route_id", "latitude", "longitude",
        "bearing", "speed_mph", "current_stop_sequence", "current_status", "occupancy_status",
        "source_id", "source_url", "notes",
    ]
    output_dir = __import__("pathlib").Path(args.output).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(args.output, "w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        for entity in feed.entity:
            if not entity.HasField("vehicle"):
                continue
            vehicle = entity.vehicle
            trip = vehicle.trip if vehicle.HasField("trip") else None
            position = vehicle.position if vehicle.HasField("position") else None
            if position is None or not position.HasField("latitude") or not position.HasField("longitude"):
                continue
            vehicle_descriptor = vehicle.vehicle if vehicle.HasField("vehicle") else None
            writer.writerow({
                "observed_at_utc": timestamp_to_utc(vehicle.timestamp if vehicle.HasField("timestamp") else feed.header.timestamp),
                "vehicle_id": vehicle_descriptor.id if vehicle_descriptor and vehicle_descriptor.HasField("id") else entity.id,
                "trip_id": trip.trip_id if trip and trip.HasField("trip_id") else "",
                "route_id": trip.route_id if trip and trip.HasField("route_id") else "",
                "latitude": position.latitude,
                "longitude": position.longitude,
                "bearing": position.bearing if position.HasField("bearing") else "",
                "speed_mph": (position.speed * 2.2369362921) if position.HasField("speed") else "",
                "current_stop_sequence": vehicle.current_stop_sequence if vehicle.HasField("current_stop_sequence") else "",
                "current_status": vehicle.current_status if vehicle.HasField("current_status") else "",
                "occupancy_status": vehicle.occupancy_status if vehicle.HasField("occupancy_status") else "",
                "source_id": args.source_id,
                "source_url": request_url,
                "notes": "Fetched from VTA GTFS-Realtime vehicle positions.",
            })


if __name__ == "__main__":
    main()
