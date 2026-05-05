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

**Next notebook: Day 16 — Style Archetypes and Matchup Interaction Effects**

Answer these questions in your own words before writing any code:

**Question 1:** Day 15 found that every linear style and tempo delta is redundant
after EPA and SP+ control. What does that result actually tell you about how style
information should be represented, and what specific failure of linear representation
motivates the clustering approach?

**Question 2:** You are about to run partial r tests on archetype matchup
combinations. Walk me through exactly what a positive result looks like — what
partial r threshold, against what outcome, controlling for what, stratified how —
and what it would mean for the model if you find it. Then do the same for a
negative result.

**Question 3:** This notebook assigns archetypes at the season level and tests them
at the game level. What are the specific ways that design can produce a false
positive result, and what constraints in the analysis prevent each one?

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
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed, VMR 4.95–7.16 (2022–2024) |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | close_game EPA pair = joint model anchor. off YoY r=0.4331, def YoY r=0.4224 |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.7741. Recruiting conference-specific prior seed. |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed. Team ICC 0.14–0.19. Conference ICC marginal. |
| 11 | eda_06_environmental_features.ipynb | ✅ complete | See environmental findings below |
| 12 | eda_07_momentum_rolling_features.ipynb | ✅ complete | See momentum findings below |
| 13 | eda_08_elo_excitement.ipynb | ✅ complete | See ELO/excitement findings below |
| 14 | Claude Code session | ✅ complete | Play-by-play schema verified. 31 new candidates added. Field zone derivable via yards_to_goal. Spatial/directional features permanently closed. raw.odds confirmed as 2026 live validation target only — no historical closing lines. |
| 15 | eda_09_style_tempo_delta.ipynb | ✅ complete | All 17 style/tempo deltas redundant after EPA+SP+ control. No linear matchup signal. YoY stability poor (max r=0.577). Clustering warranted. |
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
Day 16: eda_10_style_archetypes.ipynb — Style archetype clustering and matchup
interaction effects.

Key constraints:
- Cluster on 15 stable dimensions only (YoY r >= 0.40 from Day 15 clean results)
- def_stuff_rate_allowed at r=0.4311 — confirmed above threshold on clean data
- Use season-level averages computed from raw.plays — not rolling windows, not int_team_season_features
- Cluster offense and defense separately
- Fit clusters on 2022–2024 only. Apply fitted scaler and cluster centers to 2025 out-of-sample.
- Test matchup interaction effects (off_archetype x def_archetype) against spread
  and O/U after EPA + SP+ control using same partial r framework as Day 15
- FBS conference games only — same join pattern as Day 15
- All three outcome signals required: spread, O/U, variance
- Population for testing: 2022–2024 conference games only (1,607 matchup rows)

---

## Key Findings By Day

### Day 8 — EPA Deep Dive
- close_game_epa_per_play: anchor candidate — spread r=0.5988 at conf game 1, O/U r=0.4237, holds across full trajectory, YoY r=0.4331 (game-level predictor, not gated by YoY)
- close_game_def_epa_per_play: anchor candidate — spread r=-0.6134 at conf game 1, O/U r=0.4473, holds across full trajectory, YoY r=0.4224
- def_epa_per_play_allowed: redundant — collinear with close_game_def_epa_per_play (r=0.9775)
- last3_off_epa_avg: conference-specific supporting — signal in ACC, Mid-American, SEC only; null at conf game 1
- last3_def_epa_avg: conference-specific supporting — signal in American Athletic, Big Ten, Conference USA, Mid-American, Pac-12, Sun Belt; null at conf game 1

### Day 9 — SP+ and Recruiting
- team_sp_rating: anchor candidate — spread partial r=0.1822 after EPA control, YoY r=0.7741, holds at conf game 1 (r=0.2308). O/U signal absent.
- opp_sp_rating_at_game_time: redundant as model feature — use as control variable only. EPA anchor pair already captures opponent quality from focal team perspective.
- recruiting_3yr_avg: conference-specific prior seed — YoY r=0.9758 (extremely stable). Game-level spread signal in American Athletic, Sun Belt only. Redundant in ACC, Big 12, Big Ten, Conference USA, Mid-American, Mountain West, Pac-12, SEC. Must be modeled with conference-specific weight. Negative partial r after SP+ control in high-recruiting conferences — multicollinearity with SP+.

