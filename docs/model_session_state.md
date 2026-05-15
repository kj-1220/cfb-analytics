Always select kernel "CFB Model (ARM)" when opening any notebook in this
project. Do not use any other kernel.

---

## What This Project Is

A production AI-powered college football analytics and betting research
platform. The Bayesian model predicts score distributions for each team in
a game. From those distributions the platform derives win probability,
predicted spread, and predicted moneyline. Claude acts as a reasoning layer
over those outputs — it never predicts on its own, it reasons over what the
model produced.

Hard deadline: September 24, 2026 — first Saturday of Sun Belt conference
play. This is not the start of the season. It is the start of conference
games. Target matchup: Liberty vs Coastal Carolina.

College basketball parallel track: January 3, 2027.

The model is one component of a larger system: Postgres data layer, dbt
silver/gold layer, FastAPI backend, RAG corpus, React frontend with matchup
pages, conference dashboards, and an AI analyst chat panel. The model build
phase (this document) must be complete before gold layer work begins.

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
- NEVER use create_file to produce a .ipynb file
- NEVER batch all cells into a single response — write one cell at a time
- If a cell produces an error, rewrite the ENTIRE cell — never patch inline
- Do not proceed to the next cell until the current one has been confirmed

---

## What Comes Next

Next notebook: model_08_refit_and_posterior_checks.ipynb (Day 26)

model_08 is a combined refit and full posterior check in a single notebook.
The refit uses corrected priors identified from model_07 findings. All
posterior checks must pass in the same notebook before evaluation begins.

Before writing any code, request these two notebooks from the user:
  model_06_full_fit.ipynb
  model_07_posterior_checks.ipynb

Do not write a single cell until both are attached and read. The model
definition in model_08 Cell 2 must be copied verbatim from model_06 Cell 2
with only the three prior changes below. Do not reconstruct from memory.

Three priors changed from model_06 (change nothing else):
  r_negbinom   : Gamma(16.0, 2.0) -> Gamma(4.0, 0.5)  [mean=8, std=4]
  sigma_attack : HalfNormal(0.1)  -> HalfNormal(0.25)
  sigma_defense: HalfNormal(0.1)  -> HalfNormal(0.25)

Rationale:
  r_negbinom: model_07 showed all 10 conferences flagged on VMR check.
  Posterior means 12-18 imply VMR 2.3-3.0; observed VMR 4.8-7.2. Prior
  Gamma(16,2) too narrow — resisting low-r values data prefers (~5-8).
  sigma_attack/defense: 95/131 teams outside +-2 pt mean threshold.
  Posterior means 0.018/0.061 too small — team effects compressed toward
  league mean. Elite teams under-predicted, weak teams over-predicted.

Required checks in model_08 (all must pass before closing notebook):
  R-hat < 1.01 for all parameters
  ESS_bulk >= 400, ESS_tail >= 400 for all parameters
  0 divergences
  BFMI > 0.3 for all chains
  Posterior predictive VMR: observed VMR inside 90% CI per conference
  Team-level mean: predicted within +-2 pts of observed per team
  Conference-level mean: predicted within +-3 pts of observed

BFMI requires capturing energy at fit time. Add to MCMC.run():
  extra_fields=('energy',)
And save in pkl:
  artifact['energy'] = mcmc.get_extra_fields()['energy']
model_06 did not capture energy — BFMI was not computable from that pkl.
model_08 must not repeat this.

Save samples to: artifacts/model_08_samples.pkl

After model_08, the next notebook is model_09_holdout_evaluation.ipynb.

## Day 25 — What Was Completed

model_06_full_fit.ipynb — complete (8 cells, all run and verified):
  Full 4-chain fit: 4 chains, 1000 warmup, 1000 samples. 0 divergences.
  Wall-clock: 648.6s. Acceptance probs: 0.93 / 0.90 / 0.92 / 0.91.
  All convergence thresholds passed:
    R-hat < 1.01: PASS all parameters
    ESS_bulk >= 400: PASS all parameters (lowest: sigma_attack 1092)
    ESS_tail >= 400: PASS all parameters
    Team-level max R-hat: alpha_team_raw 1.0065, delta_team_raw 1.0063,
    hfa_team_raw 1.0040 — all PASS
  Key posterior means:
    mu_league: 3.1935  hfa_league: 0.0294  sp_weight: 0.0637
    sigma_attack: 0.0182  sigma_defense: 0.0610
    r_negbinom: ACC/SEC 17.5-17.8, Big Ten/CUSA 11.9-12.1
    b_close_game_epa: 0.347 (dominant, HDI excludes zero)
    b_pregame_elo: 0.002 (weak, HDI includes zero)
    rec_weight_sunbelt: -0.048 (constraint active)
  NOTE: energy not captured in pkl — BFMI not computable from model_06
  samples. Action item: model_08 must use extra_fields=('energy',) and
  save energy array in pkl.
  Artifact saved: artifacts/model_06_samples.pkl (78.7 MB)
  Misplaced artifacts moved from notebooks/Model/artifacts to artifacts/

