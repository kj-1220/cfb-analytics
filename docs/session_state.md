# CFB Analytics — Session State

## Last Updated
2026-05-04

---

## ⚠️ CRITICAL — How Notebooks Are Written In This Project
This rule overrides everything else. Read it before doing anything.

Notebooks are written cell by cell, directly in the conversation, as executable
Python code blocks.

- Each cell is written as a code block in the response
- The user copies it into Jupyter manually and runs it
- Output is verified before the next cell is written
- NEVER use nbformat, papermill, or any script to generate notebook files
- NEVER write a Python script that constructs a notebook object
- NEVER batch all cells into a single response — write one cell at a time
- If a cell produces an error, rewrite the ENTIRE cell — never patch inline
- Do not proceed to the next cell until the current one has been confirmed

---

## ⚠️ CRITICAL — What This Model Does
This model predicts spread, moneyline, and over/under for any FBS conference game.
It predicts each team's score distribution for a specific upcoming game. Spread,
moneyline, and over/under are derived from those two score distributions via Monte
Carlo simulation.

Goes live: September 24, 2026. This is a date marker only. The model predicts every
FBS conference game from that date forward. It is not built for any specific game or
matchup. It must predict any FBS conference game credibly.

Every feature must earn its place by improving prediction of a specific game outcome.
Season-level aggregations and YoY correlations are prior construction tools only.
The end goal is: given two specific teams playing a specific game, what is the
distribution of scores, and what does that imply for spread, moneyline, and over/under.

---

## ⚠️ CRITICAL — Correct EDA Methodology
Every feature must be evaluated against all three tests. All three together constitute
a complete verdict.

**Test 1 — Game-level prediction accuracy**
Does this feature improve prediction of:
- Point differential (spread and moneyline signal)
- Total points scored (over/under signal)
- Score distribution variance (moneyline signal specifically)
These are three separate tests. Report separately. Never collapse into one verdict.

**Test 2 — Within-season trajectory**
Does the predictive improvement hold across the conference season arc:
- Conference game 1: only the prior exists
- Conference games 2–4: posterior developing
- Conference games 5–8: posterior informed
- Conference games 9–12: fully informed
Rolling features are null at conf game 1 — trajectory starts at conf game 2.

**Test 3 — YoY stability**
Is the feature stable enough YoY to build a reliable prior from.
YoY stability is the GATING criterion for prior seed features only.
Game-level predictors (close-game EPA, ELO) are not gated by YoY stability.

**Conference stratification is mandatory for every test.**
Conference is the primary grouping structure. Every partial r table must include:
full population, P4, G5, and each individual conference. A feature that earns a
verdict in the SEC does not automatically earn it in the Big 12. Flat global analyses
are wrong and incomplete.

**Output separation requirement**
Every verdict must state separately:
- Spread signal: yes/no, partial r, threshold cleared, conferences where signal holds
- Over/under signal: yes/no, partial r, threshold cleared, conferences where signal holds
- Moneyline variance signal: yes/no, finding
- Within-season trajectory: holds / degrades / only works late season
- YoY stability: r value, stable/unstable verdict

---

## ⚠️ CRITICAL — Confirmation Gate
Rewritten each session to reflect what the next notebook must understand.

**Next notebook: Days 14–16 — Style, Tempo, and Game Script**

Answer these questions in your own words before writing any code:

1. Style and tempo features measure how a team plays — pass rate, pace, run/pass mix.
   Explain why these features need to be evaluated as matchup deltas rather than
   absolute team values, and what that means for how the partial r test should be
   constructed.

2. Game script features (game_script, game_script_avg_margin) are partially
   retrospective — they reflect how a game unfolded. Explain what the correct
   pre-game knowable version of game script is and how it should be constructed
   before any analysis.

3. The style/tempo analysis uses a delta approach first, clustering second. Explain
   what that means in terms of what gets tested in Day 15 versus Day 16, and why
   that sequencing matters.

---

