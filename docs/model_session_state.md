Always select kernel "CFB Model (ARM)" when opening any notebook in this
project. Do not use any other kernel.

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

## ⚠️ CRITICAL — Confirmation Gate
Rewritten each session to reflect what the next notebook must understand.

**Next notebook: Day 23 — First Fit**

Answer these questions in your own words before writing any code:

**Question 1:** Day 23 loads training data from `int.int_game_model_features`.
What is the granularity of that table? What join is required to get opponent
index arrays, and what season filter must be applied? Why is 2025 excluded?

**Question 2:** `model_cfb()` requires `team_idx`, `opp_idx`, and `conf_idx` as
integer arrays. Describe exactly how these are built from the training DataFrame —
what uniqueness key is used for teams, what lookup table maps strings to integers,
and what must be true about the index ranges relative to `N_teams` and
`N_CONFERENCES`.

**Question 3:** `int.int_game_model_features` was written by
`model_03_feature_engineering.ipynb` with all null handling and threshold-zeroing
already applied. What null handling must NOT be repeated in Day 23? What does
Day 23 still need to build that is not in the feature table (index arrays,
conference masks, GameData)?

---

## Day 22 — What Was Completed
- Confirmation gate answered correctly before any code was attempted
- Discovered that several features from final_features.csv were never persisted
  to the database after EDA — computed in-memory only in EDA 06, 09, 10
- Decision made: dedicate a full notebook to feature engineering before first fit
- model_03_first_fit.ipynb renamed to model_04_first_fit.ipynb; all subsequent
  notebooks shift down one day
- model_03_feature_engineering.ipynb built and completed — 10 cells:
  - Cell 1: imports, environment verification, DB connection
    (scikit-learn installed via conda into cfb_model_arm)
  - Cell 2: valid FBS game pool temp table (1,607 games, seasons 2022–2024)
  - Cell 3: close_game_play_count_delta from existing int_game_team_features cols
  - Cell 4: wind_chill (NWS formula) + environmental cols from int_game_environment;
    expanded to two team rows per game
  - Cell 5: rush/sack rate deltas from raw.plays aggregation (1.73s); home minus away
  - Cell 6: KMeans archetypes (offense k=4, defense k=4, random_state=42);
    integer-encoded; label maps and encodings saved to artifacts/
  - Cell 7: full assembly — base features + 4 merge sets + elo_sp_divergence +
    Approach A imputation + threshold-zeroing; 3,214 rows × 34 columns, zero nulls
  - Cell 8: write to int.int_game_model_features (DROP/CREATE/INSERT, 3,214 rows)
  - Cell 9: full validation — all checks passed
  - Cell 10: markdown summary
- Key facts confirmed:
  - 1,607 FBS conference games, 131 unique teams, seasons 2022–2024
  - mean points_scored = 26.9 (matches FBS baseline)
  - is_home derived from raw.games join (not in int_game_team_features)
  - close_game_epa_per_play / close_game_def_epa_per_play: 6 nulls each —
    treated as zero (no close-game situations occurred in those games)

## Day 21 — What Was Completed
- Confirmation gate answered correctly before any code was attempted
- model_02_architecture.ipynb completed — 7 cells:
  - Cell 1: imports and environment verification
  - Cell 2: conference index maps (inherited from Day 20 Cell 3)
  - Cell 3: conference-scope mask builder and smoke test
  - Cell 4: GameData dataclass (data container for model_cfb())
  - Cell 5: model_cfb() — full hierarchical NegBinom model function
  - Cell 6: structural verification — prior predictive draw, 38 parameters,
    all assertions passed, Sun Belt constraint confirmed
  - Cell 7: markdown summary
- Log-scale corrections identified and applied to both notebooks:
  - mu_league: Normal(27.0, 5.0) → Normal(3.3, 0.2) [exp(3.3) ≈ 27 pts]
  - hfa_league: Normal(2.5, 1.5) → Normal(0.1, 0.05) [≈ 2.5 pts on 27 pt baseline]
  - sigma_hfa_team: HalfNormal(2.0) → HalfNormal(0.1) [log scale]
- model_01_prior_specification.ipynb Cells 2, 4, and 6 updated to match
- Day 20 Cell 6 re-verified after corrections: 36 parameters, Sun Belt = -0.3398