### Day 10 — Hierarchy Structure
- Three-level hierarchy confirmed: league → conference → team
- Team ICC: points_scored=0.1394, total_points=0.0764, point_differential=0.1925 — strong, justifies team level
- Conference ICC: points_scored=0.0226, total_points=0.0505, point_differential=0.0002 — marginal but pooling still provides regularization
- VMR range: 4.948–7.158 (ratio=1.447) — below 1.5 threshold. Start with single dispersion parameter. Add conference-specific r only if posterior predictive checks show systematic miscalibration.
- HFA: league-level +2.48 pts (p<0.001). Team HFA SD=4.85 pts — team-level deviations justified. Conference HFA range 4.19 pts — no conference-level HFA layer needed.
- Team scoring YoY r=0.35–0.49 (raw). Prior must be anchored by SP+ and EPA, not raw scoring history.

### Day 11 — Environmental Features
- away_elevation_delta_ft: anchor candidate — spread r=0.1518 at delta>=2000ft, YoY r=0.8255. Signal concentrates in Mountain West and Big 12. Full population r near zero — threshold-activated feature, not linear predictor.
- venue_elevation_ft: redundant — no threshold cleared. Use away_elevation_delta_ft.
- away_travel_distance_mi: supporting — spread r=0.2011 at >=1500mi, YoY r=0.6562 (below anchor threshold). Spread signal only. No O/U signal.
- away_tz_delta_hrs: supporting — spread r=-0.2669 at abs>=2hr, strengthens at abs>=3hr (r=-0.3103, n=38). YoY r=0.6710. Spread signal only.
- kickoff_hour × away_tz_delta_hrs: insufficient sample (n=8) — do not model.
- wind_speed_mph, wind_gusts_mph, is_high_wind: redundant — no signal after EPA control at any threshold. Absorbed by EPA anchor pair.
- wind_chill: supporting — O/U signal only at <=40°F (r=0.1122, n=315). Strengthens at <=25°F (r=0.3373, n=71). No spread signal.
- temperature_f: supporting — O/U signal only at <=40°F (r=0.1339, n=227). Largely absorbed by wind_chill composite.
- humidity_pct: redundant — no signal in triggered population on clean data.
- heat_index: redundant — O/U signal absent in triggered population on clean data. Do not model.
- precipitation_inches, is_precipitation: insufficient sample (n=44) — do not model.
- is_dome: redundant — dome override zeroes weather correctly; no residual signal after env controls.
- CRITICAL: elevation, travel, and timezone are threshold-activated features. Signal only emerges above specific thresholds. Model as indicator×magnitude interaction, not linear.

### Day 12 — Momentum and Rolling Features
- last3_off_epa_avg: conference-specific — signal in ACC, Conference USA, Mid-American, Mountain West, SEC. Redundant in American Athletic, Big 12, Big Ten, Pac-12, Sun Belt. Null at conf game 1.
- last3_def_epa_avg: conference-specific supporting — signal holds from conf game 2, concentrates in American Athletic, Big Ten, Conference USA, Mid-American, Pac-12, Sun Belt.
- last3_points_scored_avg: conference-specific supporting — signal holds from conf game 2, concentrates in ACC, Big 12, Big Ten, Conference USA, Mid-American, Mountain West.
- last3_points_allowed_avg: conference-specific supporting — signal holds from conf game 2, concentrates in American Athletic, Big Ten, Conference USA, Mountain West, Pac-12, Sun Belt.
- last3_win_pct: supporting — signal holds from conf game 2, broad across conferences.
- days_since_last_game: conference-specific — bye week signal (>=12d) in American Athletic and Big 12 only. Redundant elsewhere and in full population.
- All rolling features: in-season only, no prior seed, null at conf game 1.

### Day 13 — ELO and Excitement Index
- pregame_elo: supporting — game-level predictor. Spread r=0.1702 full population, holds at conf game 1 (r=0.1870). YoY r=0.8452 (strong but not gating — game-level predictor). O/U signal absent. Spread signal only.
- elo_sp_divergence: supporting — spread r=0.1650 after SP+ controlled, confirming ELO adds signal beyond SP+ for spread prediction. Compute in notebook first, add to dbt only after model confirms value.
- prior_avg_excitement_index: redundant — YoY r=0.1877 (extremely unstable), cannot function as prior seed. Late-season O/U signal (games 9-12, r=0.3115) does not hold earlier. Conference trajectory inconsistent.