model_07_posterior_checks.ipynb — complete (9 cells, all run and verified):
  R-hat, ESS, trace plots confirmed passing (recomputed from pkl).
  Chain mixing excellent — spread across chains < 0.002 for all watch params.
  BFMI not recoverable from pkl — documented with surrogate evidence.
  Divergences: 0 / 4000 confirmed from sample_stats.

  TWO STRUCTURAL FINDINGS requiring refit (model_08):

  Finding 1 — VMR gap (all 10 conferences flagged):
    Observed VMR: 4.8–7.2 per conference
    Posterior predictive VMR 90% CI: 2.1–4.0
    Implied VMR from NegBin2(mu, r) at posterior means: 2.3–3.0
    Root cause: r_negbinom Gamma(16,2) prior too narrow; posterior means
    12–18 are too high; data prefers r ≈ 5–8 to match observed variance.
    Fix: r_negbinom prior Gamma(16.0, 2.0) -> Gamma(4.0, 0.5) [mean=8, std=4]

  Finding 2 — team-level mean compression (95/131 teams flagged):
    95 of 131 teams outside +-2 pt posterior predictive mean threshold.
    Pattern: elite teams under-predicted (Oregon -15, Ohio State -12,
    Georgia -12), weak teams over-predicted (Kent State +6.7,
    Northwestern +5.6, Michigan State +5.7).
    Root cause: sigma_attack=0.018, sigma_defense=0.061 too small;
    team random effects compressed toward league mean.
    Conference-level: Big 12 -4.88, Pac-12 -5.91, SEC -4.15 all flagged.
    Fix: sigma_attack and sigma_defense HalfNormal(0.1) -> HalfNormal(0.25)

  Decision: model_08 is a combined refit + posterior check. All three
  prior changes applied simultaneously. model_08 must pass all model_07
  checks before evaluation notebooks proceed. Everything after model_07
  shifts down one day.

## Day 24 — What Was Completed

model_03 Cell 7 rewrite — root cause of prior predictive explosions:
  Sparse threshold-activated features were not winsorized before scaling.
  days_since_last_game reached +19.75 sigma. off_sack_rate_allowed_delta
  reached ±6.84 sigma (Navy vs UCF 2022). These caused prior predictive
  score explosions — median correct at 27 pts but mean at 3.3M.
  Fixes applied in Cell 7:
    days_since_last_game    : winsorized at 21 days before scaling
    away_travel_distance_mi : winsorized at 5000 mi before scaling
    away_elevation_delta_ft : winsorized at 7000 ft before scaling
    all continuous features : clipped to [-3, 3] after standardization
    scaler_stats.json       : std_nonzero key renamed to std
  Cell 8: execute_values(page_size=500) replacing executemany.
    Before Cell 8: terminate idle-in-transaction sessions on
    int_game_model_features via pg_stat_activity.
  Cell 9 validation: 3,214 rows, 31 columns, all checks passed.

model_04 re-run on corrected data (diagnostic only — 1 chain, 200
warmup, 200 samples). All priors corrected before re-run (see locked
decisions below). Results:
  0 divergences, acceptance 0.94, wall-clock 64.4s
  r_negbinom posterior means: ACC/SEC ~17–18, Big Ten/CUSA ~12
  sigma_attack posterior mean: 0.019 — low; watch in full 4-chain run
  hfa_league posterior mean: 0.030 — below prior center 0.1; watch
  b_off_archetype shape: (200, 4) ✓  b_def_archetype shape: (200, 4) ✓
  Full 4-chain run still pending — must complete before model_06.

model_05_prior_predictive_checks.ipynb — all 5 cells complete and
verified (plot saved and confirmed):
  90.4% within 0–70 pts — PASS (threshold recalibrated to 90%)
  VMR deferred to model_06
  Median score: 26 pts; overall mean: 40.48 pts; P99: 194 pts
  Per-sample mean range: 13.6–285.8 pts
  2/500 samples with per-sample mean > 200 — valid hierarchical behavior
  r_negbinom prior draws: mean ~7.9–8.1 per conference (matches prior)
  Plot saved: artifacts/model_05_prior_predictive.png

RAG outlier flagging decision (locked):
  Flag predictions where any of the following are true:
    - Team's off_archetype_idx is in cluster 3 (n=83, sparse)
    - Team's def_archetype_idx is in cluster 1 (n=505, sparse)
    - Any input feature hit a winsorization cap at prediction time
    - sigma_attack * alpha_team_raw for either team exceeds 2 sigma
      from the training distribution
  Navy and option-offense teams are primary candidates.
  Do not exclude these teams from training or prediction.

Pending at end of Day 24:
  model_06_full_fit.ipynb (num_warmup=1000, num_samples=1000, num_chains=4)
  -- save samples to artifacts/model_06_samples.pkl
  model_07_posterior_checks.ipynb -- not built

## Day 23 — What Was Completed
- model_04_first_fit.ipynb audited and corrected — 6 cells:
  - Cell 1: imports, environment verification, DB connection
  - Cell 2: conference index maps, GameData dataclass, model_cfb() —
    corrected: r_negbinom Gamma(2.0, 0.1) vector x N_CONFERENCES,
    archetype embeddings (4-vector), compound matchup fields removed,
    non-centered team parameterization
  - Cell 3: load training data from int.int_game_model_features
  - Cell 4: build index arrays and conference masks
  - Cell 5: construct GameData — corrected: no re-standardization
    (data already scaled by model_03), archetype fields as int32
  - Cell 6: NUTS diagnostic run — corrected: r_negbinom init as vector,
    archetype init as 4-vector zeros
