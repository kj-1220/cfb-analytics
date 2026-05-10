# CFB Analytics — Session State

## Last Updated
2026-05-09

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

**Prior seeds vs game-level predictors — this distinction is mandatory.**
- Prior seeds (SP+, recruiting): evaluated for YoY stability, SP+ collinearity,
  and prior weight by conference. NEVER tested against specific game outcomes.
  Prior seeds inform where the model starts before seeing any game data.
- Game-level predictors (close-game EPA, ELO, rolling momentum, style metrics):
  evaluated for partial r against specific game outcomes. These are known going
  into a specific game and improve prediction beyond the prior.
Conflating these two categories is a fundamental methodological error.

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

**Next notebook: Day 20 — Prior Specification**

Answer these questions in your own words before writing any code:

**Question 1:** What is the difference between a prior specification and a PyMC
model? Why must Day 20 read prior_specification_draft.md before writing any
pm. distribution calls? What would go wrong if Day 20 invented a prior that
isn't in the specification?

**Question 2:** The Sun Belt recruiting weight must be non-positive. What does
that mean in PyMC terms? Name at least two ways to implement a non-positive
constraint and explain which is preferable for this model and why.

**Question 3:** Day 20 writes priors but does not fit the model. What does that
mean for what Day 20 must produce, and how does Day 23 (first fit) depend on
Day 20 being complete and correct?

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
- Priors seeded from: SP+ preseason rating, recruiting composite (conference-specific
  weight), pregame_elo (game-level, not prior seed)
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
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ prior anchor YoY r=0.7740. Recruiting prior seed YoY r=0.9779. Prior seed analysis only — neither tested as game-level predictor. |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed. Team ICC 0.14–0.19. Conference ICC marginal. |
| 11 | eda_06_environmental_features.ipynb | ✅ complete | See environmental findings below |
| 12 | eda_07_momentum_rolling_features.ipynb | ✅ complete | See momentum findings below |
| 13 | eda_08_elo_excitement.ipynb | ✅ complete | See ELO/excitement findings below |
| 14 | Claude Code session | ✅ complete | Play-by-play schema verified. 31 new candidates added. Field zone derivable via yards_to_goal. Spatial/directional features permanently closed. raw.odds confirmed as 2026 live validation target only — no historical closing lines. |
| 15 | eda_09_style_tempo_delta.ipynb | ✅ complete | Rebuilt correctly at game level with in-game style metrics. Spread signal strongest. O/U signal weak. Moneyline variance signal mainly tied to sack-rate mismatch. Only rush_rate_std_downs and rush_rate_pass_downs are weak prior-seed candidates. |
| 16 | eda_10_style_archetypes.ipynb | ✅ complete | Rebuilt from corrected EDA 9. k=4 offense and k=4 defense archetypes validated. Archetypes are strongest for over/under, weak secondary for spread, not valid for moneyline variance, and not stable enough for prior seeding. |
| 17 | eda_11_game_script.ipynb | ✅ complete | game_script_avg_margin and game_script_ordinal: diagnostic_only (retrospective, near-tautological with point_differential). close_game_play_count_delta: conference_specific_candidate for spread (6/10 conferences, holds from game_1). |
| 18 | eda_12_evaluation_framework.ipynb | ✅ complete | 39-item pass/fail evaluation checklist written to artifacts/evaluation_checklist.md |
| 19 | eda_13_eda_finalization.ipynb | ✅ complete | master_verdict.csv (93 rows, 23 include), final_features.csv (23 rows, all with prior specs), ambiguity_resolution.md (5 binding decisions), prior_specification_draft.md |

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
Day 20: `model_01_prior_specification.ipynb`

Goal:
Translate every entry in artifacts/prior_specification_draft.md into a
written PyMC prior distribution. No model fitting. No data loading beyond
what is needed to establish team and conference index mappings.

This notebook produces one output: a fully specified PyMC model object with
all priors defined and documented. Every pm. distribution call must include
a comment citing the EDA finding from prior_specification_draft.md that
motivated it.

