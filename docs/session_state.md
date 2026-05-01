cat > ~/cfb-analytics/docs/session_state.md << 'EOF'
# CFB Analytics — Session State

## Last Updated
2026-04-30

## Project Goal
Hierarchical Negative Binomial model predicting score distributions for FBS college football games.
Outputs: win probability, spread, moneyline, over/under via Monte Carlo simulation.
Goes live: September 24, 2026 — Liberty vs Coastal Carolina.

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team (confirmed Day 10)
- Likelihood: Negative Binomial (confirmed Day 6)
- Model form: points ~ NegBinom(mu, r), log(mu) = team_attack + opponent_defense + home_advantage + ...
- Dispersion parameter r ~ HalfNormal(), fit from data — should vary by conference given VMR range 5.2–8.1
- Priors seeded from: SP+ preseason rating, 3-year recruiting composite, transfer portal net, NIL proxy
- Conference-level pooling handles small sample size (12 games/team)
- Built in PyMC

## EDA Phase — Days 6–17
| Day | Notebook | Status | Decision Produced |
|---|---|---|---|
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | Game-level close-game EPA pair is joint model anchor; off YoY r=0.423, def YoY r=0.393 |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.761; recruiting supporting but conference-specific — see findings |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed; ICC 0.07–0.09; team spread justifies team level |
| 11 | eda_06_environmental_features.ipynb | ✅ complete | No environmental feature warrants inclusion as model adjuster — see findings and exceptions |
| 12 | eda_07_momentum_rolling_features.ipynb | ✅ complete | All rolling features redundant after opponent quality + SP+ controls; no bye week effect |
| 13 | Claude Code session | ❌ not started | Play-by-play schema exploration — style, tempo, positional, spatial, line play candidates |
| 14 | eda_08_style_tempo_delta.ipynb | ❌ not built | Style & tempo delta analysis — signal identification |
| 15 | eda_09_style_archetypes.ipynb | ❌ not built | Style archetype clustering + matchup interaction effects |
| 16 | eda_10_game_script.ipynb | ❌ not built | Game script & close game signals |
| 17 | eda_11_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |

## What The Next Session Must Do
**Day 13 — Claude Code schema exploration session (terminal, not a notebook)**

### Portal ingestion (still pending — do this first):
- CFBD API key resets May 1 (1,000 call free tier limit)
- Base URL: apinext.collegefootballdata.com (v2 API only — v1 is dead)
- Pull transfer portal data for seasons 2022, 2023, 2024, 2025 (~4 API calls)
- Fields needed: season, fromTeam, toTeam, rating, stars, position, eligibility
- Build raw.transfer_portal table
- Build stg_transfer_portal staging view
- Aggregate to team-season level: sum of incoming ratings minus sum of outgoing ratings = portal_net_rating
- Add portal_net_rating column to int_team_season_features
- Re-run EDA 4 (Day 9) with portal data added — evaluate whether portal net rating adds signal beyond HS recruiting, especially in Big 12 where recruiting alone collapsed

### Then Day 13 Claude Code exploration:
Goal: identify every available feature candidate for style, tempo, matchup, positional strength,
and spatial analysis. Output updates candidate_features.csv and produces notes that drive
Day 14 notebook design.

The exploration must answer:

**Play-by-play grain:**
- What play-by-play tables exist and at what grain (play, drive, game)?
- Are play direction and field zone captured (left/right edge, boundary/field, behind line, intermediate, deep)?
- Is individual player tagging available per play? What positions and coverage?
- What seasons and what % of games are covered?

**Style & tempo:**
- Plays per game, time of possession, tempo (pace relative to play clock)
- Rush rate, pass rate — overall and by down/distance
- Explosive play rate by run vs pass (20+ yard threshold)
- Success rate overall and by down, distance, field zone
- Average depth of target, air yards

