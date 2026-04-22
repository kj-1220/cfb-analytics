import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

# Pull SP+ for these seasons — covers the range used in raw.games
SEASONS = [2022, 2023, 2024, 2025]

def fetch_sp_ratings(year):
    url = "https://api.collegefootballdata.com/ratings/sp"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "accept": "application/json"
    }
    params = {"year": year}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json()

def insert_sp_ratings(ratings, year):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO raw.sp_ratings (
            year, team, conference,
            rating, ranking,
            offense_ranking, offense_rating,
            defense_ranking, defense_rating,
            special_teams_rating
        ) VALUES (
            %(year)s, %(team)s, %(conference)s,
            %(rating)s, %(ranking)s,
            %(offense_ranking)s, %(offense_rating)s,
            %(defense_ranking)s, %(defense_rating)s,
            %(special_teams_rating)s
        )
        ON CONFLICT (year, team) DO UPDATE SET
            rating               = EXCLUDED.rating,
            ranking              = EXCLUDED.ranking,
            offense_rating       = EXCLUDED.offense_rating,
            defense_rating       = EXCLUDED.defense_rating,
            special_teams_rating = EXCLUDED.special_teams_rating,
            _ingested_at         = NOW();
    """

    inserted = 0
    for r in ratings:
        offense  = r.get("offense")  or {}
        defense  = r.get("defense")  or {}
        sp_teams = r.get("specialTeams") or {}
        cur.execute(insert_sql, {
            "year":                 year,
            "team":                 r.get("team"),
            "conference":           r.get("conference"),
            "rating":               r.get("rating"),
            "ranking":              r.get("ranking"),
            "offense_ranking":      offense.get("ranking"),
            "offense_rating":       offense.get("rating"),
            "defense_ranking":      defense.get("ranking"),
            "defense_rating":       defense.get("rating"),
            "special_teams_rating": sp_teams.get("rating"),
        })
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    return inserted

if __name__ == "__main__":
    total = 0
    for season in SEASONS:
        print(f"Fetching SP+ ratings for {season}...")
        ratings = fetch_sp_ratings(season)
        print(f"  Retrieved {len(ratings)} records.")
        n = insert_sp_ratings(ratings, season)
        total += n
        print(f"  Inserted/updated {n} records.")
    print(f"\nDone. Total records processed: {total}")
