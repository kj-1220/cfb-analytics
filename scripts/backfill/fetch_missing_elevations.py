#!/usr/bin/env python3
import psycopg2
import requests
import csv
import time
import os

conn = psycopg2.connect(
    host='127.0.0.1', port=5455, dbname='postgres',
    user='postgres', password='postgres'
)
cur = conn.cursor()
cur.execute("""
    SELECT DISTINCT v.venue_id, v.venue_name, v.latitude, v.longitude
    FROM stg.stg_venues v
    LEFT JOIN stg.venue_elevations e ON v.venue_id = e.venue_id
    JOIN raw.games g ON g.venue_id = v.venue_id
    WHERE e.elevation_feet IS NULL
    AND v.latitude IS NOT NULL
    AND v.longitude IS NOT NULL
    AND g.home_conference IN (
        'ACC','Big 12','Big Ten','SEC','Pac-12',
        'Mountain West','American Athletic','Sun Belt',
        'Mid-American','Conference USA','FBS Independents'
    )
    AND g.season >= 2022
    ORDER BY v.venue_id
""")
venues = cur.fetchall()
conn.close()

print(f"Venues to fetch: {len(venues)}")

BATCH_SIZE = 100
METERS_TO_FEET = 3.28084
results = []

for i in range(0, len(venues), BATCH_SIZE):
    batch = venues[i:i + BATCH_SIZE]
    lats  = ','.join(str(float(v[2])) for v in batch)
    lons  = ','.join(str(float(v[3])) for v in batch)

    url = f"https://api.open-meteo.com/v1/elevation?latitude={lats}&longitude={lons}"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()

    data = resp.json()
    elevations_m = data.get('elevation', [])

    for j, venue in enumerate(batch):
        venue_id, venue_name, lat, lon = venue
        if j < len(elevations_m) and elevations_m[j] is not None:
            elev_ft = round(float(elevations_m[j]) * METERS_TO_FEET, 1)
            results.append((venue_id, venue_name, elev_ft))
            print(f"  {venue_name:<50} {elev_ft:>8.1f} ft")
        else:
            print(f"  {venue_name:<50} — no elevation returned")

    if i + BATCH_SIZE < len(venues):
        time.sleep(0.5)

print(f"\nFetched {len(results)} elevations")

seed_path = os.path.expanduser(
    '~/cfb-analytics/cfb_analytics/seeds/venue_elevations.csv')

with open(seed_path, 'a', newline='') as f:
    writer = csv.writer(f)
    for venue_id, venue_name, elev_ft in results:
        writer.writerow([venue_id, venue_name, elev_ft])

print(f"Appended {len(results)} rows to {seed_path}")