- Three diagnostic scratch cells removed (written to debug divergences
  in earlier broken state — root causes now fixed)
- Diagnostic run results: 0 divergences, acceptance prob=0.94,
  wall-clock 99.2s, 255 leapfrog steps
- r_negbinom posterior means confirmed differentiated by conference:
  ACC/SEC ~29, Big Ten/CUSA ~14–15 — validates conference-specific
  dispersion structure
- Items to watch in full 4-chain run: sigma_attack low (0.029),
  hfa_league lower than prior center (0.029 vs 0.1)

## Day 22 — What Was Completed
- model_03_feature_engineering.ipynb audited and corrected — 9 cells:
  - Cell 6: KMeans archetypes corrected — compound matchup string columns
    removed; now produces off_archetype_idx and def_archetype_idx (int32,
    0–3) per team per game; archetype_matchup_encodings.json eliminated
  - Cell 7: standardization pass added (continuous mean=0 std=1; sparse
    divide by non-zero std only; elo_sp_divergence passthrough);
    elo_sp_divergence computed using locked EDA 08 parameters
    (elo mean=1511.6097 std=236.1207; sp mean=1.0969 std=12.8712);
    scaler_stats.json written
  - Cell 8: table schema corrected — off_archetype_idx and def_archetype_idx
    SMALLINT replacing four compound matchup SMALLINT columns
  - Cell 9: validation updated — archetype range checks, compound column
    absence check
- Key facts confirmed: 3,214 rows, 131 teams, 1,607 games, 31 columns,
  all checks passed, elo_sp_divergence mean=-0.0001 std=0.449

## Day 21 — What Was Completed (audit corrections applied)
- model_02_architecture.ipynb audited and corrected:
  - Cell 4: GameData dataclass corrected — off_archetype_idx and
    def_archetype_idx (int32) replacing four float compound matchup fields
  - Cell 5: model_cfb() corrected — r_negbinom Gamma(2.0, 0.1) vector x
    N_CONFERENCES; b_off_archetype and b_def_archetype as 4-vector
    embeddings; compound matchup scalars removed; likelihood uses
    r_negbinom[data.conf_idx]
  - Cell 6: structural verification updated — int32 archetype index arrays,
    r_negbinom shape assertion (5, 10), archetype shape assertions (5, 4),
    stale parameter name check
  - All assertions passed: 0 divergences, correct shapes throughout
- Original session: log-scale prior corrections applied to model_01 and
  model_02 (mu_league, hfa_league, sigma_hfa_team)

## Day 20 — What Was Completed (audit corrections applied)
- model_01_prior_specification.ipynb audited and corrected:
  - Cell 2: r_negbinom HalfNormal(5.0) scalar → Gamma(2.0, 0.1) x
    N_CONFERENCES vector
  - Cell 4: sp_weight YoY r corrected 0.7740→0.7632; HFA SD corrected
    4.85→4.81; SP+ dual-role (prior seed + game-level predictor,
    partial r=0.197) documented
  - Cell 5: elo_sp_divergence comment corrected r=+0.1650→r=-0.1150
    (negative direction, z-score version); archetype scalars and compound
    matchup columns replaced with b_off_archetype and b_def_archetype
    sample_shape=(4,)
  - Cell 6: assembly cell corrected to match all above fixes; prior
    predictive verified: 34 parameters, r_negbinom shape (1,10),
    b_off_archetype shape (1,4), Sun Belt=-0.3398
  - Markdown summary updated: corrected intercept example, dispersion
    section, archetype encoding contract, day references

---

## Model Build Phase — Days 20–34