## Project Goal
Hierarchical Negative Binomial model predicting score distributions for any FBS
conference game.
Outputs: spread, moneyline, over/under derived via Monte Carlo simulation.
Goes live: September 24, 2026. Date marker only.

---

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team (confirmed Day 10)
- Likelihood: Negative Binomial (confirmed Day 6)
- Model form: points ~ NegBinom(mu, r), log(mu) = team_attack + opponent_defense +
  home_advantage + environmental_adjusters + ...
- Dispersion parameter r ~ HalfNormal(), start with single parameter, add
  conference-specific r if posterior predictive checks show systematic miscalibration
- Priors seeded from: SP+ preseason rating, 3-year recruiting composite (conference-
  specific weight), pregame_elo (game-level, not prior seed)
- Conference-level pooling provides regularization (ICC marginal 0.02–0.05 but
  pooling still improves small-sample estimates)
- Built in PyMC

---

## EDA Phase — Days 6–19
| Day | Notebook | Status | Decision Produced |
|---|---|---|---|
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | close_game EPA pair = joint model anchor. off YoY r=0.423, def YoY r=0.393 |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.761. Recruiting conference-specific prior seed. |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed. Team ICC 0.13–0.17. Conference ICC marginal. |
| 11 | eda_06_environmental_features.ipynb | ✅ complete | See environmental findings below |
| 12 | eda_07_momentum_rolling_features.ipynb | ✅ complete | See momentum findings below |
| 13 | eda_08_elo_excitement.ipynb | ✅ complete | See ELO/excitement findings below |
| 14 | Claude Code session | ✅ complete | Play-by-play schema verified. 31 new candidates added. Field zone derivable via yards_to_goal. Spatial/directional features permanently closed. raw.odds confirmed as 2026 live validation target only — no historical closing lines. |
| 15 | eda_09_style_tempo_delta.ipynb | ❌ not built | Style & tempo delta analysis — signal identification |
| 16 | eda_10_style_archetypes.ipynb | ❌ not built | Style archetype clustering + matchup interaction effects |
| 17 | eda_11_game_script.ipynb | ❌ not built | Game script & close game signals |
| 18 | eda_12_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |
| 19 | eda_13_eda_finalization.ipynb | ❌ not built | Consolidate all verdict CSVs into master_verdict.csv; produce final_features.csv; resolve all ambiguities; write prior specification draft |

---

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
| 28 | model_09_evaluation_season_progression.ipynb | Does calibration improve as season progresses? Conf game 1 is prior-driven. Conf game 8 has rolling data. Quantify improvement. |
| 29 | model_10_home_away_spread_accuracy.ipynb | Home field advantage calibration. Spread accuracy by expected margin. |
| 30 | model_11_year_over_year_stability.ipynb | Do 2023 model ratings predict 2024 performance? |
| 31 | model_12_refinement.ipynb | Adjust based on evaluation findings. May require revisiting priors, hierarchy, or dropping features. |
| 32 | model_13_stress_testing.ipynb | Edge cases: extreme weather, maximum travel, large timezone deltas, teams with very few data points. |
| 33 | model_14_signoff.ipynb | Work through evaluation checklist from Day 18. Model not signed off until every checklist item addressed. |

Gold layer begins Day 34.

---

## What The Next Session Must Build
Days 15–17: Style, Tempo, Game Script analysis.

Day 14 schema exploration is complete. Day 15 builds eda_09_style_tempo_delta.ipynb.
All 31 Day 14 candidates are in candidate_features.csv with authoritative_table=raw.plays.
Every candidate must be computed per game from raw.plays and evaluated as a matchup delta
(team A offense vs. team B defense) using the standard three-test methodology.

---

## Key Findings By Day

### Day 8 — EPA Deep Dive
- close_game_epa_per_play: anchor candidate — spread r=0.584 at conf game 1, O/U r=0.434, holds across full trajectory, YoY r=0.423 (game-level predictor, not gated by YoY)
- close_game_def_epa_per_play: anchor candidate — spread r=-0.587 at conf game 1, O/U r=0.471, holds across full trajectory, YoY r=0.393
- def_epa_per_play_allowed: redundant — collinear with close_game_def_epa_per_play (r=0.9775)
- last3_off_epa_avg: conference-specific supporting — signal in ACC, Mid-American, SEC only; null at conf game 1
- last3_def_epa_avg: conference-specific supporting — signal in American Athletic, Big Ten, Conference USA, Mid-American, Pac-12, Sun Belt; null at conf game 1