### Day 14 — Play-by-Play Schema Exploration
- raw.plays grain: only play-level table. 1,073,640 plays, 6,204 games, 2022–2025. No standalone drive table — drive_id and drive_number enable drive aggregation. PPA: 75.7% overall, 99.76% on scrimmage plays.
- Computable per game from raw.plays: success rate (overall, rush/pass splits, std_downs/pass_downs splits), stuff rate (yards_gained<=0 on rush), explosive rate (20+ and 10+ yard thresholds), line yards per rush, sack rate, points per opportunity, EPA splits, time of possession, field zone success and EPA.
- Spatial features: permanently closed — no hash position, no play direction, no boundary/field side anywhere in schema.
- Permanently closed: air yards, aDOT, YAC, time to throw, pressure rate, block win rates, hash position, play direction, player tagging.
- raw.odds: 2026 season only — no historical closing lines. Live validation target only.
- 31 new candidates added to candidate_features.csv — all raw.plays-derived, game-level computable.

### Day 15 — Style and Tempo Delta Analysis
- Population: 1,607 FBS conference game matchups, 2022–2024. P4=754, G5=853.
- Result: ALL 17 style/tempo deltas redundant after EPA anchor pair + SP+ control. No feature cleared 0.08 threshold on spread or O/U. No variance signal on any feature.
- Highest spread partial r: delta_off_success_rate_pass=0.0445. Highest O/U: delta_off_success_rate_std_downs=0.0517. Both below threshold.
- Trajectory: 10 of 17 weaken across season arc. 5 stable. 2 strengthen.
- YoY stability: no metric reached stable threshold (r>=0.70). Best: rush_rate_std_downs r=0.5766. Redzone metrics, time_of_possession, sack_rate all below r=0.10 — excluded from Day 16 clustering space.
- Conference sign flips observed: delta_rush_rate_pass_downs SEC r=-0.067 vs American Athletic r=+0.031. delta_off_success_rate_pass SEC r=+0.168 vs Conference USA r=-0.118. Suggests conference-specific style effects linear coefficients cannot model.
- Conclusion: linear deltas wrong representation. Clustering warranted. Style and tempo not dead — representation needs to change.
- Stable dimensions for Day 16 clustering (YoY r>=0.40, from clean 2022–2024 run):
  rush_rate_std_downs (0.5766), off_success_rate_std_downs (0.5547),
  def_pts_per_opportunity_allowed (0.5429), rush_rate_pass_downs (0.5177),
  off_success_rate_rush (0.5111), off_pts_per_opportunity (0.5108),
  off_line_yards_per_rush (0.4916), off_stuff_rate (0.4910),
  off_success_rate_pass (0.4872), off_explosive_rate_10 (0.4674),
  off_epa_rush (0.4419), def_stuff_rate_allowed (0.4311),
  def_success_rate_rush (0.4278), def_success_rate_std_downs (0.4182),
  def_epa_rush_allowed (0.4088).

---

