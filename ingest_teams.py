import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

def fetch_teams():
    url = "https://api.collegefootballdata.com/teams"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "accept": "application/json"
    }
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def insert_teams(teams):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO raw.teams (
            id, school, mascot, abbreviation,
            conference, division, classification,
            color, alt_color,
            city, state, zip, country,
            latitude, longitude, timezone
        ) VALUES (
            %(id)s, %(school)s, %(mascot)s, %(abbreviation)s,
            %(conference)s, %(division)s, %(classification)s,
            %(color)s, %(alt_color)s,
            %(city)s, %(state)s, %(zip)s, %(country)s,
            %(latitude)s, %(longitude)s, %(timezone)s
        )
        ON CONFLICT (id) DO UPDATE SET
            conference    = EXCLUDED.conference,
            division      = EXCLUDED.division,
            classification = EXCLUDED.classification,
            _ingested_at  = NOW();
    """

    inserted = 0
    for team in teams:
        location = team.get("location") or {}
        cur.execute(insert_sql, {
            "id":             team.get("id"),
            "school":         team.get("school"),
            "mascot":         team.get("mascot"),
            "abbreviation":   team.get("abbreviation"),
            "conference":     team.get("conference"),
            "division":       team.get("division"),
            "classification": team.get("classification"),
            "color":          team.get("color"),
            "alt_color":      team.get("alt_color"),
            "city":           location.get("city"),
            "state":          location.get("state"),
            "zip":            location.get("zip"),
            "country":        location.get("country_code"),
            "latitude":       location.get("latitude"),
            "longitude":      location.get("longitude"),
            "timezone":       location.get("timezone"),
        })
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(f"Inserted/updated {inserted} teams.")

if __name__ == "__main__":
    print("Fetching teams...")
    teams = fetch_teams()
    print(f"Retrieved {len(teams)} teams from API.")
    insert_teams(teams)
    print("Done.")
