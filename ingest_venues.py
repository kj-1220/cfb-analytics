import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

def fetch_venues():
    url = "https://api.collegefootballdata.com/venues"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "accept": "application/json"
    }
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def insert_venues(venues):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO raw.venues (
            id, name, capacity, grass,
            city, state, zip, country_code,
            elevation, latitude, longitude,
            dome, timezone
        ) VALUES (
            %(id)s, %(name)s, %(capacity)s, %(grass)s,
            %(city)s, %(state)s, %(zip)s, %(country_code)s,
            %(elevation)s, %(latitude)s, %(longitude)s,
            %(dome)s, %(timezone)s
        )
        ON CONFLICT (id) DO UPDATE SET
            capacity     = EXCLUDED.capacity,
            elevation    = EXCLUDED.elevation,
            latitude     = EXCLUDED.latitude,
            longitude    = EXCLUDED.longitude,
            _ingested_at = NOW();
    """

    inserted = 0
    for venue in venues:
        cur.execute(insert_sql, {
            "id":           venue.get("id"),
            "name":         venue.get("name"),
            "capacity":     venue.get("capacity"),
            "grass":        venue.get("grass"),
            "city":         venue.get("city"),
            "state":        venue.get("state"),
            "zip":          venue.get("zip"),
            "country_code": venue.get("countryCode"),
            "elevation":    venue.get("elevation"),
            "latitude":     venue.get("latitude"),
            "longitude":    venue.get("longitude"),
            "dome":         venue.get("dome"),
            "timezone":     venue.get("timezone"),
        })
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(f"Inserted/updated {inserted} venues.")

if __name__ == "__main__":
    print("Fetching venues...")
    venues = fetch_venues()
    print(f"Retrieved {len(venues)} venues from API.")
    insert_venues(venues)
    print("Done.")