## Day 20 — What Was Completed
- Confirmation gate answered correctly before any code was attempted
- Environment diagnosis: cfb_model (x86 Anaconda) failed with JAX AVX
  instruction error on Apple Silicon — same root cause as original PyMC
  failure
- Miniforge ARM environment created: cfb_model_arm
  (~/miniforge3/envs/cfb_model_arm/bin/python)
- NumPyro 0.21.0 and JAX 0.10.0 confirmed working on cpu backend
- Kernel registered as "CFB Model (ARM)"
- model_01_prior_specification.ipynb completed — 6 cells:
  - Cell 1: imports and environment verification
  - Cell 2: league-level priors (mu_league, hfa_league, r_negbinom)
  - Cell 3: conference-level priors (sigma_conference, mu_conference x10)
  - Cell 4: team-level priors (alpha_team, delta_team, hfa_team, sp_weight,
    rec_weight with Sun Belt hard constraint)
  - Cell 5: game-level feature priors (23 coefficients)
  - Cell 6: full model assembly and prior predictive verification
- 36 parameters sampled successfully
- Sun Belt constraint confirmed: rec_weight_sunbelt = -0.3398 (non-positive)
- Markdown summary added as final cell

---

## Model Build Phase — Days 20–34

| Day | Notebook | Status | Goal |
|---|---|---|---|
| 20 | model_01_prior_specification.ipynb | ✅ complete | Translate every entry in prior_specification_draft.md into NumPyro prior distributions. No fitting. Every numpyro.sample() call cites its EDA justification. |
| 21 | model_02_architecture.ipynb | ✅ complete | Write hierarchical NegBinom model structure in NumPyro. No fitting. Three levels: league → conference → team. Document every design decision. |
| 22 | model_03_feature_engineering.ipynb | ✅ complete | Engineer all features not persisted after EDA. Write to int.int_game_model_features. All null handling and threshold-zeroing applied here. |
| 23 | model_04_first_fit.ipynb | ❌ not built | Fit on 2022–2024 training data. Do not touch 2025 holdout. Record fit time, divergences, initial parameter estimates. |
| 24 | model_05_prior_predictive_checks.ipynb | ❌ not built | Sample before seeing data. Does it produce plausible CFB scores? Fix priors if it generates 0-point or 150-point games. |
| 25 | model_06_posterior_checks.ipynb | ❌ not built | R-hat < 1.01, trace plots, energy plots, ESS. Confirm convergence. Investigate divergences. |
| 26 | model_07_holdout_evaluation.ipynb | ❌ not built | First look at 2025 holdout. Overall Brier score, calibration curve. Baseline before subgroup breakouts. |
| 27 | model_08_evaluation_by_conference_tier.ipynb | ❌ not built | Brier score and calibration by P4, G5, Independents. |
| 28 | model_09_evaluation_by_game_type.ipynb | ❌ not built | Rivalry games, cross-tier matchups, neutral site games. Quantify how model handles upsets. |
| 29 | model_10_evaluation_season_progression.ipynb | ❌ not built | Does calibration improve as season progresses? Conf game 1 vs conf game 8. |
| 30 | model_11_home_away_spread_accuracy.ipynb | ❌ not built | Home field advantage calibration. Spread accuracy by expected margin. |
| 31 | model_12_year_over_year_stability.ipynb | ❌ not built | Do 2023 model ratings predict 2024 performance? |
| 32 | model_13_refinement.ipynb | ❌ not built | Adjust based on evaluation findings. May require revisiting priors, hierarchy, or dropping features. |
| 33 | model_14_stress_testing.ipynb | ❌ not built | Edge cases: extreme weather, maximum travel, large timezone deltas, thin-data teams. |
| 34 | model_15_signoff.ipynb | ❌ not built | Work through evaluation_checklist.md item by item. Model not signed off until every item addressed. |

Gold layer begins Day 35.

---

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team
- Likelihood: Negative Binomial
- Model form: points ~ NegBinom(mu, r), log(mu) = team_attack + opponent_defense
  + home_advantage + environmental_adjusters + game_level_features
- Dispersion parameter r ~ HalfNormal(); start with single parameter, add
  conference-specific r only if posterior predictive checks show systematic
  miscalibration
- Priors seeded from: sp_rating (team level), recruiting_3yr_avg (team level),
  pregame_elo (game level — not a prior seed, a game-level predictor)
