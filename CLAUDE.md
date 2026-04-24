# CFB Analytics Platform

## Project overview
AI-powered college football analytics and betting research platform.
Live target: Liberty vs Coastal Carolina, September 24, 2026.
This is a production betting research tool, not a demo.

## My setup
- Mac, Docker Desktop running Postgres 15 on port 5455
- Postgres password: postgres
- Connection string: host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres
- dbt project at ~/cfb-analytics/cfb_analytics (postgres adapter)
- GitHub repo: github.com/kj-1220/cfb-analytics
- API keys in ~/cfb-analytics/.env: CFBD_API_KEY, ODDS_API_KEY
- Never use nano or pico — always write files with cat >
- Never paste multi-line SQL into the psql prompt — always use psql -f

## Each morning
Open Docker Desktop, wait for whale icon to stop, run docker start cfb-pg if container stopped.

## Architecture (medallion)
- Bronze (raw schema) — append-only, never alter
- Silver (stg + int schemas) — in progress
- Gold (mart schema) — upcoming
- Bayesian model (Python/PyMC) — hierarchical Poisson, 3 outputs
- RAG corpus (rag schema, pgvector, same Postgres instance)
- FastAPI + Claude tool use + React frontend

## Bayesian model design
One hierarchical Poisson model, three outputs derived from 10,000 Monte Carlo draws:
- Spread = home_score - away_score per draw, median + distribution
- Moneyline = P(home_score > away_score) across draws
- Over/Under = P(home_score + away_score > total) across draws
Three-level hierarchy: league → conference → team

## Silver layer — complete as of Day 4

### Staging views (stg schema) — 8 views
- stg_games, stg_teams, stg_venues, stg_sp_ratings
- stg_recruiting, stg_advanced_stats, stg_team_stats
- stg_game_weather (Day 4 — weather bronze ingesting)

### stg_advanced_stats — expanded Day 4
Added columns previously missing from staging:
- Field position: off/def_field_position_avg_start, off/def_field_position_predicted_pts
- Second level yards: off/def_second_level_yards
- Total EPA: off/def_epa_total
- Situational EPA: off/def_std_downs_epa, off/def_pass_downs_epa
- Volume: off/def_plays, off/def_drives
- Bug fixed: havoc columns were reading off_havoc_* (offensive), now correctly
  read def_havoc_* (defensive)

### Intermediate tables (int schema) — 3 tables
- int_team_season_features — 552 rows, one per FBS team per season 2022-2025
  Full team profile: game results, SP+, advanced stats (off+def), team stats,
  field position, havoc, recruiting. Foundation for all season-level models.

- int_team_season_context — 552 rows, one per FBS team per season 2022-2025
  Derived ratios and rates built from int_team_season_features:
  Offense: plays_per_game, off_epa_total_per_game, scoring_efficiency_ratio,
           rush_rate, all success rates, explosiveness, situational EPA
  Defense: def_epa_per_play, def_success_rate, havoc splits, rushing efficiency,
           sacks_per_game, tfl_per_game, def_pts_per_opp
  Field position: off/def_field_position_avg_start and predicted_pts (raw only —
                  field_position_margin dropped, correlates with game script not quality)
  Turnovers: turnovers_forced_per_game, turnovers_lost_per_game, turnover_margin_per_game
  Penalties: penalties_per_game, penalty_yards_per_game
  Also includes: SP+ ratings, recruiting_3yr_avg

- int_game_team_features — 29,472 rows, one per team per game 2022-2025
  Rolling window features (ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING):
  Offense: last3_off_epa_avg, last3_win_pct, last3_points_scored_avg
  Defense: last3_def_epa_avg, last3_points_allowed_avg
  Rest: days_since_last_game
  Opponent: opp_sp_rating_at_game_time (prior year SP+, leakage-free)
  Week 1 NULLs expected and correct. 2022 opp_sp NULL expected (no 2021 data).

## Bronze layer — raw schema
- raw.games, raw.teams, raw.venues, raw.sp_ratings, raw.recruiting
- raw.team_stats, raw.advanced_stats, raw.plays (1,039,296 rows)
- raw.game_weather — ingesting Day 4 (~14,282 games, Open-Meteo historical API)

## Key design decisions — locked, do not revisit
- Elevation: earthdistance extension (not Python seed)
- Timezone: COALESCE(IANA timezone, state CASE) hybrid
- Momentum grain: game level (not season level)
- opp_sp_rating: prior year (season - 1) to avoid data leakage
- home_games_in_dome_pct: dropped, near-zero FBS variance
- close_game_count: both 3a (fast) and 3b (plays-based) versions planned
- field_position_margin: dropped — correlates with game script not team quality
- havoc: always use def_havoc_* columns, never off_havoc_*

## Data quality flags — known, do not investigate again
- 18 FCS team-seasons null on stats columns — benign
- 2022 null opp_sp_rating_at_game_time — expected, no prior year data
- W.C. Hawkins Stadium elevation failed — high school stadium, irrelevant
- Mountaineer Bowl 9,993 ft — Division II, irrelevant
- Mercer null opp_sp_rating — FCS opponent, expected
- ~45 games skipped in weather fetch (502 errors) — re-run script to backfill
- field_position values are 0-100 scale (not yard line) — 50 = midfield

## Day 5 goals
1. Re-run fetch_weather.py to backfill any 502-skipped games
2. Verify raw.game_weather row count (~14,282)
3. Build int_game_environment:
   - Elevation join from venue_elevations seed
   - Travel distance via earthdistance extension
   - Timezone delta via COALESCE(IANA, state CASE)
   - Weather columns + dome override logic
4. Special teams bronze ingestion (new CFBD endpoint)
5. EDA setup — begin exploratory analysis

## Ingestion scripts
- ~/cfb-analytics/scripts/fetch_weather.py
  Fetches Open-Meteo historical weather for all FBS regular season games.
  Safe to re-run — skips already-fetched game_ids via NOT IN filter.
  Run after any 502 errors to backfill missed games.

## Feature engineering plan
Full plan at ~/cfb-analytics/docs/feature_engineering_plan.md (711 lines)
Covers: game environment, game team features, team season context,
weather pipeline, game script, garbage time, pace-adjusted stats,
player continuity (Phase 2), roster turnover (Phase 2).
EOF