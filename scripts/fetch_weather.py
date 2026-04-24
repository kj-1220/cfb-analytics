import requests
import psycopg2
import time
import pytz
from datetime import datetime

DB = dict(host="127.0.0.1", port=5455, dbname="postgres",
          user="postgres", password="postgres")

def to_local(start_date_str, venue_tz):
    try:
        utc_dt = datetime.fromisoformat(start_date_str.replace('Z', '+00:00'))
        tz = pytz.timezone(venue_tz)
        return utc_dt.astimezone(tz)
    except Exception:
        return None

def fetch_weather(lat, lon, date_str, hour):
    try:
        resp = requests.get(
            "https://archive-api.open-meteo.com/v1/archive",
            params={
                "latitude":           lat,
                "longitude":          lon,
                "start_date":         date_str,
                "end_date":           date_str,
                "hourly":             "temperature_2m,wind_speed_10m,wind_gusts_10m,precipitation,relative_humidity_2m,weather_code",
                "wind_speed_unit":    "mph",
                "temperature_unit":   "fahrenheit",
                "precipitation_unit": "inch",
                "timezone":           "auto"
            },
            timeout=15
        )
        resp.raise_for_status()
        h = resp.json()["hourly"]
        return {
            "temperature_f":    h["temperature_2m"][hour],
            "wind_speed_mph":   h["wind_speed_10m"][hour],
            "wind_gusts_mph":   h["wind_gusts_10m"][hour],
            "precipitation_in": h["precipitation"][hour],
            "humidity_pct":     h["relative_humidity_2m"][hour],
            "weather_code":     h["weather_code"][hour],
        }
    except Exception as e:
        print(f"  Weather fetch failed: {e}")
        return None

def main():
    conn = psycopg2.connect(**DB)
    cur = conn.cursor()

    cur.execute("""
        SELECT
            g.game_id,
            g.start_date,
            v.venue_id,
            v.latitude,
            v.longitude,
            COALESCE(v.timezone, CASE v.state
                WHEN 'AL' THEN 'America/Chicago'
                WHEN 'AK' THEN 'America/Anchorage'
                WHEN 'AZ' THEN 'America/Phoenix'
                WHEN 'AR' THEN 'America/Chicago'
                WHEN 'CA' THEN 'America/Los_Angeles'
                WHEN 'CO' THEN 'America/Denver'
                WHEN 'CT' THEN 'America/New_York'
                WHEN 'DE' THEN 'America/New_York'
                WHEN 'FL' THEN 'America/New_York'
                WHEN 'GA' THEN 'America/New_York'
                WHEN 'HI' THEN 'Pacific/Honolulu'
                WHEN 'ID' THEN 'America/Boise'
                WHEN 'IL' THEN 'America/Chicago'
                WHEN 'IN' THEN 'America/Indiana/Indianapolis'
                WHEN 'IA' THEN 'America/Chicago'
                WHEN 'KS' THEN 'America/Chicago'
                WHEN 'KY' THEN 'America/New_York'
                WHEN 'LA' THEN 'America/Chicago'
                WHEN 'ME' THEN 'America/New_York'
                WHEN 'MD' THEN 'America/New_York'
                WHEN 'MA' THEN 'America/New_York'
                WHEN 'MI' THEN 'America/Detroit'
                WHEN 'MN' THEN 'America/Chicago'
                WHEN 'MS' THEN 'America/Chicago'
                WHEN 'MO' THEN 'America/Chicago'
                WHEN 'MT' THEN 'America/Denver'
                WHEN 'NE' THEN 'America/Chicago'
                WHEN 'NV' THEN 'America/Los_Angeles'
                WHEN 'NH' THEN 'America/New_York'
                WHEN 'NJ' THEN 'America/New_York'
                WHEN 'NM' THEN 'America/Denver'
                WHEN 'NY' THEN 'America/New_York'
                WHEN 'NC' THEN 'America/New_York'
                WHEN 'ND' THEN 'America/Chicago'
                WHEN 'OH' THEN 'America/New_York'
                WHEN 'OK' THEN 'America/Chicago'
                WHEN 'OR' THEN 'America/Los_Angeles'
                WHEN 'PA' THEN 'America/New_York'
                WHEN 'RI' THEN 'America/New_York'
                WHEN 'SC' THEN 'America/New_York'
                WHEN 'SD' THEN 'America/Chicago'
                WHEN 'TN' THEN 'America/Chicago'
                WHEN 'TX' THEN 'America/Chicago'
                WHEN 'UT' THEN 'America/Denver'
                WHEN 'VT' THEN 'America/New_York'
                WHEN 'VA' THEN 'America/New_York'
                WHEN 'WA' THEN 'America/Los_Angeles'
                WHEN 'WV' THEN 'America/New_York'
                WHEN 'WI' THEN 'America/Chicago'
                WHEN 'WY' THEN 'America/Denver'
                ELSE 'America/Chicago'
            END) AS venue_tz
        FROM stg.stg_games g
        JOIN stg.stg_venues v ON v.venue_id = g.venue_id
        WHERE g.season_type = 'regular'
          AND g.home_conference IS NOT NULL
          AND g.away_conference IS NOT NULL
          AND v.latitude IS NOT NULL
          AND g.game_id NOT IN (SELECT game_id FROM raw.game_weather)
        ORDER BY g.start_date
    """)

    games = cur.fetchall()
    total = len(games)
    print(f"Fetching weather for {total} games...")

    fetched = 0
    skipped = 0

    for i, (game_id, start_date, venue_id, lat, lon, venue_tz) in enumerate(games):
        local_dt = to_local(start_date, venue_tz)
        if local_dt is None:
            print(f"  [{i+1}/{total}] game_id={game_id} — skipping, bad timestamp")
            skipped += 1
            continue

        kickoff_hour = local_dt.hour
        date_str = local_dt.strftime("%Y-%m-%d")

        weather = fetch_weather(lat, lon, date_str, kickoff_hour)
        if weather is None:
            skipped += 1
            continue

        cur.execute("""
            INSERT INTO raw.game_weather
                (game_id, venue_id, game_date, kickoff_hour,
                 temperature_f, wind_speed_mph, wind_gusts_mph,
                 precipitation_in, humidity_pct, weather_code)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (game_id) DO NOTHING
        """, (
            game_id, venue_id, date_str, kickoff_hour,
            weather["temperature_f"], weather["wind_speed_mph"],
            weather["wind_gusts_mph"], weather["precipitation_in"],
            weather["humidity_pct"], weather["weather_code"]
        ))
        conn.commit()
        fetched += 1

        if (i + 1) % 100 == 0:
            print(f"  [{i+1}/{total}] fetched={fetched} skipped={skipped}")

        time.sleep(0.1)

    print(f"\nDone. fetched={fetched} skipped={skipped} total={total}")
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