- Conference-level pooling provides regularization (ICC marginal 0.02–0.05
  but pooling still improves small-sample estimates)
- Built in NumPyro (replaces PyMC — see library decision above)

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
| sp_rating | 0.7740 | All conferences; prior does not decay monotonically through games 9-12 |
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
| offense_archetype_matchup | yes | yes | all* | not_applicable |
| defense_archetype_matchup | yes | yes | all* | not_applicable |

*Archetype features require deployable pregame version before September 24, 2026
production launch. If no pregame version clears signal tests, drop these two features
(and home_off_vs_away_def_matchup, away_off_vs_home_def_matchup) at refinement.

### O/U Archetype Features (included in final_features but listed separately for clarity)
| Feature | O/U | Conference Scope |
|---|---|---|
| home_off_vs_away_def_matchup | yes | all* |
| away_off_vs_home_def_matchup | yes | all* |

---

## Prior Specification Summary
Full specification in artifacts/prior_specification_draft.md.

| Parameter | Distribution | Mean | SD | Type |
|---|---|---|---|---|
| mu_league (intercept) | Normal | 3.3 | 0.2 | Weakly informative (log scale) |
| hfa_league | Normal | 0.1 | 0.05 | Informative (log scale) |
| r_negbinom | HalfNormal | — | 5.0 | Weakly informative |
| mu_conference[c] | Normal (hyperprior) | 0.0 | HalfNormal(3.0) | Weakly informative |
| alpha_team[t] (attack) | Normal (hyperprior) | 0.0 | HalfNormal(0.4) | Weakly informative |
| delta_team[t] (defense) | Normal (hyperprior) | 0.0 | HalfNormal(0.4) | Weakly informative |
| hfa_team[t] | Normal (hyperprior) | 0.0 | HalfNormal(0.1) | Weakly informative (log scale) |
| sp_weight | Normal | 0.0 | 1.0 | Informative |
| rec_weight[c] | Normal | 0.0 | 0.5 | Informative |
| rec_weight[Sun Belt] | TruncatedNormal(upper=0) | 0.0 | 0.5 | Hard constraint |
| EPA anchors (×2) | Normal | 0.0 | 0.5 | Weakly informative |
| pregame_elo, elo_sp_divergence | Normal | 0.0 | 0.3 / 0.2 | Weakly informative |
| Environmental features | Normal | 0.0 | 0.3 / 0.2 | Weakly informative |
| Momentum features | Normal | 0.0 | 0.3 | Weakly informative |
| Style/tempo deltas | Normal | 0.0 | 0.3 | Weakly informative |
| Sack-rate mismatch | Normal | 0.0 | 0.2 | Weakly informative |
| Archetype matchups | Normal | 0.0 | 0.3 | Weakly informative |

**Hard constraint:** Sun Belt recruiting_3yr_avg coefficient must be non-positive.
Implementation: numpyro.sample with TruncatedNormal(high=0).

---

## Evaluation Thresholds (from evaluation_checklist.md — Day 34 reference)
- R-hat < 1.01 for all parameters
- ESS_bulk >= 400 and ESS_tail >= 400 for all parameters
- Zero divergences post-warmup
- BFMI > 0.3 for all chains
- Prior predictive: 95% of samples within 0–70 points, VMR 3.0–10.0
- Posterior predictive mean within ±2 points of observed mean per team
- Conference-level posterior predictive mean within ±3 points of observed
- Overall Brier score must beat SP+-only baseline
- Win probability calibration within ±5pp per decile bucket (n >= 20)
- Spread MAE <= 14 points overall; no margin bucket exceeding 18 points
- P4 Brier <= 0.23, G5 Brier <= 0.25
- All 10 conferences calibrated within ±8pp (n >= 10)
- Cross-tier mean P4 win probability vs G5 between 0.72 and 0.88
- Sun Belt recruiting prior weight must be non-positive

Full 39-item checklist: artifacts/evaluation_checklist.md

---

## Locked Decisions — Do Not Revisit
- Library: NumPyro (PyMC abandoned due to pytensor environment failure)
- pytensor: explicitly banned — do not install, import, or reference
- Likelihood: Negative Binomial
- Three-level hierarchy: league → conference → team
- Dispersion: single r parameter to start; add conference-specific r only if
  posterior predictive checks show systematic miscalibration