Rules:
- Read prior_specification_draft.md before writing any code
- Do not invent priors — if a parameter is missing from the spec, stop and flag it
- Sun Belt recruiting weight must be non-positive (hard constraint)
- Conference-specific feature weights are implemented as coefficient ×
  conference indicator — not as separate conference-level distributions
- No fitting in this notebook — pm.sample() is not called
- Document every design decision and the spec entry that motivated it

### FBS Integrity Check for Day 20
Day 20 loads team and conference index mappings from int_team_season_features.
The standard FBS integrity check applies: both teams must have a row in
int_team_season_features with conference != 'FBS Independents'. Show conference
distribution after every load and assert FBS Independents does not appear.

---

## Key Findings By Day

### Day 8 — EPA Deep Dive
- close_game_epa_per_play: anchor candidate — spread r=0.5988 at conf game 1, O/U r=0.4237, holds across full trajectory, YoY r=0.4331 (game-level predictor, not gated by YoY)
- close_game_def_epa_per_play: anchor candidate — spread r=-0.6134 at conf game 1, O/U r=0.4473, holds across full trajectory, YoY r=0.4224
- def_epa_per_play_allowed: redundant — collinear with close_game_def_epa_per_play (r=0.9775)
- last3_off_epa_avg: conference-specific supporting — signal in ACC, Mid-American, SEC only; null at conf game 1
- last3_def_epa_avg: conference-specific supporting — signal in American Athletic, Big Ten, Conference USA, Mid-American, Pac-12, Sun Belt; null at conf game 1

### Day 9 — SP+ and Recruiting
SP+ and recruiting are PRIOR SEEDS ONLY. Neither was tested against specific game
outcomes. The correct question for prior seeds is stability and prior weight, not
game-level signal.

- sp_rating: PRIOR SEED — YoY r=0.7740 (avg of 2022→2023 r=0.7965 and 2023→2024
  r=0.7514). Prior decay confirmed: spread partial r=0.2240 at conf game 1 after
  EPA control. Does not decay monotonically — Games 9-12 r=0.2609, prior remains
  relevant throughout season. Do not aggressively down-weight SP+ as games
  accumulate. O/U signal absent. Conference variation at game 1: American Athletic
  r=0.4254, Mid-American r=0.4291, Big Ten r=0.3994 strongest. Conference USA and
  Pac-12 insufficient sample at game 1. sp_offense YoY r=0.6060, sp_defense YoY
  r=0.6725 — less stable than sp_rating. Use sp_rating as anchor, not components.
- recruiting_3yr_avg: PRIOR SEED ONLY — YoY r=0.9779 (extremely stable). Never
  test against game-level outcomes. Prior weight by conference: Big Ten moderate
  (rec↔sp_r=0.7456, rec↔diff_r=0.6601), SEC moderate (rec↔sp_r=0.6730,
  rec↔diff_r=0.6153), all other conferences low weight. Sun Belt negative
  rec↔diff_r (-0.2665) — do not use as positive prior signal.
- opp_sp_rating_at_game_time: control variable only, not a model feature or prior seed.

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
EDA 9 was rebuilt correctly after invalidating the previous version.

Correct grain:
- one row per team per game
- style metrics computed from plays in that specific game
- matchup deltas computed as home metric minus away metric
- no season-average input to matchup delta tests
- no rolling-window input to in-game signal tests

Population:
- 1,607 valid FBS conference games
- 3,214 team-game rows
- 1,604 analysis games after dropping 3 games with missing required `close_game_epa_delta`
- seasons 2022–2024 only
- 2025 fully excluded
- FBS Independents excluded

Feature dimensions tested:
- 24 total style dimensions
- rush and pass
- offense and defense
- pass-defense dimensions included

Controls:
- `close_game_epa_delta`
- `sp_rating_delta`

Full-population spread signal:
- `rush_rate_std_downs_delta`
- `rush_rate_pass_downs_delta`
- `off_pts_per_opportunity_delta`
- `def_pts_per_opportunity_allowed_delta`
- `off_success_rate_pass_delta`
- `def_success_rate_pass_allowed_delta`
- `off_epa_pass_delta`
- `def_epa_pass_allowed_delta`

