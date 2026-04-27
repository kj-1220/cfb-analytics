#!/usr/bin/env python3
import csv
import time
import sys
import requests
import psycopg2

DB_DSN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"
USGS_URL = "https://epqs.nationalmap.gov/v1/json"
OUTPUT_CSV = "/Users/kevinjohnson/cfb-analytics/cfb_analytics/seeds/venue_elevations.csv"
DELAY_SECONDS = 0.5


def fetch_venues(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT venue_id, venue_name, latitude, longitude
            FROM stg.stg_venues
            WHERE elevation_feet IS NULL
              AND latitude IS NOT NULL
              AND longitude IS NOT NULL
            ORDER BY venue_id
        """)
        return cur.fetchall()


def query_usgs_elevation(latitude, longitude):
    params = {
        "x": float(longitude),
        "y": float(latitude),
        "units": "Feet",
        "output": "json",
    }
    resp = requests.get(USGS_URL, params=params, timeout=15)
    resp.raise_for_status()
    data = resp.json()
    elevation = data.get("value")
    if elevation is None or str(elevation).strip() in ("-1000000", ""):
        raise ValueError(f"Bad elevation value from API: {elevation!r}")
    return round(float(elevation), 1)


def main():
    conn = psycopg2.connect(DB_DSN)
    venues = fetch_venues(conn)
    conn.close()

    total = len(venues)
    print(f"Found {total} venues needing elevation backfill.\n")

    rows = []
    failed = []

    for i, (venue_id, venue_name, latitude, longitude) in enumerate(venues, start=1):
        print(f"[{i:>3}/{total}] {venue_name} (id={venue_id}) ... ", end="", flush=True)
        try:
            elevation = query_usgs_elevation(latitude, longitude)
            rows.append({"venue_id": venue_id, "venue_name": venue_name, "elevation_feet": elevation})
            print(f"{elevation} ft")
        except Exception as exc:
            failed.append({"venue_id": venue_id, "venue_name": venue_name, "error": str(exc)})
            print(f"FAILED — {exc}")
        time.sleep(DELAY_SECONDS)

    with open(OUTPUT_CSV, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["venue_id", "venue_name", "elevation_feet"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n--- Done ---")
    print(f"Backfilled : {len(rows)}")
    print(f"Failed     : {len(failed)}")
    if failed:
        print("\nFailed venues:")
        for v in failed:
            print(f"  venue_id={v['venue_id']}  {v['venue_name']}  error={v['error']}")

    print(f"\nFirst 10 rows of {OUTPUT_CSV}:")
    with open(OUTPUT_CSV, newline="") as f:
        reader = csv.DictReader(f)
        for j, row in enumerate(reader):
            if j >= 10:
                break
            print(f"  {row['venue_id']:>6}  {row['venue_name']:<40}  {row['elevation_feet']} ft")


if __name__ == "__main__":
    main()