- HFA: league-level baseline + team-level deviations; no conference-level HFA layer
- SP+ prior weight: does not decay monotonically — remains relevant through games 9-12
- SP+ components (sp_offense, sp_defense): excluded; use sp_rating composite only
- recruiting_3yr_avg: prior seed only — never a game-level predictor
- Sun Belt recruiting weight: non-positive (hard constraint); TruncatedNormal(high=0)
- Early-season null handling: Approach A — impute with season-to-date prior
- ELO/SP+ divergence: compute in notebook first; add to dbt only after model confirms
- Archetype features: deployable pregame version required before production launch
- rush_rate_std_downs, rush_rate_pass_downs: game-level predictors only; not prior seeds
- Environmental features: threshold-activated, modeled as indicator×magnitude; not linear
- opp_sp_rating_at_game_time: control variable only; not a model feature
- Portal and NIL: deprioritized; revisit only if model underperforms in evaluation
- raw.odds: 2026 season only — no historical closing lines; live validation target only
- Pac-12 in dataset: G5 for all seasons (remnant conference after realignment)
- Notre Dame: Power Four — route by team name not conference label
- UConn: Group of Five — route by team name not conference label
- FBS Independents: not a pooling group
- No tiers within conferences: team-level parameters handle within-conference spread
- Conference assignment: historically accurate by season from game records
- 2025 is holdout — excluded from all training queries; season IN (2022, 2023, 2024)
- Training data: 2022–2024 only
- mu_league: Normal(3.3, 0.2) — log scale; exp(3.3) ≈ 27 pts (corrected from Normal(27.0, 5.0))
- hfa_league: Normal(0.1, 0.05) — log scale; ≈ 2.5 pts on 27 pt baseline (corrected from Normal(2.5, 1.5))
- sigma_hfa_team: HalfNormal(0.1) — log scale (corrected from HalfNormal(2.0))
- model_cfb() accepts GameData dataclass; N_teams passed at call time from training data
- Conference-scope masking: build_conf_mask() builds binary float32 mask before model_cfb() is called; one coefficient per scoped feature; masking handles zeroing — no separate priors per conference
- close_game_epa_per_play / close_game_def_epa_per_play: null means no close-game
  situations occurred — treated as zero; applied in model_03_feature_engineering.ipynb
- Archetype KMeans: refit on every run of model_03_feature_engineering.ipynb
  (offense k=4, defense k=4, random_state=42); encoded as integers before DB write;
  label maps in artifacts/archetype_label_maps.json;
  encodings in artifacts/archetype_matchup_encodings.json
- All null handling and threshold-zeroing for model features is applied in
  model_03_feature_engineering.ipynb — do not repeat in downstream notebooks
- scikit-learn installed in cfb_model_arm via:
  ~/miniforge3/bin/conda install -n cfb_model_arm scikit-learn -y

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
- raw.games opponent column in int_game_team_features is named 'opponent' (not
  'opponent_name')
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
  model_03_feature_engineering.ipynb; primary key (game_id, team_name)
- stg.stg_game_weather — kickoff_hour (not yet promoted to int layer)
- raw.games — home/away points, teams, conference_game flag, ELO fields;
  authoritative source for is_home
- raw.plays — play-level table for in-game derived features
- raw.odds — 2026 season only; live validation target only

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

## Artifacts — Active Reference Files
| File | Notes |
|---|---|
| artifacts/final_features.csv | 23 included features with complete prior specs — authoritative feature list for model build |
| artifacts/master_verdict.csv | 93 rows — full EDA verdict record |
| artifacts/prior_specification_draft.md | Day 20 input — translate into NumPyro code |
| artifacts/evaluation_checklist.md | 39-item pass/fail checklist — Day 34 works through this |
| artifacts/ambiguity_resolution.md | 5 binding ambiguity decisions |
| artifacts/candidate_features.csv | 185 keep=True features — reference only |
| artifacts/archetype_label_maps.json | KMeans archetype label maps (offense k=4, defense k=4) — written by model_03_feature_engineering.ipynb |
| artifacts/archetype_matchup_encodings.json | Integer encodings for all 4 archetype matchup columns — written by model_03_feature_engineering.ipynb |

---

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the model build table
3. Add any new locked decisions
4. Add key findings from the session
5. Rewrite the confirmation gate to reflect what the next session must understand
6. Commit: git add docs/model_session_state.md && git commit -m "docs: update model session state after Day X" && git push