cat > ~/cfb-analytics/docs/session_state.md << 'EOF'
# CFB Analytics — Session State

## Last Updated
2026-05-01

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

## EDA Phase — Days 6–19
| Day | Notebook | Status | Decision Produced |
|---|---|---|---|
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | Game-level close-game EPA pair is joint model anchor; off YoY r=0.423, def YoY r=0.393 |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.761; recruiting supporting but conference-specific — see findings |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed; ICC 0.07–0.09; team spread justifies team level |
| 11 | eda_06_environmental_features.ipynb | ✅ complete | No environmental adjusters for spread; temperature/wind chill small signal on individual scoring rate — see findings |
| 12 | eda_07_momentum_rolling_features.ipynb | ✅ complete | All rolling features redundant after opponent quality + SP+ controls; no bye week effect |
| 13 | eda_08_elo_excitement.ipynb | ❌ not built | SP+/ELO divergence signal; excitement index as game profile feature |
| 14 | Claude Code session | ❌ not started | Play-by-play schema exploration — style, tempo, positional, spatial, line play candidates |
| 15 | eda_09_style_tempo_delta.ipynb | ❌ not built | Style & tempo delta analysis — signal identification |
| 16 | eda_10_style_archetypes.ipynb | ❌ not built | Style archetype clustering + matchup interaction effects |
| 17 | eda_11_game_script.ipynb | ❌ not built | Game script & close game signals |
| 18 | eda_12_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |
| 19 | eda_13_eda_finalization.ipynb | ❌ not built | Consolidate all verdict CSVs into master_verdict.csv; produce final_features.csv; resolve all ambiguities; write prior specification draft |

## Model Build Phase — Days 20–33
| Day | Notebook | Goal |
|---|---|---|
| 20 | model_01_prior_specification.ipynb | Translate every EDA finding into a written prior distribution. Every parameter needs a prior before any code is written. Traceable to master_verdict.csv. |
| 21 | model_02_architecture.ipynb | Write hierarchical Negative Binomial model structure in PyMC. No fitting yet. Three levels: league → conference → team. Document every design decision and the EDA finding that motivated it. |
| 22 | model_03_first_fit.ipynb | Fit on 2022–2024 training data. Do not touch 2025 holdout. Record fit time, divergences, initial parameter estimates. |
| 23 | model_04_prior_predictive_checks.ipynb | Sample before seeing data. Does it produce plausible CFB scores? Fix priors if it generates 0-point or 150-point games. |
| 24 | model_05_posterior_checks.ipynb | R-hat < 1.01, trace plots, energy plots, effective sample size. Confirm convergence. Investigate divergences. |
| 25 | model_06_holdout_evaluation.ipynb | First look at 2025 holdout. Overall Brier score, calibration curve. Baseline before subgroup breakouts. |
| 26 | model_07_evaluation_by_conference_tier.ipynb | Brier score and calibration by P4, G5, Independents. Model must perform credibly across all tiers. |
| 27 | model_08_evaluation_by_game_type.ipynb | Rivalry games, cross-tier matchups, neutral site games. Quantify how model handles upsets. |
| 28 | model_09_evaluation_season_progression.ipynb | Does calibration improve as season progresses? Week 1 is prior-driven. Week 8 has rolling data. Quantify improvement. |
| 29 | model_10_home_away_spread_accuracy.ipynb | Home field advantage calibration. Spread accuracy by expected margin. |
| 30 | model_11_year_over_year_stability.ipynb | Do 2023 model ratings predict 2024 performance? Tests whether team quality estimates are predictive not just descriptive. |
| 31 | model_12_refinement.ipynb | Adjust based on evaluation findings. May require revisiting priors, hierarchy, or dropping features. Likely a two-session day. |
| 32 | model_13_stress_testing.ipynb | Edge cases: extreme weather, maximum travel, large timezone deltas, teams with very few data points. Find where model breaks. |
| 33 | model_14_signoff.ipynb | Work through evaluation checklist from Day 18. Document every modeling decision, EDA finding that motivated it, and known limitations. Model not signed off until every checklist item addressed. |

Gold layer begins Day 34.

## What The Next Session Must Build
`notebooks/eda/eda_08_elo_excitement.ipynb` — Day 13

Questions to answer:
1. Does SP+/ELO divergence predict next-season outcomes beyond SP+ alone? Compute divergence as normalized ELO minus SP+ implied rating. Evaluate partial r after controlling for SP+. YoY stability of divergence score.
2. Does team-season excitement index profile add signal beyond existing game script features? Aggregate to team-season level: avg_excitement_index, pct_games_high_excitement (>= 6.0). Partial r after controlling for EPA pair. Compare to pct_games_competitive which is already in candidate list.
3. Do divergence and excitement index interact — do high-divergence teams also have distinctive excitement index profiles?

Decision this day produces: whether ELO divergence and excitement index belong in the model as prior adjusters, and in what form.

Key methodology notes:
- ELO is only populated for FBS vs FBS games — filter accordingly
- Excitement index is 41% coverage overall but higher within FBS games — check coverage before analysis
- SP+/ELO divergence requires normalizing both to same scale before computing difference — do this in the notebook, not in dbt
- Divergence is a team-season level feature — aggregate game-level ELO to season level first
- Do not add divergence to dbt until it proves to be a valid feature

## Day 14 — Claude Code Schema Exploration (after Day 13)
Goal: identify every available feature candidate for style, tempo, matchup, positional strength,
and spatial analysis. Output updates candidate_features.csv and produces notes that drive
Day 15 notebook design.

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

### Definition of done for Day 14:
- All candidate style/tempo/spatial/positional features listed with source table,
  grain, derivation path if needed, and keep=True/False recommendation