**Line play:**
- Stuff rate (run stopped at or behind line of scrimmage)
- Line yards, opportunity rate
- Sack rate, pressure rate, time to throw
- Run block win rate, pass block win rate if available
- Are these pre-computed or derived from play-by-play?

**Spatial & field position:**
- Can explosiveness and success rate be computed by field zone?
- Is play direction tagged (left, middle, right)?
- Can boundary vs field side tendencies be identified?
- Hash position if available

**Positional strength proxies:**
- Recruiting composites by position group (QB, OL, DL, DB, WR, RB) — available or aggregate only?
- Any PFF-style grades in CFBD or adjacent tables?
- Havoc rates by position group — already have def_havoc_* columns, check granularity
- opp_sp_rating_at_game_time exists in int_game_team_features — investigate what it contains

**Matchup construction:**
- Confirm opponent column exists at play level for matchup delta construction
- Identify which features can be computed as team A strength vs team B weakness deltas
- Examples: strong edge rusher vs weak right tackle, deep coverage vs explosive pass attack

### Definition of done for Day 13:
- All candidate style/tempo/spatial/positional features listed with source table,
  grain, derivation path if needed, and keep=True/False recommendation
- candidate_features.csv updated with new candidates
- Explicit flag on whether PFF data would fill a meaningful gap after seeing what CFBD provides
- Day 14 notebook design unblocked — no open data availability questions remaining

## Data Fixes Applied
**Fix 1 — Conference assignment by season (not static snapshot)**
- int_team_season_features now derives conference from stg_games by season
- Commit: "fix: derive conference from game records by season, not static team snapshot"

**Fix 2 — FCS team filter**
- 18 FCS transition team-seasons removed via FBS conference allowlist
- Row count: 552 → 534
- Commit: "fix: filter FCS teams from int_team_season_features using FBS conference allowlist"

**Fix 3 — Venue elevation data**
- 161 FBS venues were missing elevation data including Wyoming (7,220 ft), Air Force (6,905 ft), Colorado (5,430 ft), Colorado State (5,003 ft), BYU (4,551 ft)
- away_home_elevation_ft was returning 0 for every team whose home venue was missing
- Fetched elevations for 159 venues via Open-Meteo API, appended to venue_elevations.csv seed
- Deduped seed file: 603 unique venues
- Commit: "fix: add missing venue elevations for 159 FBS venues via Open-Meteo API"

## Locked Decisions — Do Not Revisit
- Likelihood: Negative Binomial
- Elevation computation: earthdistance extension
- Timezone: COALESCE(IANA timezone, state CASE) hybrid
- Momentum grain: game level
- opp_sp_rating: prior year (season - 1) to prevent leakage
- field_position_margin: dropped
- havoc: always def_havoc_* columns, never off_havoc_*
- Weather dome override: temp=68, wind=0, precip=0 when is_dome=true
- D1 filter: FBS + FCS only via conference allowlist
- Notre Dame: Power Four — route by team name not conference label
- UConn: Group of Five — route by team name not conference label
- FCS-to-FBS transitions: excluded — filtered at dbt level
- recruiting_3yr_avg: high school recruiting only
- Conference assignment: historically accurate by season from game records
- Pac-12 in dataset: G5 for all seasons — teams in data are not the real Pac-12
- FBS Independents: not a pooling group
- No tiers within conferences: team-level parameters handle within-conference spread
- Three-level hierarchy: league → conference → team — confirmed Day 10
- No environmental feature as model adjuster — none cleared both thresholds
- is_dome: not a spread term (residual SD diff 0.69 pts); not an over/under term (OLS coef +0.87 pts after EPA)
- Weather features: redundant for both spread and over/under after EPA control
- away_travel_distance_mi: supporting-unstable only in max stress population; if included use tight prior near zero
- Notre Dame pools with ACC for environmental analysis
- UConn pools with American Athletic for environmental analysis
- No last3_* rolling features in model
- No bye week adjustment term in model
- Early-season null handling: Approach A — impute with season-to-date prior
- Style/tempo analysis: delta approach first, clustering second (Days 14–15)
- PFF enterprise API: evaluate after Day 13 exploration confirms what CFBD gap exists