| Day | Notebook | Status | Goal |
|---|---|---|---|
| 20 | model_01_prior_specification.ipynb | ✅ complete | Translate every entry in prior_specification_draft.md into NumPyro prior distributions. No fitting. Every numpyro.sample() call cites its EDA justification. |
| 21 | model_02_architecture.ipynb | ✅ complete | Write hierarchical NegBinom model structure in NumPyro. No fitting. Three levels: league → conference → team. Document every design decision. |
| 22 | model_03_feature_engineering.ipynb | ✅ complete | Engineer all features not persisted after EDA. Write to int.int_game_model_features. All null handling, threshold-zeroing, and standardization applied here. |
| 23 | model_04_first_fit_diagnostic.ipynb | ✅ complete (Day 23/24) | Diagnostic run only: 1 chain, 200 warmup, 200 samples. Confirms model geometry is healthy before full fit. 0 divergences, acceptance 0.94. |
| 24 | model_05_prior_predictive_checks.ipynb | ✅ complete (Day 24) | Sample before seeing data. 90.4% within 0–70 pts [PASS]. VMR deferred to model_07. Plot saved: artifacts/model_05_prior_predictive.png. |
| 25 | model_06_full_fit.ipynb | ✅ complete (Day 25) | Full 4-chain fit. 0 divergences, all R-hat/ESS thresholds passed. Samples: artifacts/model_06_samples.pkl. |
| 25 | model_07_posterior_checks.ipynb | ✅ complete (Day 25) | Posterior checks on model_06 samples. All convergence checks passed. Two structural findings: VMR gap and team-level mean compression. Refit required — see model_08. |
| 26 | model_08_refit_and_posterior_checks.ipynb | ❌ not built — this is next | Refit with corrected priors (r_negbinom Gamma(4,0.5), sigma_attack/defense HalfNormal(0.25)) plus full posterior check suite. Both refit and checks must pass in this notebook. Save to artifacts/model_08_samples.pkl. |
| 27 | model_09_holdout_evaluation.ipynb | ❌ not built (blocked on model_08) | First look at 2025 holdout. Overall Brier score, calibration curve. Baseline before subgroup breakouts. |
| 28 | model_10_evaluation_by_conference_tier.ipynb | ❌ not built | Brier score and calibration by P4, G5, Independents. |
| 29 | model_11_evaluation_by_game_type.ipynb | ❌ not built | Rivalry games, cross-tier matchups, neutral site games. Quantify how model handles upsets. |
| 30 | model_12_evaluation_season_progression.ipynb | ❌ not built | Does calibration improve as season progresses? Conf game 1 vs conf game 8. |
| 31 | model_13_home_away_spread_accuracy.ipynb | ❌ not built | Home field advantage calibration. Spread accuracy by expected margin. |
| 32 | model_14_year_over_year_stability.ipynb | ❌ not built | Do 2023 model ratings predict 2024 performance? |
| 33 | model_15_refinement.ipynb | ❌ not built | Adjust based on evaluation findings. May require revisiting priors, hierarchy, or dropping features. |
| 34 | model_16_stress_testing.ipynb | ❌ not built | Edge cases: extreme weather, maximum travel, large timezone deltas, thin-data teams. |
| 35 | model_17_signoff.ipynb | ❌ not built | Work through evaluation_checklist.md item by item. Model not signed off until every item addressed. |

Gold layer begins Day 36.

---

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team
- Likelihood: Negative Binomial 2
- Model form: points ~ NegBinom2(mu, r), log(mu) = team_attack +
  opponent_defense + home_advantage + environmental_adjusters +
  game_level_features
- Dispersion parameter r: VECTOR of length N_CONFERENCES, prior
  Gamma(16.0, 2.0) per conference independently (mean=8, std=2). EDA 05
  confirmed conference-specific dispersion (Bartlett p=0.000470, Levene
  p=0.000705). Scalar r caused sampler collapse — do not revert to scalar.
  Gamma(2.0, 0.1) also caused sampler collapse — do not revert.
  Likelihood: r_negbinom[data.conf_idx] selects per-game dispersion.
- Priors seeded from: sp_rating (team level, ALSO game-level spread
  predictor partial r=0.197), recruiting_3yr_avg (team level only)
- pregame_elo: game-level predictor only, not a prior seed
- Conference-level pooling provides regularization (ICC marginal 0.02–0.05
  but pooling still improves small-sample estimates)
- Built in NumPyro (replaces PyMC — see library decision below)
- Non-centered parameterization for alpha_team, delta_team, hfa_team:
  *_raw ~ Normal(0,1) sampled; * = *_raw * sigma deterministic

---

## Included Features — Final (23 total)
Source of truth: artifacts/final_features.csv
Prior specifications: artifacts/prior_specification_draft.md

### Anchors (3)
| Feature | Role | Spread | O/U | ML Var | Conference Scope | Threshold | Null Handling |
|---|---|---|---|---|---|---|---|
| close_game_epa_per_play | anchor | yes | yes | no | all | none | zero if null |
| close_game_def_epa_per_play | anchor | yes | yes | no | all | none | zero if null |
| away_elevation_delta_ft | anchor | yes | no | no | Mountain West, Big 12 | >=2000ft | zero |

### Prior Seeds (2) — team level, not game-level predictors
| Feature | YoY r | Conference Notes |
|---|---|---|
| sp_rating | 0.7632 | All conferences; DUAL ROLE — also game-level spread predictor (partial r=0.197 after EPA control, p<0.0001); does not decay monotonically through games 9-12 |
| recruiting_3yr_avg | 0.9779 | Moderate weight Big Ten and SEC; low elsewhere; **non-positive in Sun Belt** |

### Supporting — Game Level (10)
| Feature | Spread | O/U | ML Var | Conference Scope | Threshold | Null Handling |
|---|---|---|---|---|---|---|
| away_travel_distance_mi | yes | no | no | all | >=1500mi | zero |
| away_tz_delta_hrs | yes | no | no | all | abs>=2hr | zero |
| wind_chill | no | yes | no | all | <=40F, not dome | zero |
| pregame_elo | yes | no | no | all | none | not_applicable |
| elo_sp_divergence | yes | no | no | all | none | not_applicable |
| last3_win_pct | yes | no | no | all | none | impute_season_prior |
| rush_rate_std_downs_delta | yes | no | no | all | none | not_applicable |
| rush_rate_pass_downs_delta | yes | no | no | all | none | not_applicable |
| off_sack_rate_allowed_delta | no | no | yes | all | none | not_applicable |
| def_sack_rate_delta | no | no | yes | all | none | not_applicable |