Over/under:
- full-population O/U signal was weak
- bucket/conference-specific O/U signals exist but are not broad anchor findings

Moneyline variance:
- clearest full-population moneyline variance candidate is sack-rate mismatch
- `off_sack_rate_allowed_delta`: abs residual variance partial r = +0.0919
- `def_sack_rate_delta`: abs residual variance partial r = -0.0919
- squared residual variance was directionally similar but slightly below threshold

Within-season trajectory:
- spread signal was strongest and most consistent
- `rush_rate_std_downs_delta` cleared in every conference-game bucket:
  - conf game 1: r = 0.2965
  - games 2–4: r = 0.2774
  - games 5–8: r = 0.3018
  - games 9–12: r = 0.3628
- pass-game dimensions also mattered for spread:
  - `off_success_rate_pass_delta`
  - `def_success_rate_pass_allowed_delta`
  - `off_epa_pass_delta`
  - `def_epa_pass_allowed_delta`

YoY stability:
- only 2 of 24 style dimensions cleared weak prior-seed threshold:
  - `rush_rate_std_downs`: avg YoY r = 0.4890
  - `rush_rate_pass_downs`: avg YoY r = 0.4648
- no style metric cleared strong prior-seed threshold
- style/tempo dimensions are mostly game-level predictors, not strong prior seeds

Final EDA 9 verdict:
- Spread: meaningful signal, especially rush tendency and pass efficiency mismatch
- Over/under: weak globally, some conference/bucket-specific signal
- Moneyline variance: sack-rate mismatch candidate
- Prior seed: only `rush_rate_std_downs` and `rush_rate_pass_downs` are weak candidates
- Do not use the invalidated old EDA 9 outputs

### Day 16 — Style Archetypes
EDA 10 was rebuilt from the corrected EDA 9 output. The previous EDA 10 is invalid.

Inputs:
- rebuilt `artifacts/style_tempo_verdict.csv`
- rebuilt `artifacts/style_tempo_summary.json`
- 24 eligible EDA 9 style dimensions

Population:
- 1,607 valid FBS conference games
- 3,214 team-game rows
- 1,604 analysis games after dropping the same 3 missing-control games
- 2022–2024 only
- 2025 fully excluded
- FBS conference games only

Clustering:
- k-means diagnostics showed silhouette favored k=2, but k=2 was too coarse for archetype analysis
- k=3, k=4, and k=5 were profiled
- final working choice:
  - offense k=4
  - defense k=4

Offense archetypes:
- `high_efficiency_balanced`
- `pass_leaning_efficient`
- `run_leaning_limited_pass`
- `low_efficiency_struggling`

Defense archetypes:
- `strong_all_phase`
- `struggling_all_phase`
- `pass_vulnerable_run_stopper`
- `rush_vulnerable_moderate_pass`

Spot checks:
- every 2022–2024 CFP team was included in the sanity check list
- Notre Dame 2024 was the only missing CFP team, expected under FBS conference-game-only filter
- Michigan 2023 defense = `strong_all_phase`
- Georgia 2022 defense = `strong_all_phase`
- Iowa 2023 offense = `low_efficiency_struggling`
- Kent State 2023 offense = `low_efficiency_struggling`
- USC 2023 defense = `struggling_all_phase`
- labels passed hard sanity checks

Outcome validation:
- archetype matchups tested against:
  - `point_differential`
  - `total_points`
  - `abs_spread_residual`
  - `squared_spread_residual`
- controls:
  - `close_game_epa_delta`
  - `sp_rating_delta`
- minimum matchup threshold:
  - full population: 30
  - stratified: 15

Full-population over/under:
- strongest EDA 10 finding
- `defense_archetype_matchup`: eta² = 0.3901
- `offense_archetype_matchup`: eta² = 0.3684
- `away_off_vs_home_def_matchup`: eta² = 0.2328
- `home_off_vs_away_def_matchup`: eta² = 0.2234

