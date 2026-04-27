import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

def fetch_games(year, season_type="regular"):
    url = "https://api.collegefootballdata.com/games"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "accept": "application/json"
    }
    params = {"year": year, "seasonType": season_type}
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json()

def insert_games(games):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO raw.games (
            id, season, week, season_type, start_date,
            start_time_et, neutral_site, conference_game,
            attendance, venue_id, venue, home_team,
            home_conference, home_points, away_team,
            away_conference, away_points
        ) VALUES (
            %(id)s, %(season)s, %(week)s, %(season_type)s,
            %(start_date)s, %(start_time_et)s, %(neutral_site)s,
            %(conference_game)s, %(attendance)s, %(venue_id)s,
            %(venue)s, %(home_team)s, %(home_conference)s,
            %(home_points)s, %(away_team)s, %(away_conference)s,
            %(away_points)s
        )
        ON CONFLICT (id) DO NOTHING;
    """

    inserted = 0
    for game in games:
        cur.execute(insert_sql, {
            "id":               game.get("id"),
            "season":           game.get("season"),
            "week":             game.get("week"),
            "season_type":      game.get("seasonType"),
            "start_date":       game.get("startDate"),
            "start_time_et":    game.get("startTimeTBD"),
            "neutral_site":     game.get("neutralSite"),
            "conference_game":  game.get("conferenceGame"),
            "attendance":       game.get("attendance"),
            "venue_id":         game.get("venueId"),
            "venue":            game.get("venue"),
            "home_team":        game.get("homeTeam"),
            "home_conference":  game.get("homeConference"),
            "home_points":      game.get("homePoints"),
            "away_team":        game.get("awayTeam"),
            "away_conference":  game.get("awayConference"),
            "away_points":      game.get("awayPoints"),
        })
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(f"Inserted {inserted} games.")

if __name__ == "__main__":
    for year in [2022, 2023, 2024, 2025]:
        print(f"Fetching {year} regular season games...")
        games = fetch_games(year)
        print(f"Fetched {len(games)} games from API.")
        insert_games(games)