### Conference-Specific (8)
| Feature | Spread | O/U | Conference Scope | Null Handling |
|---|---|---|---|---|
| last3_off_epa_avg | yes | no | ACC, Mid-American, SEC | impute_season_prior |
| last3_def_epa_avg | yes | no | American Athletic, Big Ten, Conference USA, Mid-American, Pac-12, Sun Belt | impute_season_prior |
| last3_points_scored_avg | yes | no | ACC, Big 12, Big Ten, Conference USA, Mid-American, Mountain West | impute_season_prior |
| last3_points_allowed_avg | yes | no | American Athletic, Big Ten, Conference USA, Mountain West, Pac-12, Sun Belt | impute_season_prior |
| days_since_last_game | yes | no | American Athletic, Big 12 | zero |
| close_game_play_count_delta | yes | no | ACC, American Athletic, Big 12, Mid-American, Pac-12, Sun Belt | not_applicable |
| off_archetype_idx | yes | yes | all* | not_applicable |
| def_archetype_idx | yes | yes | all* | not_applicable |

*Archetype features require deployable pregame version before September 24, 2026
production launch. If no pregame version clears signal tests, drop these two
features at refinement.

**Archetype encoding:** `off_archetype_idx` and `def_archetype_idx` are integer
index arrays (int32, values 0–3) stored in `int.int_game_model_features`.
The model indexes into 4-vector embeddings:
`b_off_archetype[data.off_archetype_idx]` and
`b_def_archetype[data.def_archetype_idx]`.
No compound matchup string columns exist anywhere in the pipeline.

---

## Prior Specification Summary
Full specification in artifacts/prior_specification_draft.md.

| Parameter | Distribution | Notes |
|---|---|---|
| mu_league (intercept) | Normal(3.3, 0.2) | Log scale; exp(3.3) ≈ 27 pts |
| hfa_league | Normal(0.1, 0.05) | Log scale; ≈ 2.43 pts on 27 pt baseline |
| r_negbinom[c] | Gamma(4.0, 0.5) x N_CONFERENCES | Conference-specific vector; mean=8, std=4. Gamma(16,2) caused VMR gap — posterior means 12-18 too high; observed VMR 4.8-7.2 requires r ≈ 5-8. Changed Day 25. |
| mu_conference[c] | Normal(0.0, sigma_conference) x 10 | Centered; sigma_conference ~ HalfNormal(0.1) |
| alpha_team_raw[t] | Normal(0.0, 1.0) x N_teams | Non-centered; alpha_team = raw * sigma_attack |
| sigma_attack | HalfNormal(0.25) | HalfNormal(0.1) caused team-effect compression; 95/131 teams outside +-2 pt threshold. Changed Day 25. |
| delta_team_raw[t] | Normal(0.0, 1.0) x N_teams | Non-centered; delta_team = raw * sigma_defense |
| sigma_defense | HalfNormal(0.25) | Same rationale as sigma_attack. Changed Day 25. |
| hfa_team_raw[t] | Normal(0.0, 1.0) x N_teams | Non-centered; hfa_team = raw * sigma_hfa_team |
| sigma_hfa_team | HalfNormal(0.1) | Log scale |
| b_off_archetype | Normal(0.0, 0.15) x 4 | 4-vector embedding; indexed by off_archetype_idx |
| b_def_archetype | Normal(0.0, 0.15) x 4 | 4-vector embedding; indexed by def_archetype_idx |
| b_sp | Normal(0.0, 0.15) | Dual role: prior seed + game-level predictor |
| b_elo | Normal(0.0, 0.15) | |
| b_elo_sp_div | Normal(0.0, 0.15) | r=-0.1150 (negative direction); already z-scored |
| b_epa_off | Normal(0.0, 0.10) | Tighter — EPA features have stronger direct signal |
| b_epa_def | Normal(0.0, 0.10) | |
| b_elevation / b_travel / b_tz / b_wind | Normal(0.0, 0.15) | Environmental features |
| b_last3_win / b_rush_std / b_rush_pass | Normal(0.0, 0.15) | Momentum/style features |
| b_sack_off / b_sack_def | Normal(0.0, 0.15) | |
| b_conf_scoped (6-vector) | Normal(0.0, 0.15) | Conference-scoped features |
| rec_weight[c] | Normal(0.0, 0.5) x 9 | Non-Sun-Belt conferences |
| rec_weight[Sun Belt] | TruncatedNormal(0.0, 0.5, high=0.0) | Hard non-positive constraint |

**Hard constraint:** Sun Belt recruiting_3yr_avg coefficient must be non-positive.
Implementation: TruncatedNormal(0.0, 0.5, high=0.0).

---

## Feature Preprocessing (locked — applied in model_03, never repeated downstream)
- **Continuous features** (15): standardized to mean=0, std=1
- **Sparse threshold-activated features** (5 — elevation, travel, tz, wind_chill,
  days_since): divided by std of non-zero values only; no mean subtraction;
  zeros remain zero