Full-population spread:
- modest secondary signal
- `defense_archetype_matchup`: eta² = 0.0213
- `offense_archetype_matchup`: eta² = 0.0188
- `home_off_vs_away_def_matchup`: eta² = 0.0103
- `away_off_vs_home_def_matchup`: did not clear threshold

Moneyline variance:
- do not promote
- full-population moneyline variance tests did not clear threshold
- some stratified eta thresholds cleared, but results were noisy and often had weak p-values

Stratified validation:
- over/under held broadly across tiers, seasons, and many conferences
- stratified over/under clear counts:
  - conference: 35
  - season: 12
  - tier: 8
- spread was weaker and secondary
- moneyline variance was noisy and should not be promoted

YoY stability:
- archetypes are not stable enough for prior seeding
- offense retention:
  - 2022→2023: 0.3548
  - 2023→2024: 0.2636
- defense retention:
  - 2022→2023: 0.3952
  - 2023→2024: 0.2481
- modal archetype share around 0.50, meaning teams move between archetypes across games

Final EDA 10 verdict:
- Primary use: over/under / total-points candidate
- Secondary use: weak supporting spread feature
- Do not use for: moneyline variance
- Do not use for: preseason prior seeding
- Do not treat archetypes as fixed team identities
- Do not directly promote in-game archetypes into the production pregame model
- If archetypes are used later, a deployable pregame/rolling version must be tested first

### Day 17 — Game Script Analysis
- game_script_avg_margin_delta: diagnostic_only — raw r=0.9075 with
  point_differential. R²=0.8235 alone. Average margin across game IS the score
  by construction. Near-tautological. Post-game feature only. Do not use as
  model input.
- game_script_ordinal_delta: diagnostic_only — raw r=0.8628 with
  point_differential. Ordinal categories derived from in-game score margin.
  Post-game feature only. Do not use as model input.
- close_game_play_count_delta: conference_specific_candidate — spread partial
  r=0.1834 full population (p<0.0001). Not tautological (raw r=0.2256).
  Signal holds in 6/10 conferences: ACC, American Athletic, Big 12,
  Mid-American, Pac-12, Sun Belt. Absent in Big Ten, Conference USA,
  Mountain West, SEC. No clean tier split.
  Trajectory: holds from game_1 (r=0.1676), strengthens monotonically to
  games_9_12 (r=0.2480). Available at all information states.
  O/U: Big 12 only (r=-0.2282, p=0.0019). game_1 bucket (r=0.1713) narrow.
  Too isolated to generalize.
  Moneyline variance: no signal across full population or any trajectory bucket.
  YoY stability: not applicable — game-level predictor.
  Prior seed: not applicable.

  ### Day 18 — Evaluation Framework
This notebook produced a document, not signal tests. No partial r values.
No feature verdicts. No new EDA findings.

Output: artifacts/evaluation_checklist.md — 39-item pass/fail checklist
that model_14_signoff.ipynb (Day 33) works through item by item.
Model is not signed off until every item has an explicit PASS or a
documented exception with written justification.

Checklist dimensions and item counts:
- Convergence and Sampling Quality (5 items): R-hat, ESS, divergences,
  trace plots, BFMI energy plots
- Prior Predictive Checks (3 items): score range, VMR consistency,
  total points distribution
- Posterior Predictive Checks (4 items): overall score distribution fit,
  conference-level calibration, dispersion parameter adequacy, tail behavior
- Holdout Evaluation — 2025 season (4 items): Brier score vs baseline,
  win probability calibration curve, spread MAE by margin bucket,
  over/under calibration
- Subgroup Evaluation (8 items): P4 Brier, G5 Brier, calibration by
  individual conference, rivalry games, cross-tier matchups, neutral site
  games, conf game 1 (prior-driven), conf games 5–8 (posterior-informed)
- Edge Case Stress Tests (6 items): elevation >= 2000ft, travel >= 1500mi,
  timezone abs >= 2hr, wind_chill <= 25°F, thin-data teams, conference
  switchers
- Feature Contribution Checks (5 items): EPA anchor pair direction, SP+
  prior weight decay, conference-specific features fire correctly,
  threshold-activated features activate correctly, Sun Belt recruiting
  prior direction
