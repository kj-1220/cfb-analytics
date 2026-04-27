import requests
import psycopg2
import os
import time
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.expanduser("~/cfb-analytics/.env"))

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

# Season config: (year, max_week, include_postseason)
SEASONS = [
    (2022, 15, True),
    (2023, 15, True),
    (2024, 16, True),
    (2025, 16, True),
]

CHECKPOINT_FILE = os.path.expanduser("~/cfb-analytics/.plays_checkpoint")

def load_checkpoint():
    """Returns a set of 'year-week-seasonType' strings already completed."""
    if not os.path.exists(CHECKPOINT_FILE):
        return set()
    with open(CHECKPOINT_FILE) as f:
        return set(line.strip() for line in f if line.strip())

def save_checkpoint(key):
    with open(CHECKPOINT_FILE, "a") as f:
        f.write(key + "\n")

def fetch_plays(year, week, season_type):
    url = "https://api.collegefootballdata.com/plays"
    headers = {"Authorization": f"Bearer {API_KEY}", "accept": "application/json"}
    params = {"year": year, "week": week, "seasonType": season_type}
    r = requests.get(url, headers=headers, params=params)
    r.raise_for_status()
    return r.json()

def insert_plays(plays, year, week, season_type):
    if not plays:
        return 0
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()
    inserted = 0
    for p in plays:
        clock = p.get("clock") or {}
        cur.execute("""
            INSERT INTO raw.plays (
                id, game_id, drive_id, drive_number, play_number,
                season, week, season_type,
                offense, offense_conference, defense, defense_conference,
                home, away, offense_score, defense_score,
                period, clock_minutes, clock_seconds,
                yard_line, yards_to_goal, down, distance, yards_gained,
                scoring, play_type, play_text, ppa, wallclock
            ) VALUES (
                %(id)s, %(game_id)s, %(drive_id)s, %(drive_number)s, %(play_number)s,
                %(season)s, %(week)s, %(season_type)s,
                %(offense)s, %(offense_conference)s, %(defense)s, %(defense_conference)s,
                %(home)s, %(away)s, %(offense_score)s, %(defense_score)s,
                %(period)s, %(clock_minutes)s, %(clock_seconds)s,
                %(yard_line)s, %(yards_to_goal)s, %(down)s, %(distance)s, %(yards_gained)s,
                %(scoring)s, %(play_type)s, %(play_text)s, %(ppa)s, %(wallclock)s
            )
            ON CONFLICT (id) DO NOTHING;
        """, {
            "id":                  str(p.get("id")),
            "game_id":             p.get("gameId"),
            "drive_id":            str(p.get("driveId")),
            "drive_number":        p.get("driveNumber"),
            "play_number":         p.get("playNumber"),
            "season":              year,
            "week":                week,
            "season_type":         season_type,
            "offense":             p.get("offense"),
            "offense_conference":  p.get("offenseConference"),
            "defense":             p.get("defense"),
            "defense_conference":  p.get("defenseConference"),
            "home":                p.get("home"),
            "away":                p.get("away"),
            "offense_score":       p.get("offenseScore"),
            "defense_score":       p.get("defenseScore"),
            "period":              p.get("period"),
            "clock_minutes":       clock.get("minutes"),
            "clock_seconds":       clock.get("seconds"),
            "yard_line":           p.get("yardline"),
            "yards_to_goal":       p.get("yardsToGoal"),
            "down":                p.get("down"),
            "distance":            p.get("distance"),
            "yards_gained":        p.get("yardsGained"),
            "scoring":             p.get("scoring"),
            "play_type":           p.get("playType"),
            "play_text":           p.get("playText"),
            "ppa":                 p.get("ppa"),
            "wallclock":           p.get("wallclock"),
        })
        inserted += 1
    conn.commit()
    cur.close()
    conn.close()
    return inserted

if __name__ == "__main__":
    completed = load_checkpoint()
    grand_total = 0

    for year, max_week, include_postseason in SEASONS:
        season_types = ["regular"]
        if include_postseason:
            season_types.append("postseason")

        for season_type in season_types:
            # Postseason uses week numbers too — API returns results for week 1-4
            weeks = range(1, max_week + 1) if season_type == "regular" else range(1, 5)

            for week in weeks:
                key = f"{year}-{week}-{season_type}"
                if key in completed:
                    print(f"  SKIP {key} (already loaded)")
                    continue

                print(f"  Fetching {key}...", end=" ", flush=True)
                try:
                    plays = fetch_plays(year, week, season_type)
                    if not plays:
                        print("0 plays (bye week or end of postseason)")
                        save_checkpoint(key)
                        continue
                    n = insert_plays(plays, year, week, season_type)
                    grand_total += n
                    print(f"{n} plays inserted")
                    save_checkpoint(key)
                    time.sleep(0.5)  # be polite to the API
                except Exception as e:
                    print(f"ERROR: {e}")
                    print(f"  Stopping. Re-run the script to resume from this point.")
                    exit(1)

    print(f"\nDone. Grand total plays inserted: {grand_total}")