- **elo_sp_divergence**: z-score difference using locked EDA 08 parameters:
  pregame_elo mean=1511.6097 std=236.1207; sp_rating mean=1.0969 std=12.8712.
  Not re-standardized.
- **is_home**: binary — no standardization
- **off_archetype_idx, def_archetype_idx**: categorical int32 — no standardization
- **Scaler stats**: saved to artifacts/scaler_stats.json by model_03 Cell 7.
  Do not rewrite in downstream notebooks.

---

## Evaluation Thresholds (from evaluation_checklist.md — Day 35 reference)
- R-hat < 1.01 for all parameters
- ESS_bulk >= 400 and ESS_tail >= 400 for all parameters
- Zero divergences post-warmup
- BFMI > 0.3 for all chains — requires extra_fields=('energy',) at fit
  time; not recoverable post-hoc; model_06 did not capture; model_08 must
- Prior predictive: 90% of samples within 0–70 points (recalibrated from
  95% on Day 24 — 131-team hierarchy produces legitimate tail scores);
  VMR threshold retired from prior predictive (replaced by posterior
  predictive VMR per conference in model_08)
- Posterior predictive VMR per conference: observed VMR must fall inside
  posterior predictive 90% CI per conference. All 10 conferences failed
  in model_07 — this is the primary driver of the model_08 refit.
- Posterior predictive mean within ±2 points of observed mean per team
- Conference-level posterior predictive mean within ±3 points of observed
- Overall Brier score must beat SP+-only baseline
- Win probability calibration within ±5pp per decile bucket (n >= 20)
- Spread MAE <= 14 points overall; no margin bucket exceeding 18 points
- Sub-season: conf game 1 Brier ≤ 0.26; conf games 5–8 Brier ≤ 0.23
- P4 Brier <= 0.23, G5 Brier <= 0.25
- All 10 conferences calibrated within ±8pp (n >= 10)
- Cross-tier mean P4 win probability vs G5 between 0.72 and 0.88
- Sun Belt recruiting prior weight must be non-positive

Full 39-item checklist: artifacts/evaluation_checklist.md

---

## Locked Decisions — Do Not Revisit
- Library: NumPyro (PyMC abandoned due to pytensor environment failure)
- pytensor: explicitly banned — do not install, import, or reference
- Likelihood: Negative Binomial 2
- Three-level hierarchy: league → conference → team
- Dispersion: conference-specific vector r_negbinom of length N_CONFERENCES,
  prior Gamma(4.0, 0.5) per conference independently (mean=8, std=4).
  Changed from Gamma(16.0, 2.0) on Day 25 — model_07 showed VMR gap:
  posterior means 12-18 implied VMR 2.3-3.0; observed VMR 4.8-7.2.
  Do not revert to scalar. Do not revert to Gamma(2.0, 0.1) or
  Gamma(16.0, 2.0) — all caused sampler collapse or VMR failure.
- sigma_attack: HalfNormal(0.25) — changed from HalfNormal(0.1) on Day 25.
  model_07 showed 95/131 teams outside +-2 pt threshold; team effects
  compressed toward league mean. Do not revert to HalfNormal(0.1).
- sigma_defense: HalfNormal(0.25) — same rationale as sigma_attack.
  Do not revert to HalfNormal(0.1).
- sigma_conference: HalfNormal(0.1) — HalfNormal(3.0) caused exp(6)≈400x
  log-scale multipliers in prior predictive; do not revert
- All game-level coefficients: Normal(0, 0.15); b_epa_off and b_epa_def:
  Normal(0, 0.10); original widths (0.2–0.5) contributed to log_mu explosions
- Winsorization caps (applied in model_03 Cell 7 only — never repeat
  downstream, but must apply at prediction time):
    days_since_last_game    : cap at 21 days before scaling
    away_travel_distance_mi : cap at 5000 mi before scaling
    away_elevation_delta_ft : cap at 7000 ft before scaling
    all continuous features : clipped to [-3, 3] after standardization
- Prior predictive score threshold: 90% within 0–70 (recalibrated from 95%
  on Day 24 — 131-team hierarchy produces legitimate tail scores)
- Prior predictive VMR threshold: retired — evaluated as posterior predictive
  VMR per conference in model_06 instead
- DB bulk insert: always execute_values(page_size=500); never executemany.
  Before Cell 8: check pg_stat_activity for idle-in-transaction sessions
  on int_game_model_features and terminate them.
- RAG outlier flagging: flag predictions where team's off_archetype_idx is
  in cluster 3 (n=83), def_archetype_idx is in cluster 1 (n=505), any input
  feature hit a winsorization cap at prediction time, or sigma_attack *
  alpha_team_raw for either team exceeds 2 sigma from training distribution
- HFA: league-level baseline + team-level deviations; no conference-level HFA layer
- SP+ dual role: prior seed AND game-level spread predictor (partial r=0.197
  after EPA control, p<0.0001, all conferences); does not decay monotonically
  through games 9-12 (r=0.2609); do not treat as prior-only