## assign_tier Function — Canonical Version
```python
P4_CONFERENCES = {"ACC", "Big 12", "Big Ten", "SEC"}

def assign_tier(row):
    if row["team_name"] == "Notre Dame":
        return "P4"
    if row["team_name"] == "UConn":
        return "G5"
    if row["conference"] in P4_CONFERENCES:
        return "P4"
    return "G5"
```

## Key Findings From Completed Notebooks

### Day 6 — Scoring Distributions
- 2,835 FBS games, 2022–2025
- Every conference in every season is overdispersed — no exceptions, VMR 3.56–8.05
- Decision: Negative Binomial. r ~ HalfNormal(), should vary by conference.

### Day 7 — Feature Inventory
- 154 keep=True features
- close_game_def_epa_per_play and close_game_def_play_count now properly in candidate list

### Day 8 — EPA Deep Dive
- Game-level joint anchor pair: close_game_epa_per_play + close_game_def_epa_per_play, R²=0.772
- Season-level: off_epa_per_play R²=0.779
- YoY: off r=0.423, def r=0.393 — priors should be wider
- def_epa_per_play_allowed, last3_off_epa_avg, last3_def_epa_avg — all redundant

### Day 9 — SP+ & Recruiting
- SP+ partial r=0.399 after EPA, YoY r=0.761 — anchor candidate
- Recruiting overall R²=0.103 — supporting
- Recruiting G5 collapse: R²≈0.000
- Recruiting within P4 varies significantly by conference:
  - Big Ten: rec→win_pct R²=0.390, leading indicator R²=0.309 — strong signal
  - SEC: rec→win_pct R²=0.236 but rec→off_epa R²=0.048 — predicts wins not EPA
  - ACC: weak (R²<0.095)
  - Big 12: essentially zero (R²=0.004)
- Recruiting YoY stability: r=0.929–0.968 across all P4 conferences — very stable input
- ⚠️ Recruiting requires conference-specific treatment — cannot be a flat feature
- ⚠️ Transfer portal ingestion needed — especially important for Big 12

### Day 10 — Hierarchy Structure
- 534 team-seasons, 136 teams, 11 FBS conferences, 4 seasons
- Tier split: P4=246, G5=288 (Pac-12 correctly G5)
- ICC: scored=0.093, point_diff=0.088, off_epa=0.094, def_epa=0.070
- Within-conference team SD range: 8.743–13.772, mean=10.356
- Decision: THREE-LEVEL HIERARCHY CONFIRMED — league → conference → team

### Day 11 — Environmental Features
- Elevation: flat after EPA control even with correct data. No adjuster warranted.
- Travel: away_travel_distance_mi supporting-unstable in max stress population only (r=+0.102, YoY r=0.723). 2.4 pt raw disadvantage in max stress population.
- Timezone: tz_delta <= -2 hrs clears 0.10 but p not significant and n small.
- Weather (spread): all features < 0.03 partial r after EPA. Completely flat.
- Weather (over/under): all features < 0.03 partial r vs total scoring after EPA. Completely flat.
- Weather (individual scoring): temperature r=+0.037 (p=0.003), wind_chill r=+0.037 (p=0.004), heat_index r=+0.038 (p=0.003) — small but significant. Below 0.10 threshold.
- High wind asymmetry: home scoring -2.94 pts, away scoring -0.55 pts in high wind. Asymmetry 2.38 pts. Spread-relevant but not captured by point_differential partial r. Monitor with 2026 data.
- Dome: OLS coefficient +0.87 pts total scoring after EPA. Below 2-point threshold. Not a model term.
- Kickoff × timezone: n=22 early kickoffs — insufficient. Re-evaluate with 2026 data.