### Day 9 — SP+ and Recruiting
- team_sp_rating: anchor candidate — spread partial r=0.1865 after EPA control, YoY r=0.7632, holds at conf game 1 (r=0.2107). O/U signal absent.
- opp_sp_rating_at_game_time: redundant as model feature — use as control variable only. EPA anchor pair already captures opponent quality from focal team perspective.
- recruiting_3yr_avg: conference-specific prior seed — YoY r=0.9746 (extremely stable). Game-level spread signal in American Athletic, Big Ten, Conference USA, Sun Belt. Redundant in ACC, Big 12, Mid-American, Mountain West, Pac-12, SEC. Must be modeled with conference-specific weight. Negative partial r after SP+ control in high-recruiting conferences — multicollinearity with SP+.

### Day 10 — Hierarchy Structure
- Three-level hierarchy confirmed: league → conference → team
- Team ICC: points_scored=0.1282, total_points=0.0644, point_differential=0.1725 — strong, justifies team level
- Conference ICC: points_scored=0.0207, total_points=0.0472, point_differential=0.0002 — marginal but pooling still provides regularization
- VMR range: 5.041–7.016 (ratio=1.392) — below 1.5 threshold. Start with single dispersion parameter. Add conference-specific r only if posterior predictive checks show systematic miscalibration.
- HFA: league-level +2.53 pts (p<0.001). Team HFA SD=4.27 pts — team-level deviations justified. Conference HFA range 2.91 pts — no conference-level HFA layer needed.
- Team scoring YoY r=0.34–0.40 (raw). Prior must be anchored by SP+ and EPA, not raw scoring history.

### Day 11 — Environmental Features
- away_elevation_delta_ft: anchor candidate — spread r=0.105 at delta>=2000ft, YoY r=0.827. Signal concentrates in Mountain West and Big 12. Full population r near zero — threshold-activated feature, not linear predictor.
- venue_elevation_ft: redundant — no threshold cleared. Use away_elevation_delta_ft.
- away_travel_distance_mi: supporting — spread r=0.153 at >=1500mi, YoY r=0.717 (below anchor threshold). Spread signal only. No O/U signal.
- away_tz_delta_hrs: supporting — spread r=-0.197 at abs>=2hr, strengthens at abs>=3hr (r=-0.258, n=71). YoY r=0.762. Spread signal only.
- kickoff_hour × away_tz_delta_hrs: insufficient sample (n=15) — do not model.
- wind_speed_mph, wind_gusts_mph, is_high_wind: redundant — no signal after EPA control at any threshold. Absorbed by EPA anchor pair.
- wind_chill: supporting — O/U signal only at <=40°F (r=0.101, n=397). Strengthens at <=25°F (r=0.235, n=99). No spread signal.
- temperature_f: supporting — O/U signal only at <=40°F (r=0.119, n=285). Largely absorbed by wind_chill composite.
- humidity_pct: supporting — O/U signal within HI triggered population. Prefer heat_index.
- heat_index: supporting — O/U signal in triggered pop (r=-0.121, n=300). Strengthens at >=90°F (r=-0.255, n=40). No spread signal.
- precipitation_inches, is_precipitation: insufficient sample (n=66) — do not model.
- is_dome: redundant — dome override zeroes weather correctly; no residual signal after env controls.
- CRITICAL: elevation, travel, and timezone are threshold-activated features. Signal only emerges above specific thresholds. Model as indicator×magnitude interaction, not linear.

