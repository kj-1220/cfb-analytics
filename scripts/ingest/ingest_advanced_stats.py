import requests
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.expanduser("~/cfb-analytics/.env"))

API_KEY = os.getenv("CFBD_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"
SEASONS = [2022, 2023, 2024, 2025]

def fetch_advanced_stats(year):
    url = "https://api.collegefootballdata.com/stats/season/advanced"
    headers = {"Authorization": f"Bearer {API_KEY}", "accept": "application/json"}
    r = requests.get(url, headers=headers, params={"year": year})
    r.raise_for_status()
    return r.json()

def insert_advanced_stats(records, year):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()
    inserted = 0
    for t in records:
        o = t.get("offense") or {}
        d = t.get("defense") or {}
        cur.execute("""
            INSERT INTO raw.advanced_stats (
                year, team, conference,
                off_plays, off_drives, off_ppa, off_total_ppa,
                off_success_rate, off_explosiveness, off_power_success, off_stuff_rate,
                off_line_yards, off_second_level_yards, off_open_field_yards,
                off_points_per_opportunity,
                off_field_position_avg_start, off_field_position_predicted_pts,
                off_havoc_total, off_havoc_front_seven, off_havoc_db,
                off_std_downs_rate, off_std_downs_ppa,
                off_std_downs_success_rate, off_std_downs_explosiveness,
                off_pass_downs_rate, off_pass_downs_ppa,
                off_pass_downs_success_rate, off_pass_downs_explosiveness,
                off_rushing_rate, off_rushing_ppa,
                off_rushing_success_rate, off_rushing_explosiveness,
                off_passing_rate, off_passing_ppa,
                off_passing_success_rate, off_passing_explosiveness,
                def_plays, def_drives, def_ppa, def_total_ppa,
                def_success_rate, def_explosiveness, def_power_success, def_stuff_rate,
                def_line_yards, def_second_level_yards, def_open_field_yards,
                def_points_per_opportunity,
                def_field_position_avg_start, def_field_position_predicted_pts,
                def_havoc_total, def_havoc_front_seven, def_havoc_db,
                def_std_downs_rate, def_std_downs_ppa,
                def_std_downs_success_rate, def_std_downs_explosiveness,
                def_pass_downs_rate, def_pass_downs_ppa,
                def_pass_downs_success_rate, def_pass_downs_explosiveness,
                def_rushing_rate, def_rushing_ppa,
                def_rushing_success_rate, def_rushing_explosiveness,
                def_passing_rate, def_passing_ppa,
                def_passing_success_rate, def_passing_explosiveness
            ) VALUES (
                %(year)s, %(team)s, %(conference)s,
                %(off_plays)s, %(off_drives)s, %(off_ppa)s, %(off_total_ppa)s,
                %(off_success_rate)s, %(off_explosiveness)s, %(off_power_success)s, %(off_stuff_rate)s,
                %(off_line_yards)s, %(off_second_level_yards)s, %(off_open_field_yards)s,
                %(off_points_per_opportunity)s,
                %(off_field_position_avg_start)s, %(off_field_position_predicted_pts)s,
                %(off_havoc_total)s, %(off_havoc_front_seven)s, %(off_havoc_db)s,
                %(off_std_downs_rate)s, %(off_std_downs_ppa)s,
                %(off_std_downs_success_rate)s, %(off_std_downs_explosiveness)s,
                %(off_pass_downs_rate)s, %(off_pass_downs_ppa)s,
                %(off_pass_downs_success_rate)s, %(off_pass_downs_explosiveness)s,
                %(off_rushing_rate)s, %(off_rushing_ppa)s,
                %(off_rushing_success_rate)s, %(off_rushing_explosiveness)s,
                %(off_passing_rate)s, %(off_passing_ppa)s,
                %(off_passing_success_rate)s, %(off_passing_explosiveness)s,
                %(def_plays)s, %(def_drives)s, %(def_ppa)s, %(def_total_ppa)s,
                %(def_success_rate)s, %(def_explosiveness)s, %(def_power_success)s, %(def_stuff_rate)s,
                %(def_line_yards)s, %(def_second_level_yards)s, %(def_open_field_yards)s,
                %(def_points_per_opportunity)s,
                %(def_field_position_avg_start)s, %(def_field_position_predicted_pts)s,
                %(def_havoc_total)s, %(def_havoc_front_seven)s, %(def_havoc_db)s,
                %(def_std_downs_rate)s, %(def_std_downs_ppa)s,
                %(def_std_downs_success_rate)s, %(def_std_downs_explosiveness)s,
                %(def_pass_downs_rate)s, %(def_pass_downs_ppa)s,
                %(def_pass_downs_success_rate)s, %(def_pass_downs_explosiveness)s,
                %(def_rushing_rate)s, %(def_rushing_ppa)s,
                %(def_rushing_success_rate)s, %(def_rushing_explosiveness)s,
                %(def_passing_rate)s, %(def_passing_ppa)s,
                %(def_passing_success_rate)s, %(def_passing_explosiveness)s
            )
            ON CONFLICT (year, team) DO UPDATE SET
                off_ppa          = EXCLUDED.off_ppa,
                off_success_rate = EXCLUDED.off_success_rate,
                def_ppa          = EXCLUDED.def_ppa,
                def_success_rate = EXCLUDED.def_success_rate,
                _ingested_at     = NOW();
        """, {
            "year": year, "team": t.get("team"), "conference": t.get("conference"),
            "off_plays": o.get("plays"), "off_drives": o.get("drives"),
            "off_ppa": o.get("ppa"), "off_total_ppa": o.get("totalPPA"),
            "off_success_rate": o.get("successRate"), "off_explosiveness": o.get("explosiveness"),
            "off_power_success": o.get("powerSuccess"), "off_stuff_rate": o.get("stuffRate"),
            "off_line_yards": o.get("lineYards"), "off_second_level_yards": o.get("secondLevelYards"),
            "off_open_field_yards": o.get("openFieldYards"),
            "off_points_per_opportunity": o.get("pointsPerOpportunity"),
            "off_field_position_avg_start": (o.get("fieldPosition") or {}).get("averageStart"),
            "off_field_position_predicted_pts": (o.get("fieldPosition") or {}).get("averagePredictedPoints"),
            "off_havoc_total": (o.get("havoc") or {}).get("total"),
            "off_havoc_front_seven": (o.get("havoc") or {}).get("frontSeven"),
            "off_havoc_db": (o.get("havoc") or {}).get("db"),
            "off_std_downs_rate": (o.get("standardDowns") or {}).get("rate"),
            "off_std_downs_ppa": (o.get("standardDowns") or {}).get("ppa"),
            "off_std_downs_success_rate": (o.get("standardDowns") or {}).get("successRate"),
            "off_std_downs_explosiveness": (o.get("standardDowns") or {}).get("explosiveness"),
            "off_pass_downs_rate": (o.get("passingDowns") or {}).get("rate"),
            "off_pass_downs_ppa": (o.get("passingDowns") or {}).get("ppa"),
            "off_pass_downs_success_rate": (o.get("passingDowns") or {}).get("successRate"),
            "off_pass_downs_explosiveness": (o.get("passingDowns") or {}).get("explosiveness"),
            "off_rushing_rate": (o.get("rushingPlays") or {}).get("rate"),
            "off_rushing_ppa": (o.get("rushingPlays") or {}).get("ppa"),
            "off_rushing_success_rate": (o.get("rushingPlays") or {}).get("successRate"),
            "off_rushing_explosiveness": (o.get("rushingPlays") or {}).get("explosiveness"),
            "off_passing_rate": (o.get("passingPlays") or {}).get("rate"),
            "off_passing_ppa": (o.get("passingPlays") or {}).get("ppa"),
            "off_passing_success_rate": (o.get("passingPlays") or {}).get("successRate"),
            "off_passing_explosiveness": (o.get("passingPlays") or {}).get("explosiveness"),
            "def_plays": d.get("plays"), "def_drives": d.get("drives"),
            "def_ppa": d.get("ppa"), "def_total_ppa": d.get("totalPPA"),
            "def_success_rate": d.get("successRate"), "def_explosiveness": d.get("explosiveness"),
            "def_power_success": d.get("powerSuccess"), "def_stuff_rate": d.get("stuffRate"),
            "def_line_yards": d.get("lineYards"), "def_second_level_yards": d.get("secondLevelYards"),
            "def_open_field_yards": d.get("openFieldYards"),
            "def_points_per_opportunity": d.get("pointsPerOpportunity"),
            "def_field_position_avg_start": (d.get("fieldPosition") or {}).get("averageStart"),
            "def_field_position_predicted_pts": (d.get("fieldPosition") or {}).get("averagePredictedPoints"),
            "def_havoc_total": (d.get("havoc") or {}).get("total"),
            "def_havoc_front_seven": (d.get("havoc") or {}).get("frontSeven"),
            "def_havoc_db": (d.get("havoc") or {}).get("db"),
            "def_std_downs_rate": (d.get("standardDowns") or {}).get("rate"),
            "def_std_downs_ppa": (d.get("standardDowns") or {}).get("ppa"),
            "def_std_downs_success_rate": (d.get("standardDowns") or {}).get("successRate"),
            "def_std_downs_explosiveness": (d.get("standardDowns") or {}).get("explosiveness"),
            "def_pass_downs_rate": (d.get("passingDowns") or {}).get("rate"),
            "def_pass_downs_ppa": (d.get("passingDowns") or {}).get("ppa"),
            "def_pass_downs_success_rate": (d.get("passingDowns") or {}).get("successRate"),
            "def_pass_downs_explosiveness": (d.get("passingDowns") or {}).get("explosiveness"),
            "def_rushing_rate": (d.get("rushingPlays") or {}).get("rate"),
            "def_rushing_ppa": (d.get("rushingPlays") or {}).get("ppa"),
            "def_rushing_success_rate": (d.get("rushingPlays") or {}).get("successRate"),
            "def_rushing_explosiveness": (d.get("rushingPlays") or {}).get("explosiveness"),
            "def_passing_rate": (d.get("passingPlays") or {}).get("rate"),
            "def_passing_ppa": (d.get("passingPlays") or {}).get("ppa"),
            "def_passing_success_rate": (d.get("passingPlays") or {}).get("successRate"),
            "def_passing_explosiveness": (d.get("passingPlays") or {}).get("explosiveness"),
        })
        inserted += 1
    conn.commit()
    cur.close()
    conn.close()
    return inserted

if __name__ == "__main__":
    total = 0
    for season in SEASONS:
        print(f"Fetching advanced stats for {season}...")
        records = fetch_advanced_stats(season)
        print(f"  Retrieved {len(records)} teams.")
        n = insert_advanced_stats(records, season)
        total += n
        print(f"  Inserted/updated {n} rows.")
    print(f"\nDone. Total: {total} rows.")