- candidate_features.csv updated with new candidates
- Explicit flag on whether PFF data would fill a meaningful gap after seeing what CFBD provides
- Day 15 notebook design unblocked — no open data availability questions remaining

## Portal and NIL Status
- Transfer portal CFBD v2 endpoint path unknown — v1 is dead, correct v2 path not found
- Portal ingestion deprioritized — revisit only if model performance is poor during evaluation
- NIL data requires On3 scrape — not built, deprioritized for same reason
- ELO partially substitutes for these signals — captures effect of roster changes on actual performance

## Data Added This Session (2026-05-01)
**ELO and excitement index ingested from CFBD API:**
- Added to raw.games: home_pregame_elo, away_pregame_elo, home_postgame_elo, away_postgame_elo, excitement_index
- Added to stg_games: all five columns
- Added to int_game_team_features: pregame_elo, opponent_pregame_elo, postgame_elo, excitement_index
- ELO flipped correctly to team perspective (home team gets home_pregame_elo, away team gets away_pregame_elo)
- Coverage: pregame_elo 6,478/29,472 rows (100% within FBS conferences), excitement_index 12,066/29,472 rows
- ELO/SP+ correlation: r=0.8625 — meaningful overlap but 26% divergence worth exploring
- Commit: "feat: add pregame_elo, postgame_elo, opponent_pregame_elo, excitement_index to int_game_team_features"

## Data Fixes Applied (prior sessions)
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
- No environmental feature as model adjuster for spread — none cleared both thresholds
- is_dome: not a spread term (residual SD diff 0.69 pts); not an over/under term (OLS coef +0.87 pts after EPA)
- Weather features (spread): redundant after EPA control — partial r < 0.03 for all features
- Weather features (over/under): redundant after EPA control — partial r < 0.03 vs total scoring
- Weather features (individual scoring rate): temperature r=+0.037, wind_chill r=+0.037, heat_index r=+0.038 — small but statistically significant; evaluate at model build whether to include as weak scoring rate adjusters
- High wind asymmetry: home scoring -2.94 pts vs away -0.55 pts — spread-relevant but insufficient sample; monitor with 2026 data
- away_travel_distance_mi: supporting-unstable only in max stress population; if included use tight prior near zero
- Notre Dame pools with ACC for environmental analysis
- UConn pools with American Athletic for environmental analysis
- No last3_* rolling features in model
- No bye week adjustment term in model
- Early-season null handling: Approach A — impute with season-to-date prior
- Style/tempo analysis: delta approach first, clustering second (Days 15–16)
- PFF enterprise API: evaluate after Day 14 exploration confirms what CFBD gap exists
- SP+/ELO divergence: compute in notebook first, add to dbt only if proven valid feature
- Portal and NIL: deprioritized — revisit only if model underperforms in evaluation
- def_epa_per_play_allowed (game-level, int_game_team_features): redundant at game level — r=0.971 with close-game anchor pair, signal concentrated in blowouts. Do NOT use as model feature.
- def_epa_per_play (season-level, int_team_season_features): ANCHOR FEATURE — used as prior seed alongside off_epa_per_play. Keep=True. Never dropped.

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
- Season-level anchors (prior seeds): off_epa_per_play R²=0.779, def_epa_per_play (season-level) YoY r=0.393
- YoY: off r=0.423, def r=0.393 — priors should be wider
- def_epa_per_play_allowed (GAME-LEVEL): redundant — r=0.971 with close-game anchor pair, signal concentrated in blowouts. This is the game-level column. Do not use as model feature.
- def_epa_per_play (SEASON-LEVEL): anchor feature for prior seed. Keep=True. Never dropped.
- last3_off_epa_avg, last3_def_epa_avg — redundant

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
- Weather vs point_differential (spread): all features partial r < 0.03. Redundant for spread.
- Weather vs total_points (over/under): all features partial r < 0.03. Redundant for over/under.
- Weather vs individual points_scored (scoring rate): temperature r=+0.037 (p=0.003), wind_chill r=+0.037 (p=0.004), heat_index r=+0.038 (p=0.003) — small but statistically significant. Below 0.10 threshold but real. Evaluate at model build whether to include as weak scoring rate adjusters in log(mu).
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
- opp_sp_rating_at_game_time confirmed in int_game_team_features schema
- Data: 2023–2025 only (3 seasons) — 2022 dropped by prior-year SP+ join design, correct by methodology

## Candidate Features
- Authoritative list: artifacts/candidate_features.csv
- Total features: 154 keep=True
- pregame_elo, opponent_pregame_elo, postgame_elo, excitement_index now in int_game_team_features but NOT yet in candidate_features.csv — add after Day 13 evaluation if proven valid

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
- Defensive EPA columns — two distinct columns, do not confuse:
  - def_epa_per_play_allowed in int_game_team_features — GAME-LEVEL, redundant, do not use as model feature
  - def_epa_per_play in int_team_season_features — SEASON-LEVEL, anchor feature, prior seed
- int_game_environment has home_team and away_team, not team_name — join on game_id only, then filter f.team_name IN (e.home_team, e.away_team)
- conference comes from int_team_season_context, joined on team_name and season
- All numeric columns from psycopg2 return as Decimal — cast entire numeric column list to float64 immediately
- Connection: host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres
- Boolean columns (is_dome, is_high_wind, is_precipitation) return as Python objects with None values — use .map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float) before partial_corr
- opp_sp_rating_at_game_time exists in int_game_team_features — not yet fully investigated
- pregame_elo, opponent_pregame_elo, postgame_elo, excitement_index now exist in int_game_team_features

## Source Tables
- int.int_game_team_features — game-level team performance including pregame_elo, excitement_index
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