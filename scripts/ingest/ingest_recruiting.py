import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

# Recruiting classes that feed into the 2022–2025 rosters
# A team's 2025 roster reflects classes from ~2022–2025
SEASONS = [2020, 2021, 2022, 2023, 2024, 2025]

def fetch_recruiting(year):
    url = "https://api.collegefootballdata.com/recruiting/teams"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "accept": "application/json"
    }
    params = {"year": year}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json()

def insert_recruiting(records, year):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO raw.recruiting (
            year, team,
            points, rank,
            commits
        ) VALUES (
            %(year)s, %(team)s,
            %(points)s, %(rank)s,
            %(commits)s
        )
        ON CONFLICT (year, team) DO UPDATE SET
            points       = EXCLUDED.points,
            rank         = EXCLUDED.rank,
            commits      = EXCLUDED.commits,
            _ingested_at = NOW();
    """

    inserted = 0
    for r in records:
        cur.execute(insert_sql, {
            "year":    year,
            "team":    r.get("team"),
            "points":  r.get("points"),
            "rank":    r.get("rank"),
            "commits": r.get("commits"),
        })
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    return inserted

if __name__ == "__main__":
    total = 0
    for season in SEASONS:
        print(f"Fetching recruiting data for class of {season}...")
        records = fetch_recruiting(season)
        print(f"  Retrieved {len(records)} team records.")
        n = insert_recruiting(records, season)
        total += n
        print(f"  Inserted/updated {n} records.")
    print(f"\nDone. Total records processed: {total}")