- SP+ YoY r: 0.7632 (corrected from 0.7740)
- SP+ components (sp_offense, sp_defense): excluded — DATA LEAKAGE
  (end-of-season values, not collinearity)
- recruiting_3yr_avg: prior seed only — never a game-level predictor; YoY r=0.9779
- Sun Belt recruiting weight: non-positive (hard constraint); TruncatedNormal(high=0)
- elo_sp_divergence: r=-0.1150 (NEGATIVE direction, z-score version, EDA 08
  corrected). Pre-fix value r=+0.1650 is wrong — do not reference it.
  Prior Normal(0, 0.2) is correct. Already z-scored — do not re-standardize.
- Early-season null handling: Approach A — impute with season-to-date prior
- ELO/SP+ divergence: computed in model_03 using locked EDA 08 parameters;
  not recomputed downstream
- Archetype encoding: off_archetype_idx and def_archetype_idx (int32, 0–3).
  Embedded as b_off_archetype[off_archetype_idx] and
  b_def_archetype[def_archetype_idx]. sample_shape=(4,) for both.
  No compound matchup string columns anywhere in the pipeline.
  archetype_matchup_encodings.json does not exist — do not reference it.
- Archetype features: deployable pregame version required before 2026-09-24
  production launch; drop at refinement if not available
- rush_rate_std_downs_delta, rush_rate_pass_downs_delta: game-level predictors
  only; not prior seeds
- Environmental features: threshold-activated, modeled as indicator×magnitude;
  not linear. Pre-zeroed in model_03.
- opp_sp_rating_at_game_time: control variable only; not a model feature
- Portal and NIL: deprioritized; revisit only if model underperforms
- raw.odds: 2026 season only — no historical closing lines; live validation target only
- Pac-12 in dataset: G5 for all seasons (remnant conference after realignment)
- Notre Dame: Power Four — route by team name not conference label
- UConn: Group of Five — route by team name not conference label
- FBS Independents: not a pooling group; excluded from all training data
- No tiers within conferences: team-level parameters handle within-conference spread
- Conference assignment: historically accurate by season from game records
- 2025 is holdout — excluded from all training queries; season IN (2022, 2023, 2024)
- Training data: 2022–2024 only
- mu_league: Normal(3.3, 0.2) — log scale; exp(3.3) ≈ 27 pts
- hfa_league: Normal(0.1, 0.05) — log scale; ≈ 2.43 pts on 27 pt baseline
- sigma_hfa_team: HalfNormal(0.1) — log scale; team HFA SD = 4.81 pts
- model_cfb() accepts GameData dataclass; N_teams passed at call time
- Conference-scope masking: build_conf_mask() builds binary float32 mask before
  model_cfb() is called; one coefficient per scoped feature; masking handles
  zeroing — no separate priors per conference
- close_game_epa_per_play / close_game_def_epa_per_play: null means no close-game
  situations occurred — treated as zero; applied in model_03
- Archetype KMeans: refit on every run of model_03 (offense k=4, defense k=4,
  random_state=42); produces off_archetype_idx and def_archetype_idx (int32, 0–3);
  label maps in artifacts/archetype_label_maps.json (auditability only)
- All null handling, threshold-zeroing, and standardization applied in model_03 —
  do not repeat in downstream notebooks
- scikit-learn installed in cfb_model_arm via:
  ~/miniforge3/bin/conda install -n cfb_model_arm scikit-learn -y
- Non-centered parameterization for team effects: *_raw ~ Normal(0,1) sampled;
  * = *_raw * sigma deterministic. Separates sigma geometry from team-effect
  geometry for NUTS.

---

## Known Schema Facts — Use Exactly
- point_differential: derive as points_scored - points_allowed
- total_points: derive as points_scored + points_allowed
- conference does NOT exist in int_game_team_features — join to
  int_team_season_features on team_name and season
- is_home does NOT exist in int_game_team_features — derive as
  CASE WHEN f.team_name = g.home_team THEN 1 ELSE 0 END via join to raw.games
  on game_id and season
- int_game_environment has home_team and away_team, not team_name — join on
  game_id only, then expand to two team rows
- All numeric columns from psycopg2 return as Decimal — cast entire numeric
  column list to float64 immediately
- Boolean columns (is_dome, is_high_wind, is_precipitation) — use
  .map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)
- opp_sp_rating_at_game_time exists in int_game_team_features
- pregame_elo, opponent_pregame_elo, postgame_elo, excitement_index exist in
  int_game_team_features
- game_script, game_script_avg_margin exist in int_game_team_features
- close_game_play_count, close_game_def_play_count exist in int_game_team_features
- int_game_team_features granularity: two rows per game (one per team)
- sp_rating and conference: authoritative source is int_team_season_features
- raw.games opponent column in int_game_team_features is named 'opponent'
  (not 'opponent_name')
- raw.plays scrimmage play types for rush: 'Rush', 'Rushing Touchdown'
- raw.plays scrimmage play types for pass: 'Pass Reception', 'Pass Incompletion',
  'Passing Touchdown', 'Sack', 'Pass Completion', 'Pass Interception Return'
