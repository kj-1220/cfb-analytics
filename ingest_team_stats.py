import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.expanduser("~/cfb-analytics/.env"))

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"
SEASONS = [2022, 2023, 2024, 2025]

def fetch_team_stats(year):
    url = "https://api.collegefootballdata.com/stats/season"
    headers = {"Authorization": f"Bearer {API_KEY}", "accept": "application/json"}
    r = requests.get(url, headers=headers, params={"year": year})
    r.raise_for_status()
    return r.json()

def pivot_stats(records):
    """
    The API returns one row per (team, statName, statValue).
    This pivots it into one row per team with all stats as columns.
    """
    teams = {}
    for r in records:
        team = r["team"]
        if team not in teams:
            teams[team] = {"team": team, "conference": r.get("conference")}
        # Convert camelCase statName to snake_case column name
        stat = r["statName"]
        col = ''.join(['_' + c.lower() if c.isupper() else c for c in stat]).lstrip('_')
        teams[team][col] = r["statValue"]
    return list(teams.values())

def insert_team_stats(rows, year):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()
    inserted = 0
    for row in rows:
        cur.execute("""
            INSERT INTO raw.team_stats (
                year, team, conference, games,
                total_yards, net_passing_yards, rushing_yards,
                pass_attempts, pass_completions, passing_tds,
                rushing_attempts, rushing_tds,
                first_downs, third_downs, third_down_conversions,
                fourth_downs, fourth_down_conversions,
                kick_return_yards, kick_returns, kick_return_tds,
                punt_return_yards, punt_returns, punt_return_tds,
                possession_time, penalties, penalty_yards,
                fumbles_lost, fumbles_recovered,
                interceptions, interception_yards, interception_tds,
                total_yards_opponent, net_passing_yards_opponent, rushing_yards_opponent,
                pass_attempts_opponent, pass_completions_opponent, passing_tds_opponent,
                rushing_attempts_opponent, rushing_tds_opponent,
                first_downs_opponent, third_downs_opponent, third_down_conversions_opponent,
                fourth_downs_opponent, fourth_down_conversions_opponent,
                sacks, sacks_opponent,
                tackles_for_loss, tackles_for_loss_opponent,
                turnovers, turnovers_opponent,
                passes_intercepted, passes_intercepted_opponent,
                fumbles_recovered_opponent,
                penalties_opponent, penalty_yards_opponent, possession_time_opponent
            ) VALUES (
                %(year)s, %(team)s, %(conference)s, %(games)s,
                %(total_yards)s, %(net_passing_yards)s, %(rushing_yards)s,
                %(pass_attempts)s, %(pass_completions)s, %(passing_t_ds)s,
                %(rushing_attempts)s, %(rushing_t_ds)s,
                %(first_downs)s, %(third_downs)s, %(third_down_conversions)s,
                %(fourth_downs)s, %(fourth_down_conversions)s,
                %(kick_return_yards)s, %(kick_returns)s, %(kick_return_t_ds)s,
                %(punt_return_yards)s, %(punt_returns)s, %(punt_return_t_ds)s,
                %(possession_time)s, %(penalties)s, %(penalty_yards)s,
                %(fumbles_lost)s, %(fumbles_recovered)s,
                %(interceptions)s, %(interception_yards)s, %(interception_t_ds)s,
                %(total_yards_opponent)s, %(net_passing_yards_opponent)s, %(rushing_yards_opponent)s,
                %(pass_attempts_opponent)s, %(pass_completions_opponent)s, %(passing_t_ds_opponent)s,
                %(rushing_attempts_opponent)s, %(rushing_t_ds_opponent)s,
                %(first_downs_opponent)s, %(third_downs_opponent)s, %(third_down_conversions_opponent)s,
                %(fourth_downs_opponent)s, %(fourth_down_conversions_opponent)s,
                %(sacks)s, %(sacks_opponent)s,
                %(tackles_for_loss)s, %(tackles_for_loss_opponent)s,
                %(turnovers)s, %(turnovers_opponent)s,
                %(passes_intercepted)s, %(passes_intercepted_opponent)s,
                %(fumbles_recovered_opponent)s,
                %(penalties_opponent)s, %(penalty_yards_opponent)s, %(possession_time_opponent)s
            )
            ON CONFLICT (year, team) DO UPDATE SET
                games = EXCLUDED.games,
                total_yards = EXCLUDED.total_yards,
                _ingested_at = NOW();
        """, {**row, "year": year})
        inserted += 1
    conn.commit()
    cur.close()
    conn.close()
    return inserted

if __name__ == "__main__":
    total = 0
    for season in SEASONS:
        print(f"Fetching team stats for {season}...")
        raw = fetch_team_stats(season)
        rows = pivot_stats(raw)
        print(f"  Pivoted {len(raw)} stat records into {len(rows)} team rows.")
        n = insert_team_stats(rows, season)
        total += n
        print(f"  Inserted/updated {n} rows.")
    print(f"\nDone. Total: {total} rows.")