### Day 12 — Momentum & Rolling Features
- All five last3_* features redundant — partial r 0.02–0.08 after controlling for both teams' season-to-date EPA + prior-year SP+
- YoY r range 0.35–0.45 — below or near off_epa benchmark of 0.423
- Bye week effect: no signal — partial r=0.006, p=0.71 after quality controls
- Asymmetric opponent effect: +0.415 pts, p=0.710 — also no signal
- Null handling: Approach A — impute with season-to-date prior; residual SD +8.2% higher in early weeks, below 10% materiality threshold
- Imputation quality: corr=0.948 (offense), 0.932 (defense), MAE < 0.03 — high quality
- opp_sp_rating_at_game_time confirmed in int_game_team_features schema — not previously documented
- Data: 2023–2025 only (3 seasons) — 2022 dropped by prior-year SP+ join design, correct by methodology

## Candidate Features
- Authoritative list: artifacts/candidate_features.csv
- Total features: 154 keep=True

## Artifacts Written
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 154 features, keep=True only |
| artifacts/epa_feature_verdict.csv | ✅ valid | Day 8 output |
| artifacts/sp_recruiting_verdict.csv | ✅ valid | Day 9 output |
| artifacts/hierarchy_verdict.csv | ✅ valid | Day 10 output, post-fix numbers |
| artifacts/environment_verdict.csv | ✅ valid | Day 11 output, post elevation fix |
| artifacts/momentum_verdict.csv | ✅ valid | Day 12 output |

## YoY Benchmarks
- off_epa_per_play YoY r = 0.423
- def_epa_per_play YoY r = 0.393
- sp_rating YoY r = 0.761, 95% CI [0.718, 0.803]
- away_elevation_delta_ft YoY r = 0.863 — stable
- away_travel_distance_mi YoY r = 0.723 — unstable

## Known Schema Facts — Use Exactly
- point_differential does not exist — derive as points_scored - points_allowed
- Defensive EPA column is def_epa_per_play_allowed — not def_epa_per_play
- int_game_environment has home_team and away_team, not team_name — join on game_id only, then filter f.team_name IN (e.home_team, e.away_team)
- conference comes from int_team_season_context, joined on team_name and season
- All numeric columns from psycopg2 return as Decimal — cast entire numeric column list to float64 immediately
- Connection: host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres
- Boolean columns (is_dome, is_high_wind, is_precipitation) return as Python objects with None values — use .map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float) before partial_corr
- opp_sp_rating_at_game_time exists in int_game_team_features — not yet fully investigated

## Source Tables
- int.int_game_team_features — game-level team performance
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context including conference
- int.int_team_season_features — season-level team features, 534 rows, FBS only

## Connection Pattern (psycopg2 only)
```python
conn = psycopg2.connect(
    host='127.0.0.1', port=5455, dbname='postgres',
    user='postgres', password='postgres'
)
cur = conn.cursor()
cur.execute("SELECT ...")
rows = cur.fetchall()
cols = [d[0] for d in cur.description]
df = pd.DataFrame(rows, columns=cols)
df[numeric_cols] = df[numeric_cols].astype(float)
```

## Rules Every Session Must Follow
1. Read this file before touching anything else
2. Read artifacts/candidate_features.csv — only keep=True columns are authorized
3. Run schema introspection query before writing any SQL — never guess column names
4. Write complete cells only — never partial fixes or incremental edits
5. Use existing helpers — never redefine logic that already exists in the notebook
6. Cast all Decimal columns to float64 immediately after loading
7. Cast boolean columns using .map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)
8. Do not rewrite verified cells
9. Do not close the DB connection until the notebook is complete
10. If a required column is not in the schema output, stop and say so
11. Use the canonical assign_tier function — do not modify it

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the EDA table
3. Add any new locked decisions
4. Add key findings
5. Update what the next session must do
6. Commit: git add docs/session_state.md && git commit -m "docs: update session state after Day X" && git push
EOF