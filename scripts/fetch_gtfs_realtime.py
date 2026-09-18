import argparse
import csv
import datetime as dt
import pathlib
import urllib.parse
import urllib.request

from google.transit import gtfs_realtime_pb2


def utc_timestamp(value):
    if not value:
        return ""
    return dt.datetime.fromtimestamp(value, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def text_value(translated_text):
    if translated_text and translated_text.translation:
        return translated_text.translation[0].text
    return ""


def request_feed(url, api_key):
    request_url = url
    if api_key:
        separator = "&" if "?" in request_url else "?"
        request_url = f"{request_url}{separator}{urllib.parse.urlencode({'api_key': api_key})}"
    with urllib.request.urlopen(request_url, timeout=30) as response:
        payload = response.read()
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(payload)
    return feed, request_url


def write_trip_updates(feed, output_path, source_id, source_url):
    fields = ["observed_at_utc", "trip_id", "route_id", "vehicle_id", "stop_id", "stop_sequence", "arrival_time_utc", "departure_time_utc", "arrival_delay_seconds", "departure_delay_seconds", "schedule_relationship", "source_id", "source_url", "notes"]
    with output_path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        observed = feed.header.timestamp
        for entity in feed.entity:
            if not entity.HasField("trip_update"):
                continue
            update = entity.trip_update
            trip = update.trip if update.HasField("trip") else None
            vehicle = update.vehicle if update.HasField("vehicle") else None
            for stop_update in update.stop_time_update:
                arrival = stop_update.arrival if stop_update.HasField("arrival") else None
                departure = stop_update.departure if stop_update.HasField("departure") else None
                writer.writerow({
                    "observed_at_utc": utc_timestamp(observed),
                    "trip_id": trip.trip_id if trip and trip.HasField("trip_id") else "",
                    "route_id": trip.route_id if trip and trip.HasField("route_id") else "",
                    "vehicle_id": vehicle.id if vehicle and vehicle.HasField("id") else "",
                    "stop_id": stop_update.stop_id if stop_update.HasField("stop_id") else "",
                    "stop_sequence": stop_update.stop_sequence if stop_update.HasField("stop_sequence") else "",
                    "arrival_time_utc": utc_timestamp(arrival.time) if arrival and arrival.HasField("time") else "",
                    "departure_time_utc": utc_timestamp(departure.time) if departure and departure.HasField("time") else "",
                    "arrival_delay_seconds": arrival.delay if arrival and arrival.HasField("delay") else "",
                    "departure_delay_seconds": departure.delay if departure and departure.HasField("delay") else "",
                    "schedule_relationship": trip.schedule_relationship if trip and trip.HasField("schedule_relationship") else "",
                    "source_id": source_id,
                    "source_url": source_url,
                    "notes": "Fetched from GTFS-Realtime trip updates.",
                })


def write_alerts(feed, output_path, source_id, source_url):
    fields = ["observed_at_utc", "alert_id", "cause", "effect", "header_text", "description_text", "active_start_utc", "active_end_utc", "route_id", "stop_id", "source_id", "source_url", "notes"]
    with output_path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        observed = feed.header.timestamp
        for entity in feed.entity:
            if not entity.HasField("alert"):
                continue
            alert = entity.alert
            periods = list(alert.active_period) or [None]
            entities = list(alert.informed_entity) or [None]
            for period in periods:
                for informed in entities:
                    writer.writerow({
                        "observed_at_utc": utc_timestamp(observed),
                        "alert_id": entity.id,
                        "cause": alert.cause if alert.HasField("cause") else "",
                        "effect": alert.effect if alert.HasField("effect") else "",
                        "header_text": text_value(alert.header_text),
                        "description_text": text_value(alert.description_text),
                        "active_start_utc": utc_timestamp(period.start) if period and period.HasField("start") else "",
                        "active_end_utc": utc_timestamp(period.end) if period and period.HasField("end") else "",
                        "route_id": informed.route_id if informed and informed.HasField("route_id") else "",
                        "stop_id": informed.stop_id if informed and informed.HasField("stop_id") else "",
                        "source_id": source_id,
                        "source_url": source_url,
                        "notes": "Fetched from GTFS-Realtime service alerts.",
                    })


def main():
    parser = argparse.ArgumentParser(description="Fetch GTFS-Realtime trip updates or service alerts into CSV.")
    parser.add_argument("--feed-type", choices=["trip_updates", "service_alerts"], required=True)
    parser.add_argument("--url", default="")
    parser.add_argument("--api-key", default="", help="511.org API key, if required by the feed.")
    parser.add_argument("--output", default="")
    parser.add_argument("--source-id", default="")
    args = parser.parse_args()

    default_url = {
        "trip_updates": "https://api.511.org/transit/tripupdates?agency=SC",
        "service_alerts": "https://api.511.org/transit/servicealerts?agency=SC",
    }[args.feed_type]
    url = args.url or default_url
    source_id = args.source_id or f"vta_gtfsrt_{args.feed_type}"
    output_path = pathlib.Path(args.output or f"data/.cache/{args.feed_type}.csv")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    feed, request_url = request_feed(url, args.api_key)
    if args.feed_type == "trip_updates":
        write_trip_updates(feed, output_path, source_id, request_url)
    else:
        write_alerts(feed, output_path, source_id, request_url)
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