## Decisions Confirmed by EDA
- away_elevation_delta_ft: model as threshold-activated (>=2000ft), not linear
- away_travel_distance_mi: model as threshold-activated (>=1500mi), not linear
- away_tz_delta_hrs: model as threshold-activated (abs>=2hr), not linear
- wind_chill: model in triggered population (temp<50, wind>3) only
- heat_index: redundant — no O/U signal on clean 2022–2024 data. Do not model.
- humidity_pct: redundant — no signal in triggered population. Do not model.
- Conference-specific dispersion: start single parameter, revisit in posterior checks
- ELO/SP+ divergence: compute in notebook first, not in dbt until model confirms
- excitement_index: retrospective — prior-season team average is not a usable prior seed
- Style/tempo linear deltas: ALL redundant after EPA+SP+ control — do not model as linear features
- Style/tempo clustering: cluster on 15 stable dimensions (YoY r>=0.40) using raw.plays season averages only
- Redzone metrics, time of possession, sack rate: excluded from clustering space (YoY r<0.30)
- recruiting_3yr_avg: game-level spread signal in American Athletic and Sun Belt only (Big Ten and Conference USA signal does not survive on clean data)
- days_since_last_game: bye week signal in American Athletic and Big 12 only (Mid-American and Mountain West signal does not survive on clean data)

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
- Pac-12 in dataset: G5 for all seasons — Oregon/USC/UCLA moved to Big Ten; Arizona/Arizona State/Colorado/Utah moved to Big 12; Cal/Stanford moved to ACC. Teams labeled Pac-12 in data are the remnant G5-caliber conference.
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
- Play direction (pass left/right/middle, rush direction): no structured column — permanently closed
- Air yards, aDOT, YAC, time to throw, pressure rate, block win rates: do not exist anywhere in schema — permanently closed
- Recruiting by position group: raw.recruiting has no position column — permanently closed
- PFF grades: no PFF table in any schema — permanently closed
- DB havoc game-level derivation: passes defended not in raw.plays — use season-level def_havoc_db only
- raw.odds: 2026 target season only — no historical closing lines exist
- Havoc columns: off_havoc_* excluded from all int layers — only def_havoc_* used
- Style/tempo linear deltas: ALL 17 redundant — do not model as linear features
- Rolling windows for clustering: do not use — use raw.plays season averages only
- Clustering dimensions: exclude redzone metrics, time of possession, sack rate (YoY r<0.30)
- EDA training population: 2022–2024 only. 2025 is holdout — excluded from all EDA signal tests, YoY stability calculations, and cluster fitting. 2025 archetypes assigned out-of-sample using fitted cluster centers.

---

## Artifacts Status
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 185 features keep=True (154 prior + 31 raw.plays Day 14) |
| artifacts/epa_feature_verdict.csv | ✅ valid | Day 8 — rerun on 2022–2024 clean data |
| artifacts/sp_recruiting_verdict.csv | ✅ valid | Day 9 — rerun on 2022–2024 clean data |
| artifacts/hierarchy_verdict.json | ✅ valid | Day 10 — rerun on 2022–2024 clean data |
| artifacts/environment_verdict.csv | ✅ valid | Day 11 — rerun on 2022–2024 clean data |
| artifacts/momentum_verdict.csv | ✅ valid | Day 12 — rerun on 2022–2024 clean data |
| artifacts/elo_excitement_verdict.csv | ✅ valid | Day 13 — rerun on 2022–2024 clean data |
| artifacts/style_tempo_verdict.csv | ✅ valid | Day 15 — rerun on 2022–2024 clean data |

---

## YoY Benchmarks
All values from clean 2022–2024 training data only.

- off_epa_per_play YoY r = 0.4331
- def_epa_per_play YoY r = 0.4224
- sp_rating YoY r = 0.7741
- away_elevation_delta_ft YoY r = 0.8255 — stable (anchor candidate)
- away_travel_distance_mi YoY r = 0.6562 — unstable (below anchor threshold)
- away_tz_delta_hrs YoY r = 0.6710 — unstable (below anchor threshold)
- pregame_elo YoY r = 0.8452 — strong (game-level predictor, not gating)
- recruiting_3yr_avg YoY r = 0.9758 — extremely stable (prior seed)
- excitement_index YoY r = 0.1877 — extremely unstable (not usable as prior)
- rush_rate_std_downs YoY r = 0.5766 — best style/tempo metric (moderate)
- off_success_rate_std_downs YoY r = 0.5547 — moderate
- def_pts_per_opportunity_allowed YoY r = 0.5429 — moderate
- rush_rate_pass_downs YoY r = 0.5177 — moderate
- off_success_rate_rush YoY r = 0.5111 — moderate
- off_pts_per_opportunity YoY r = 0.5108 — moderate
- off_line_yards_per_rush YoY r = 0.4916 — unstable (above 0.40 threshold)
- off_stuff_rate YoY r = 0.4910 — unstable (above 0.40 threshold)
- off_success_rate_pass YoY r = 0.4872 — unstable (above 0.40 threshold)
- off_explosive_rate_10 YoY r = 0.4674 — unstable (above 0.40 threshold)
- off_epa_rush YoY r = 0.4419 — unstable (above 0.40 threshold)
- def_stuff_rate_allowed YoY r = 0.4311 — unstable (above 0.40 threshold, confirmed)
- def_success_rate_rush YoY r = 0.4278 — unstable (above 0.40 threshold)
- def_success_rate_std_downs YoY r = 0.4182 — unstable (above 0.40 threshold)
- def_epa_rush_allowed YoY r = 0.4088 — unstable (above 0.40 threshold)
- time_of_possession YoY r = 0.0574 — extremely unstable
- off_success_rate_redzone YoY r = 0.0518 — extremely unstable
- def_sack_rate YoY r = 0.2161 — unstable