### Day 12 — Momentum and Rolling Features
- last3_off_epa_avg: conference-specific — signal in ACC, Mid-American, SEC. Redundant in American Athletic, Big 12, Big Ten, Conference USA, Mountain West, Pac-12, Sun Belt. Null at conf game 1.
- last3_def_epa_avg: conference-specific supporting — signal holds from conf game 2, concentrates in American Athletic, Big Ten, Conference USA, Mid-American, Pac-12, Sun Belt.
- last3_points_scored_avg: conference-specific supporting — signal holds from conf game 2, concentrates in ACC, American Athletic, Big 12, Big Ten, Conference USA, Mid-American.
- last3_points_allowed_avg: supporting — signal holds from conf game 2, broad across conferences.
- last3_win_pct: supporting — signal holds from conf game 2, broad across conferences.
- days_since_last_game: conference-specific — bye week signal (>=12d) in Big 12, Mid-American, Mountain West only. Redundant elsewhere and in full population.
- All rolling features: in-season only, no prior seed, null at conf game 1.

### Day 13 — ELO and Excitement Index
- pregame_elo: supporting — game-level predictor. Spread r=0.181 full population, holds at conf game 1 (r=0.132). YoY r=0.854 (strong but not gating — game-level predictor). O/U signal absent. Spread signal only.
- elo_sp_divergence: supporting — spread r=0.176 after SP+ controlled, confirming ELO adds signal beyond SP+ for spread prediction. Compute in notebook first, add to dbt only after model confirms value.
- prior_avg_excitement_index: redundant — YoY r=0.134 (extremely unstable), cannot function as prior seed. Late-season O/U signal (games 9-12, r=0.192) insufficient — n=169 and does not hold earlier. Conference trajectory inconsistent.

### Day 14 — Play-by-Play Schema Exploration
**Play-by-play grain:** raw.plays is the only play-level table. 1,073,640 plays, 6,204 games, 2022–2025. No drive-level standalone table — drive_id and drive_number in raw.plays enable drive aggregation. PPA coverage: 75.7% overall, 99.76% on scrimmage plays.
**Style & tempo (verified computable per game from raw.plays):** success rate (overall, rush/pass splits, std_downs/pass_downs splits), stuff rate (rush yards_gained<=0), explosive rate (20+ and 10+ yard thresholds), line yards per rush (formula on yards_gained), sack rate (Sack play_type / pass attempts), points per opportunity (drive_id + scoring boolean), EPA splits (rush/pass, std_downs/pass_downs via ppa + play_type + down/distance), time of possession (game clock delta per drive, verified), field zone success and EPA (yards_to_goal buckets).
**Spatial features:** No hash position, no play direction columns, no boundary/field side. Pass direction in play_text for 10.27% of pass plays — inconsistent formatting, not usable. Rush direction in play_text for 0.00%. Field zone IS computable via yards_to_goal (red zone ≤10 yards, scoring zone 11-25, own half 26-50, deep own 51+).
**Not available (permanently closed):** Air yards, aDOT, YAC, time to throw, pressure rate, block win rates, hash position, play direction.
**Player tagging:** None. No player ID, position, or roster tables anywhere in schema.
**Havoc:** DB havoc not derivable game-by-game — passes defended not in raw.plays. Season-level def_havoc_* columns remain the only complete source. Proxy possible (sacks + interceptions + forced fumbles) but undercounts vs. CFBD definition.
**Recruiting by position:** Not available — raw.recruiting has no position column. Aggregate composite only.
**Opponent at play level:** offense/defense columns in raw.plays — opponent fully derivable for all 6,204 games.
**raw.odds:** 20 rows, 11 games, August–September 2026 only (Bovada, DraftKings, FanDuel). No historical closing lines. This is the live validation target — model predictions compared against these lines.
**raw.games:** conference_game boolean present for all games. home_win_prob available for 41% of rows (2022–2024 only, absent in 2025). attendance sparse.
**31 new candidates added to candidate_features.csv** (all raw.plays-derived, game-level computable).

---