- Known Failure Modes (4 items): conf game 1 null handling, G5 thin-data
  estimates, cross-tier miscalibration, Sun Belt recruiting direction
  (duplicate gate from feature contribution checks)

Key thresholds established:
- R-hat < 1.01 for all parameters
- ESS_bulk >= 400 and ESS_tail >= 400 for all parameters
- Zero divergences post-warmup
- BFMI > 0.3 for all chains
- Prior predictive: 95% of samples within 0–70 points, VMR 3.0–10.0
- Posterior predictive mean within ±2 points of observed mean per team
- Conference-level posterior predictive mean within ±3 points of observed
- Overall Brier score must beat SP+-only baseline
- Win probability calibration within ±5pp per decile bucket (n >= 20)
- Spread MAE <= 14 points overall, no margin bucket exceeding 18 points
- P4 Brier <= 0.23, G5 Brier <= 0.25
- All 10 conferences calibrated within ±8pp (n >= 10)
- Cross-tier mean P4 win probability vs G5 between 0.72 and 0.88
- Sun Belt recruiting prior weight must be non-positive

### Day 19 — EDA Finalization
No new signal tests. Consolidation only.

master_verdict.csv: 93 rows total. 23 include, 70 exclude.
- Anchor features (3): close_game_epa_per_play, close_game_def_epa_per_play,
  away_elevation_delta_ft
- Prior seeds (2): sp_rating, recruiting_3yr_avg
- Conference-specific (8): last3_off_epa_avg, last3_def_epa_avg,
  last3_points_scored_avg, last3_points_allowed_avg, days_since_last_game,
  close_game_play_count_delta, offense_archetype_matchup, defense_archetype_matchup
- Supporting (10): all remaining included game-level features

Five ambiguity resolutions (all binding):
1. close_game_play_count_delta → INCLUDE for 6 confirmed conferences
2. Style archetype matchup features (×4) → INCLUDE as game-level O/U features;
   deployable pregame version required before September 24, 2026 launch
3. last3 rolling EPA conference lists → INCLUDE with explicit separate lists
   (offense: ACC, Mid-American, SEC; defense: American Athletic, Big Ten,
   Conference USA, Mid-American, Pac-12, Sun Belt)
4. rush_rate prior seeds → EXCLUDE as prior seeds (YoY r below 0.5 threshold);
   retained as game-level supporting predictors
5. elo_sp_divergence → INCLUDE computed in notebook; add to dbt after model confirms

Prior specification draft: every model parameter specified with distribution
family, mean, SD, informative/weakly-informative label, and EDA justification.
Sun Belt recruiting weight hard-constrained to non-positive.

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
- recruiting_3yr_avg: prior seed only — never test against game-level outcomes.
  Moderate prior weight in Big Ten and SEC. Low weight everywhere else.
  Negative rec↔outcome correlation in Sun Belt — do not use as positive prior signal.
- days_since_last_game: bye week signal in American Athletic and Big 12 only
- sp_rating prior weight: does not decay monotonically — remains relevant through
  games 9-12. Do not aggressively down-weight as games accumulate.
- sp_offense and sp_defense: less stable than sp_rating. Use sp_rating as anchor only.
- Style/tempo deltas: rebuilt at correct game-level grain. Strongest value is spread.
- Style/tempo prior seeds: only `rush_rate_std_downs` and `rush_rate_pass_downs` are weak prior-seed candidates.
- Style archetypes: valid as descriptive game-level matchup features, strongest for totals.
- Style archetypes: not valid for moneyline variance.
- Style archetypes: not stable enough for prior seeding.
- In-game style archetypes must not be promoted directly into the production pregame model.

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
- recruiting_3yr_avg: high school recruiting only. Prior seed only — never a game-level predictor.
- Conference assignment: historically accurate by season from game records
- Pac-12 in dataset: G5 for all seasons — Oregon/USC/UCLA moved to Big Ten; Arizona/Arizona State/Colorado/Utah moved to Big 12; Cal/Stanford moved to ACC. Teams labeled Pac-12 in data are the remnant G5-caliber conference.
- FBS Independents: not a pooling group — Notre Dame routes to P4, UConn routes to G5 by team name
- No tiers within conferences: team-level parameters handle within-conference spread
- Three-level hierarchy: league → conference → team
- Early-season null handling: Approach A — impute with season-to-date prior
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
- Style/tempo analysis: in-game metrics only for diagnostic game-level signal tests
- EDA training population: 2022–2024 only. 2025 is holdout — excluded from all EDA signal tests, YoY stability calculations, and cluster fitting.
- raw.plays performance: never scan with IN clause on large game_id list or multiple INNER JOINs. Always materialize valid game_ids into a temp table with PRIMARY KEY first, then join raw.plays to temp table once.
- EDA 10 archetypes: valid primarily for totals, weak for spread, not valid for moneyline variance, not stable enough for prior seeding.
- game_script_avg_margin: diagnostic_only — post-game, near-tautological with
  point_differential (raw r=0.9075). Do not use as model input.