- raw.plays yards_to_goal: 0–100 scale; red zone = yards_to_goal <= 10
- raw.plays std_downs: down=1, OR (down=2 AND distance<=8), OR (down IN (3,4)
  AND distance<=5)
- raw.plays pass_downs: (down=2 AND distance>8) OR (down IN (3,4) AND distance>5)
- CRITICAL PERFORMANCE: never scan raw.plays with WHERE game_id IN (large list)
  or multiple INNER JOINs. Materialize valid game_ids into temp table with
  PRIMARY KEY first, then join raw.plays once.
- int.int_game_model_features: one row per team per game, 31 columns, primary
  key (game_id, team_name); all features fully preprocessed (standardized,
  threshold-zeroed, null-handled); do not re-standardize when loading

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

---

## Source Tables
- int.int_game_team_features — game-level team performance
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context
- int.int_team_season_features — season-level features; authoritative source
  for conference and sp_rating
- int.int_game_model_features — one row per team per game; all engineered model
  features for seasons 2022–2024; rebuilt by running
  model_03_feature_engineering.ipynb; primary key (game_id, team_name);
  31 columns; fully preprocessed — do not re-standardize when loading
- stg.stg_game_weather — kickoff_hour (not yet promoted to int layer)
- raw.games — home/away points, teams, conference_game flag, ELO fields;
  authoritative source for is_home
- raw.plays — play-level table for in-game derived features
- raw.odds — 2026 season only; live validation target only

---

## Artifacts — Active Reference Files
| File | Notes |
|---|---|
| artifacts/final_features.csv | 23 included features with complete prior specs — authoritative feature list for model build |
| artifacts/master_verdict.csv | 93 rows — full EDA verdict record |
| artifacts/prior_specification_draft.md | Day 20 input — translate into NumPyro code |
| artifacts/evaluation_checklist.md | 39-item pass/fail checklist — Day 34 works through this |
| artifacts/ambiguity_resolution.md | 5 binding ambiguity decisions |
| artifacts/candidate_features.csv | 185 keep=True features — reference only |
| artifacts/archetype_label_maps.json | KMeans archetype label maps (offense k=4, defense k=4) — written by model_03; auditability only, not used by model |
| artifacts/scaler_stats.json | Mean and std for all 21 scaled features — written by model_03 Cell 7; required for prediction-time scaling; do not rewrite in downstream notebooks |
| artifacts/model_05_prior_predictive.png | Prior predictive check plots — written by model_05 Cell 5 (Day 24) |
| artifacts/model_06_samples.pkl | Full 4-chain posterior samples from model_06 (Day 25) — 78.7 MB. NOTE: energy not captured; BFMI not computable from this file. |
| artifacts/model_07_trace_plots.png | Trace plots for sigma_attack, hfa_league, mu_league, r_negbinom[0,8] — written by model_07 Cell 3 (Day 25) |
| artifacts/model_08_samples.pkl | Refit posterior samples — PENDING (written by model_08; must include energy array for BFMI) |

Note: artifacts/archetype_matchup_encodings.json no longer exists —
compound matchup encoding was eliminated in the audit. Do not reference it.

---

## Rules Every Session Must Follow
1. Read this file before touching anything else
2. Never take shortcuts. If a query fails, read the actual schema before
   rewriting. Never patch inline — rewrite the entire cell. Never guess
   column names.
3. Write complete cells only — never partial fixes or incremental edits
4. Use existing helpers — never redefine logic that already exists in the notebook
5. Cast all Decimal columns to float64 immediately after loading
6. Cast boolean columns using
   `.map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)`
7. FBS conference games only, no exceptions. Both teams must join to
   int_team_season_features with conference != 'FBS Independents'.
   conference_game = TRUE alone does not exclude Independents.
   Print conference distribution after every game load and assert
   FBS Independents does not appear.
8. Do not rewrite verified cells
9. Do not close the DB connection until the notebook is complete
10. If a required column is not in the schema output, stop and say so
11. Use the canonical assign_tier function — do not modify it
12. Season filter mandatory: every query must include
    AND season IN (2022, 2023, 2024). 2025 is holdout.
13. Never call numpyro.infer.MCMC.run() in Day 20 — prior specification only
14. Every prior in Day 20 must cite its entry in prior_specification_draft.md
15. If a required file is not available (notebook, artifact, schema output,
    or any local project file), stop and ask the user to provide it — do not
    attempt to reconstruct it from memory or build a generic version.
16. Do not re-standardize features loaded from int.int_game_model_features —
    all preprocessing was applied in model_03. Do not rewrite scaler_stats.json.
17. r_negbinom is always a vector of length N_CONFERENCES. Never sample it as
    a scalar. Never initialize it as a scalar in init_to_value.
18. Archetype fields are always int32 index arrays (values 0–3). Never treat
    them as continuous float features. Never use compound matchup string columns.

---

## FBS Integrity Check — Mandatory After Every Game Load
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
2. Move completed notebooks to ✅ in the model build table
3. Add any new locked decisions
4. Add key findings from the session
5. Rewrite the confirmation gate to reflect what the next session must understand
6. Commit: git add docs/model_session_state.md && git commit -m "docs: update model session state after Day X" && git push