## Decisions Confirmed by EDA (add to locked decisions)
- away_elevation_delta_ft: model as threshold-activated (>=2000ft), not linear
- away_travel_distance_mi: model as threshold-activated (>=1500mi), not linear
- away_tz_delta_hrs: model as threshold-activated (abs>=2hr), not linear
- wind_chill: model in triggered population (temp<50, wind>3) only
- heat_index: model in triggered population (temp>80, humidity>40) only
- Conference-specific dispersion: start single parameter, revisit in posterior checks
- ELO/SP+ divergence: compute in notebook first, not in dbt until model confirms
- excitement_index: retrospective — prior-season team average is not a usable prior seed

---

## Locked Decisions — Do Not Revisit
- Likelihood: Negative Binomial
- Elevation computation: earthdistance extension
- Timezone: COALESCE(IANA timezone, state CASE) hybrid
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
- Pac-12 in dataset: G5 for all seasons — Oregon/USC/UCLA moved to Big Ten;
  Arizona/Arizona State/Colorado/Utah moved to Big 12; Cal/Stanford moved to ACC.
  Teams labeled Pac-12 in data are the remnant G5-caliber conference.
- FBS Independents: not a pooling group — Notre Dame routes to P4, UConn routes to G5 by team name
- No tiers within conferences: team-level parameters handle within-conference spread
- Three-level hierarchy: league → conference → team
- Early-season null handling: Approach A — impute with season-to-date prior
- Style/tempo analysis: delta approach first, clustering second (Days 15–16)
- SP+/ELO divergence: compute in notebook first, add to dbt only if proven valid
- Portal and NIL: deprioritized — revisit only if model underperforms in evaluation
- def_epa_per_play_allowed (game-level): redundant — collinear with close_game_def_epa_per_play
- def_epa_per_play (season-level): ANCHOR FEATURE — prior seed, never dropped
- HFA: league-level baseline + team-level deviations. No conference-level HFA layer.
- opp_sp_rating_at_game_time: control variable only, not a model feature
- Hash position: does not exist in schema — permanently closed, never revisit
- Play direction (pass left/right/middle, rush direction): no structured column — play_text coverage 10% pass / 0% rush — permanently closed
- Air yards, aDOT, YAC, time to throw, pressure rate, block win rates: do not exist anywhere in schema — permanently closed
- Recruiting by position group: raw.recruiting has no position column — permanently closed
- PFF grades: no PFF table in any schema — permanently closed
- DB havoc game-level derivation: passes defended not in raw.plays — use season-level def_havoc_db only
- raw.odds: 2026 target season only — no historical closing lines exist
- Havoc columns: off_havoc_* excluded from all int layers — only def_havoc_* used

---

## Artifacts Status
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 185 features keep=True (154 prior + 31 raw.plays Day 14) |
| artifacts/epa_feature_verdict.csv | ✅ valid | Day 8 — correct methodology |
| artifacts/sp_recruiting_verdict.csv | ✅ valid | Day 9 — correct methodology |
| artifacts/hierarchy_verdict.json | ✅ valid | Day 10 — correct methodology |
| artifacts/environment_verdict.csv | ✅ valid | Day 11 — correct methodology |
| artifacts/momentum_verdict.csv | ✅ valid | Day 12 — correct methodology |
| artifacts/elo_excitement_verdict.csv | ✅ valid | Day 13 — correct methodology |

---

## YoY Benchmarks
- off_epa_per_play YoY r = 0.423
- def_epa_per_play YoY r = 0.393
- sp_rating YoY r = 0.761, 95% CI [0.718, 0.803]
- away_elevation_delta_ft YoY r = 0.827 — stable (anchor candidate)
- away_travel_distance_mi YoY r = 0.717 — unstable (below anchor threshold)
- away_tz_delta_hrs YoY r = 0.762 — unstable (below anchor threshold)
- pregame_elo YoY r = 0.854 — strong (game-level predictor, not gating)
- recruiting_3yr_avg YoY r = 0.975 — extremely stable (prior seed)
- excitement_index YoY r = 0.134 — extremely unstable (not usable as prior)

---