- game_script_ordinal: diagnostic_only — post-game, derived from in-game score
  margin (raw r=0.8628). Do not use as model input.
- close_game_play_count_delta: conference_specific_candidate for spread.
  Signal in ACC, American Athletic, Big 12, Mid-American, Pac-12, Sun Belt.
  Not valid for O/U (except Big 12), moneyline variance, or prior seeding.

---

## Artifacts Status
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 185 features keep=True (154 prior + 31 raw.plays Day 14) |
| artifacts/epa_feature_verdict.csv | ✅ valid | Day 8 — rerun on 2022–2024 clean data |
| artifacts/sp_recruiting_verdict.csv | ✅ valid | Day 9 — prior seed analysis only, correctly scoped |
| artifacts/hierarchy_verdict.json | ✅ valid | Day 10 — rerun on 2022–2024 clean data |
| artifacts/environment_verdict.csv | ✅ valid | Day 11 — rerun on 2022–2024 clean data |
| artifacts/momentum_verdict.csv | ✅ valid | Day 12 — rerun on 2022–2024 clean data |
| artifacts/elo_excitement_verdict.csv | ✅ valid | Day 13 — rerun on 2022–2024 clean data |
| artifacts/style_tempo_verdict.csv | ✅ valid | Day 15 rebuilt correctly from in-game team-game style metrics |
| artifacts/style_tempo_summary.json | ✅ valid | Day 15 rebuilt summary |
| artifacts/game_script_verdict.csv | ✅ valid | Day 17 — game script analysis |
| artifacts/evaluation_checklist.md | ✅ valid | Day 18 — 39-item pass/fail checklist for model_14_signoff.ipynb |
| artifacts/eda_12_completion.json  | ✅ valid | Day 18 — completion record |
| artifacts/master_verdict.csv | ✅ valid | Day 19 — 93 rows, 23 include, 70 exclude |
| artifacts/final_features.csv | ✅ valid | Day 19 — 23 included features with complete prior specs |
| artifacts/ambiguity_resolution.md | ✅ valid | Day 19 — 5 binding ambiguity resolutions |
| artifacts/prior_specification_draft.md | ✅ valid | Day 19 — full prior spec for all 23 features + hierarchy parameters |

---

## YoY Benchmarks
All values from clean 2022–2024 training data only.

- off_epa_per_play YoY r = 0.4331
- def_epa_per_play YoY r = 0.4224
- sp_rating YoY r = 0.7740 (avg of 2022→2023 r=0.7965 and 2023→2024 r=0.7514)
- sp_offense YoY r = 0.6060
- sp_defense YoY r = 0.6725
- away_elevation_delta_ft YoY r = 0.8255 — stable (anchor candidate)
- away_travel_distance_mi YoY r = 0.6562 — unstable (below anchor threshold)
- away_tz_delta_hrs YoY r = 0.6710 — unstable (below anchor threshold)
- pregame_elo YoY r = 0.8452 — strong (game-level predictor, not gating)
- recruiting_3yr_avg YoY r = 0.9779 — extremely stable (prior seed only)
- excitement_index YoY r = 0.1877 — extremely unstable (not usable as prior)
- rush_rate_std_downs YoY r = 0.4890 — weak prior-seed candidate only
- rush_rate_pass_downs YoY r = 0.4648 — weak prior-seed candidate only
- offense archetype YoY retention:
  - 2022→2023 = 0.3548
  - 2023→2024 = 0.2636
  - unstable, not a prior seed
