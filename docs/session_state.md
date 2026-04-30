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

## EDA Phase — Days 6–14
| Day | Notebook | Status | Decision Produced |
|---|---|---|---|
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | Game-level close-game EPA pair is joint model anchor; off YoY r=0.423, def YoY r=0.393 |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.761; recruiting supporting but conference-specific — see findings |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed; ICC 0.07–0.09; team spread justifies team level |
| 11 | eda_06_environmental_features.ipynb | ✅ complete | No environmental feature warrants inclusion as model adjuster — see findings and exceptions |
| 12 | eda_07_momentum_rolling_features.ipynb | ❌ not built | Whether rolling features add signal beyond season averages |
| 13 | eda_08_game_script_close_games.ipynb | ❌ not built | Whether game script belongs in model and in what role |
| 14 | eda_09_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |

## What The Next Session Must Do
**May 1 — Transfer portal ingestion first, then Day 12**

### Portal ingestion (before any notebook work):
- CFBD API key resets May 1 (1,000 call free tier limit)
- Base URL: apinext.collegefootballdata.com (v2 API only — v1 is dead)
- Pull transfer portal data for seasons 2022, 2023, 2024, 2025 (~4 API calls)
- Fields needed: season, fromTeam, toTeam, rating, stars, position, eligibility
- Build raw.transfer_portal table
- Build stg_transfer_portal staging view
- Aggregate to team-season level: sum of incoming ratings minus sum of outgoing ratings = portal_net_rating
- Add portal_net_rating column to int_team_season_features
- Re-run EDA 4 (Day 9) with portal data added — evaluate whether portal net rating adds signal beyond HS recruiting, especially in Big 12 where recruiting alone collapsed

### Then build Day 12:
`notebooks/eda/eda_07_momentum_rolling_features.ipynb`

Questions to answer:
1. Do last3_off_epa_avg and last3_win_pct predict next-game outcomes better than season-level averages?
2. How much do rolling features diverge from season averages mid-season? When do they converge?
3. Is there a measurable bye week effect in days_since_last_game?
4. How should Week 1 and Week 2 nulls be handled?

Decision: whether rolling features add signal beyond season averages and how to handle early-season nulls.

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
- ⚠️ Transfer portal ingestion needed May 1 — especially important for Big 12

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