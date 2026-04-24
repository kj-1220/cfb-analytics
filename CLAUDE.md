# CFB Analytics Platform

## Project overview
AI-powered college football analytics and betting research platform.
Live target: Liberty vs Coastal Carolina, September 24, 2026.

## My setup
- Mac, Docker Desktop running Postgres 15 on port 5455
- Postgres password: postgres
- Connection string: host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres
- dbt project at ~/cfb-analytics/cfb_analytics (postgres adapter)
- GitHub repo: github.com/kj-1220/cfb-analytics
- API keys in ~/cfb-analytics/.env: CFBD_API_KEY, ODDS_API_KEY
- Never use nano or pico — always write files with cat >
- Never paste multi-line SQL into the psql prompt — always use psql -f

## Architecture (medallion)
- Bronze (raw schema) — complete, append-only, never alter
- Silver (stg + int schemas) — complete as of Day 3
- Gold (mart + semantic schemas) — upcoming Day 6
- Bayesian model (Python/PyMC) — hierarchical Poisson, 3 outputs
- RAG corpus (rag schema, pgvector, same Postgres instance)
- FastAPI + Claude tool use + React frontend

## Silver layer — complete as of Day 3
7 staging views in stg schema:
- stg_games, stg_teams, stg_venues, stg_sp_ratings
- stg_recruiting, stg_advanced_stats, stg_team_stats

1 intermediate table in int schema:
- int_team_season_features — 552 rows, one per FBS team per season 2022-2025

## Bayesian model design
One hierarchical Poisson model, three outputs derived from 10,000 Monte Carlo draws:
- Spread = home_score - away_score per draw, median + distribution
- Moneyline = P(home_score > away_score) across draws
- Over/Under = P(home_score + away_score > total) across draws

Three-level hierarchy: league → conference → team

## Day 4 goal
Feature engineering brainstorm and planning. No new dbt models today.
Two new silver models to be built on Day 5:
- int_game_environment (game-level: venue, elevation, travel, timezone)
- int_team_season_context (team-season-level: momentum, schedule, derived ratios)

## Feature families planned for Day 5
1. Venue and environment: venue_elevation_ft, away_elevation_delta_ft,
   away_elevation_ascent_ft (max of delta and 0), is_dome
2. Travel and logistics: away_travel_distance_mi (haversine),
   away_tz_delta_hrs (signed), is_neutral_site
3. Team momentum: last3_games_epa_avg, last3_games_win_pct,
   days_since_last_game
4. Schedule context: opp_sp_rating_at_game_time, season_week,
   is_conference_game
5. Derived ratios: scoring_efficiency_ratio, turnover_margin_per_game

## Key design decisions still open
- Haversine calculation: Postgres earth_distance extension vs Python seed
- Timezone lookup: dbt seed CSV vs SQL CASE statement by state
- Rolling window approach for momentum features (avoid data leakage)
- Opponent SP+ at game time vs end-of-season (data leakage risk)

## Day 5 build order
1. Run USGS elevation backfill script first — generates
   cfb_analytics/seeds/venue_elevations.csv
   Elevation coverage currently 38%, needs ~95% before building
2. Run dbt seed to load venue_elevations into the database
3. Build int_game_environment (game level)
4. Build int_game_team_features (game level — momentum, opp SP+)
5. Build int_team_season_context (season level — pace, ratios,
   game script aggregates)
6. Run dbt run --select int_game_environment
   int_game_team_features int_team_season_context
7. Run dbt test on all three new models
8. Day 6 first task: weather bronze table and ingestion script

## Open decisions for Day 6
- 2022 null opp_sp_rating_at_game_time: imputation strategy
  (league mean vs exclusion vs Bayesian missing data handling)
- Garbage time thresholds: confirm period 4 > 28 and
  period 3+ > 38 against actual game data before finalizing
- Opponent-adjusted pace: refinement after base model runs
- Injury proxy: requires passer column confirmation in raw.plays

## This is a production betting research tool, not a demo