- defense archetype YoY retention:
  - 2022→2023 = 0.3952
  - 2023→2024 = 0.2481
  - unstable, not a prior seed

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
- game_script and game_script_avg_margin exist in int_game_team_features
- close_game_play_count and close_game_def_play_count exist in int_game_team_features
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
- raw.games home_team and away_team match int_team_season_features team_name for
  FBS teams — use this join for identifying home/away sides in matchup construction
- CRITICAL JOIN PATTERN: conference and sp_rating come from int_team_season_features
  joined on team_name + season. Always join through int_game_team_features team_name
  as the bridge — never join team name columns directly from raw.games unless
  specifically constructing the valid game pool and joining home/away to
  int_team_season_features by team_name + season.
- CRITICAL PERFORMANCE: never scan raw.plays with WHERE game_id IN (large list) or
  multiple INNER JOINs on large tables. Create temp table of valid game_ids with
  PRIMARY KEY, then join raw.plays to temp table once.

---

## Source Tables
- int.int_game_team_features — game-level team performance including pregame_elo,
  excitement_index, game_script, game_script_avg_margin, close_game_play_count,
  close_game_def_play_count
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context
- int.int_team_season_features — season-level team features, FBS only, includes
  conference and sp_rating (authoritative source for both)
- stg.stg_game_weather — kickoff_hour available here, not yet in int layer
- raw.games — game-level home/away points, teams, conference_game flag, ELO fields
- raw.plays — play-level table for in-game style and derived play-by-play features
- raw.odds — 2026 season only, live validation target only

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
2. Never take shortcuts or lazy solutions. If a query fails, read the actual schema
   before rewriting. If data is wrong, diagnose the actual cause before fixing.
   Never patch inline — rewrite the entire cell. Never guess column names. Never
   assume a filter handles exclusions it was not designed to handle.
3. Read artifacts/candidate_features.csv — only keep=True columns are authorized
4. Run schema introspection query before writing any SQL — never guess column names
5. Write complete cells only — never partial fixes or incremental edits
6. Use existing helpers — never redefine logic that already exists in the notebook
7. Cast all Decimal columns to float64 immediately after loading
8. Cast boolean columns using `.map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)`
9. FBS conference games only, no exceptions. Every game-level query must filter both
   teams through int_team_season_features with conference != 'FBS Independents'.
   conference_game = TRUE alone does not exclude Independents. After loading, assert
   zero nulls on all controls — any null means a non-FBS team leaked through. Print
   conference distribution and assert FBS Independents does not appear.
10. Do not rewrite verified cells
11. Do not close the DB connection until the notebook is complete
12. If a required column is not in the schema output, stop and say so — do not proceed
13. Use the canonical assign_tier function — do not modify it
14. Never use nbformat, papermill, or any script to generate notebook files
15. Every verdict must report spread signal, over/under signal, and moneyline signal
    separately — never collapse into a single verdict
16. Conference stratification is mandatory for every partial r test — full population,
    P4, G5, and each individual conference. Never issue a verdict from global analysis only.
17. Season filter mandatory: every query must include AND season IN (2022, 2023, 2024).
    2025 is the holdout year and must never appear in training data queries.
18. Prior seeds vs game-level predictors: SP+ and recruiting are prior seeds — never
    test them against specific game outcomes. Style metrics, EPA, ELO, momentum
    features, environmental features, and game script features are game-level predictors
    — test them against specific game outcomes using partial r framework.
19. raw.plays performance: always materialize valid game_ids into a temp table with
    PRIMARY KEY before querying raw.plays. Never use IN clause with large lists.
20. Do not promote in-game diagnostic features directly to the production pregame
    model without first testing a deployable pregame version.

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
Report this back to me verbatim after answering the confirmation gate questions
then tell me exactly what that means:

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