## Known Schema Facts — Use Exactly
- point_differential does not exist — derive as points_scored - points_allowed
- total_points does not exist — derive as points_scored + points_allowed
- Two distinct defensive EPA columns — do not confuse:
  - def_epa_per_play_allowed in int_game_team_features — GAME-LEVEL, redundant
  - def_epa_per_play in int_team_season_features — SEASON-LEVEL, anchor feature
- conference does NOT exist in int_game_team_features — join to
  int_team_season_context on team_name and season to get conference
- int_game_environment has home_team and away_team, not team_name — join on game_id
  only, then filter f.team_name IN (e.home_team, e.away_team)
- All numeric columns from psycopg2 return as Decimal — cast entire numeric column
  list to float64 immediately
- Connection: host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres
- Boolean columns (is_dome, is_high_wind, is_precipitation) return as Python objects
  with None values — use .map(lambda x: 1 if x is True else (0 if x is False else
  np.nan)).astype(float)
- opp_sp_rating_at_game_time exists in int_game_team_features
- pregame_elo, opponent_pregame_elo, postgame_elo, excitement_index exist in
  int_game_team_features
- kickoff_hour exists in stg.stg_game_weather (smallint, ET timezone) — not yet
  promoted to int layer
- raw.plays scrimmage play types for rush: 'Rush', 'Rushing Touchdown'
- raw.plays scrimmage play types for pass: 'Pass Reception', 'Pass Incompletion',
  'Passing Touchdown', 'Sack', 'Pass Completion', 'Pass Interception Return'
- raw.plays ppa coverage: 75.7% overall, 99.76% on scrimmage plays — use scrimmage
  filter before computing any EPA metric
- raw.plays yards_to_goal: 0–100 scale. Red zone = yards_to_goal <= 10.
- raw.plays std_downs: down=1, OR (down=2 AND distance<=8), OR (down IN (3,4) AND distance<=5)
- raw.plays pass_downs: (down=2 AND distance>8) OR (down IN (3,4) AND distance>5)
- raw.plays opponent: defense column = opponent of the offense on that play
- raw.odds: 2026 season only (Bovada, DraftKings, FanDuel) — not historical
- raw.games: conference_game boolean available for all rows; home_win_prob available
  2022–2024 only (absent 2025); attendance sparse (3,220 / 14,744 rows)

---

## Source Tables
- int.int_game_team_features — game-level team performance including pregame_elo,
  excitement_index
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context including conference
- int.int_team_season_features — season-level team features, 534 rows, FBS only
- stg.stg_game_weather — kickoff_hour available here, not yet in int layer

---

## Connection Pattern (psycopg2 only — no SQLAlchemy)
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

---

## Rules Every Session Must Follow
1. Read this file before touching anything else
2. Read artifacts/candidate_features.csv — only keep=True columns are authorized
3. Run schema introspection query before writing any SQL — never guess column names
4. Write complete cells only — never partial fixes or incremental edits
5. Use existing helpers — never redefine logic that already exists in the notebook
6. Cast all Decimal columns to float64 immediately after loading
7. Cast boolean columns using .map(lambda x: 1 if x is True else (0 if x is False
   else np.nan)).astype(float)
8. Do not rewrite verified cells
9. Do not close the DB connection until the notebook is complete
10. If a required column is not in the schema output, stop and say so — do not proceed
11. Use the canonical assign_tier function — do not modify it
12. Never use nbformat, papermill, or any script to generate notebook files
13. Every verdict must report spread signal, over/under signal, and moneyline signal
    separately — never collapse into a single verdict
14. Conference stratification is mandatory for every partial r test — full population,
    P4, G5, and each individual conference. Never issue a verdict from global analysis only.

---

## assign_tier Function — Canonical Version
Use this exact function in every notebook. Do not modify it.

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

Pac-12 falls through to G5. FBS Independents handled by team name conditions.

---

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the EDA table
3. Add any new locked decisions
4. Add key findings — spread, over/under, and moneyline reported separately
5. Rewrite the confirmation gate to reflect what the next session must understand
6. Update what the next session must build
7. Commit: git add docs/session_state.md && git commit -m "docs: update session
   state after Day X" && git push