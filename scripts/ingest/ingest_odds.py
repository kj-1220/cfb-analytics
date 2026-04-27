import requests
import psycopg2
import os
import json
from dotenv import load_dotenv

load_dotenv()

ODDS_API_KEY = os.getenv("ODDS_API_KEY")
DB_CONN = "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres"

# The sport key for college football on The Odds API
SPORT_KEY = "americanfootball_ncaaf"

# The markets we want: h2h = moneyline, spreads = point spread, totals = over/under
MARKETS = "h2h,spreads,totals"

# Bookmakers to capture — these are the most liquid for NCAAF
BOOKMAKERS = "draftkings,fanduel,bovada,betmgm,caesars"

def fetch_odds():
    """
    Fetches upcoming + in-progress games with lines.
    The free tier returns current/upcoming games only.
    For historical odds (past seasons), you need a paid plan.
    This script captures what's available now and upserts on conflict.
    """
    url = f"https://api.the-odds-api.com/v4/sports/{SPORT_KEY}/odds"
    params = {
        "apiKey":     ODDS_API_KEY,
        "regions":    "us",
        "markets":    MARKETS,
        "bookmakers": BOOKMAKERS,
        "oddsFormat": "american",
    }
    response = requests.get(url, params=params)
    
    # The Odds API returns quota usage in response headers — log it
    remaining = response.headers.get("x-requests-remaining", "unknown")
    used      = response.headers.get("x-requests-used", "unknown")
    print(f"  API quota — used: {used}, remaining: {remaining}")
    
    response.raise_for_status()
    return response.json()

def parse_and_insert(games):
    conn = psycopg2.connect(DB_CONN)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO raw.odds (
            game_id, sport_key, commence_time,
            home_team, away_team,
            bookmaker,
            h2h_home, h2h_away,
            spread_home_point, spread_home_price,
            spread_away_point, spread_away_price,
            total_point, total_over_price, total_under_price,
            raw_payload
        ) VALUES (
            %(game_id)s, %(sport_key)s, %(commence_time)s,
            %(home_team)s, %(away_team)s,
            %(bookmaker)s,
            %(h2h_home)s, %(h2h_away)s,
            %(spread_home_point)s, %(spread_home_price)s,
            %(spread_away_point)s, %(spread_away_price)s,
            %(total_point)s, %(total_over_price)s, %(total_under_price)s,
            %(raw_payload)s
        )
        ON CONFLICT (game_id, bookmaker) DO UPDATE SET
            h2h_home         = EXCLUDED.h2h_home,
            h2h_away         = EXCLUDED.h2h_away,
            spread_home_point  = EXCLUDED.spread_home_point,
            spread_home_price  = EXCLUDED.spread_home_price,
            spread_away_point  = EXCLUDED.spread_away_point,
            spread_away_price  = EXCLUDED.spread_away_price,
            total_point        = EXCLUDED.total_point,
            total_over_price   = EXCLUDED.total_over_price,
            total_under_price  = EXCLUDED.total_under_price,
            raw_payload        = EXCLUDED.raw_payload,
            _ingested_at       = NOW();
    """

    inserted = 0
    for game in games:
        game_id      = game.get("id")
        sport_key    = game.get("sport_key")
        commence     = game.get("commence_time")
        home_team    = game.get("home_team")
        away_team    = game.get("away_team")
        bookmakers   = game.get("bookmakers", [])

        for bm in bookmakers:
            bm_key   = bm.get("key")
            markets  = {m["key"]: m for m in bm.get("markets", [])}

            # --- moneyline ---
            h2h = markets.get("h2h", {})
            h2h_prices = {o["name"]: o["price"] for o in h2h.get("outcomes", [])}
            h2h_home = h2h_prices.get(home_team)
            h2h_away = h2h_prices.get(away_team)

            # --- spread ---
            spreads = markets.get("spreads", {})
            spread_map = {o["name"]: o for o in spreads.get("outcomes", [])}
            sh = spread_map.get(home_team, {})
            sa = spread_map.get(away_team, {})

            # --- totals ---
            totals = markets.get("totals", {})
            total_map = {o["name"]: o for o in totals.get("outcomes", [])}
            ov = total_map.get("Over",  {})
            un = total_map.get("Under", {})

            cur.execute(insert_sql, {
                "game_id":          game_id,
                "sport_key":        sport_key,
                "commence_time":    commence,
                "home_team":        home_team,
                "away_team":        away_team,
                "bookmaker":        bm_key,
                "h2h_home":         h2h_home,
                "h2h_away":         h2h_away,
                "spread_home_point":  sh.get("point"),
                "spread_home_price":  sh.get("price"),
                "spread_away_point":  sa.get("point"),
                "spread_away_price":  sa.get("price"),
                "total_point":        ov.get("point"),
                "total_over_price":   ov.get("price"),
                "total_under_price":  un.get("price"),
                "raw_payload":        json.dumps(bm),
            })
            inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    return inserted

if __name__ == "__main__":
    if not ODDS_API_KEY:
        print("ERROR: ODDS_API_KEY not found in .env file.")
        print("Add this line to ~/cfb-analytics/.env:")
        print("  ODDS_API_KEY=your_key_here")
        exit(1)

    print(f"Fetching odds for {SPORT_KEY}...")
    games = fetch_odds()
    print(f"Retrieved {len(games)} games with odds.")

    if len(games) == 0:
        print("No games returned. This is normal in the off-season.")
        print("The table exists and the script is working — lines will populate when the season starts.")
    else:
        n = parse_and_insert(games)
        print(f"Inserted/updated {n} bookmaker rows across {len(games)} games.")

    print("Done.")