---

## Known Schema Facts — Use Exactly
- point_differential does not exist — derive as points_scored - points_allowed
- total_points does not exist — derive as points_scored + points_allowed
- Two distinct defensive EPA columns — do not confuse:
  - def_epa_per_play_allowed in int_game_team_features — GAME-LEVEL, redundant
  - def_epa_per_play in int_team_season_features — SEASON-LEVEL, anchor feature
- conference does NOT exist in int_game_team_features — join to
  int_team_season_features on team_name and season to get conference
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
- CRITICAL JOIN PATTERN: conference and sp_rating come from int_team_season_features
  joined on team_name + season. raw.games home_team/away_team strings do NOT match
  int_team_season_features team_name. Always join through int_game_team_features
  team_name as the bridge — never join team name columns directly from raw.games.

---

## Source Tables
- int.int_game_team_features — game-level team performance including pregame_elo,
  excitement_index
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context
- int.int_team_season_features — season-level team features, FBS only, includes
  conference and sp_rating (authoritative source for both)
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
2. Never take shortcuts or lazy solutions. If a query fails, read the actual schema before rewriting. If data is wrong, diagnose the actual cause before fixing. Never patch inline — rewrite the entire cell. Never guess column names. Never assume a filter handles exclusions it was not designed to handle.
3. Read artifacts/candidate_features.csv — only keep=True columns are authorized
4. Run schema introspection query before writing any SQL — never guess column names
5. Write complete cells only — never partial fixes or incremental edits
6. Use existing helpers — never redefine logic that already exists in the notebook
7. Cast all Decimal columns to float64 immediately after loading
8. Cast boolean columns using `.map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)`
9. FBS conference games only, no exceptions. Every game-level query must filter `s.conference != 'FBS Independents'` in the join to `int_team_season_features`. Both teams must have a valid FBS conference. `conference_game = TRUE` alone does not exclude Independents. After loading, assert zero nulls on all controls — any null means a non-FBS team leaked through. If the home conference distribution shows FBS Independents with any row count, stop and fix before proceeding.
10. Do not rewrite verified cells
11. Do not close the DB connection until the notebook is complete
12. If a required column is not in the schema output, stop and say so — do not proceed
13. Use the canonical assign_tier function — do not modify it
14. Never use nbformat, papermill, or any script to generate notebook files
15. Every verdict must report spread signal, over/under signal, and moneyline signal separately — never collapse into a single verdict
16. Conference stratification is mandatory for every partial r test — full population, P4, G5, and each individual conference. Never issue a verdict from global analysis only.
17. Season filter mandatory: every query must include AND season IN (2022, 2023, 2024). 2025 is the holdout year and must never appear in training data queries.

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

### FBS Integrity Check — Mandatory After Every Game Load
Report this back to me verbatim after answering the confirmation gate questions then tell me exactly what that means:

FBS conference games only. Both teams must have a row in int_team_season_features
with conference != 'FBS Independents'. conference_game = TRUE does not filter out
FCS, D2, D3, or Independent opponents. The INNER JOIN to int_team_season_features
handles non-FBS teams with no season row. The conference != 'FBS Independents'
filter handles Independents who do have a season row. Both filters are required.
Show the home conference distribution after every game load — if FBS Independents
appears with any row count, stop and fix before proceeding.

---

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the EDA table
3. Add any new locked decisions
4. Add key findings — spread, over/under, and moneyline reported separately
5. Rewrite the confirmation gate to reflect what the next session must understand
6. Update what the next session must build
7. Commit: git add docs/session_state.md && git commit -m "docs: update session state after Day X" && git push