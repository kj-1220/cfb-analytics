Always select kernel "CFB Model (ARM)" when opening any notebook in this
project. Do not use any other kernel.

---

## ⚠️ CRITICAL — Confirmation Gate
Rewritten each session to reflect what the next notebook must understand.

**Next notebook: Day 21 — Model Architecture**

Answer these questions in your own words before writing any code:

**Question 1:** Day 21 writes the model architecture but does not fit. What
is the difference between the prior specification function from Day 20 and
the full model function Day 21 must produce? What does Day 21 add that Day
20 does not have?

**Question 2:** The model form is
`log(mu) = team_attack + opponent_defense + home_advantage +
environmental_adjusters + game_level_features`.
How does the three-level hierarchy connect to this equation — specifically,
how do conference-level parameters enter the log-mu calculation?

**Question 3:** Conference-scoped features must be zeroed outside their
confirmed conference list. How is that implemented in the model function
without creating separate priors per conference for game-level features?

---

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

## Model Build Phase — Days 20–33

| Day | Notebook | Status | Goal |
|---|---|---|---|
| 20 | model_01_prior_specification.ipynb | ✅ complete | Translate every entry in prior_specification_draft.md into NumPyro prior distributions. No fitting. Every numpyro.sample() call cites its EDA justification. |
| 21 | model_02_architecture.ipynb | ❌ not built | Write hierarchical NegBinom model structure in NumPyro. No fitting. Three levels: league → conference → team. Document every design decision. |
| 22 | model_03_first_fit.ipynb | ❌ not built | Fit on 2022–2024 training data. Do not touch 2025 holdout. Record fit time, divergences, initial parameter estimates. |
| 23 | model_04_prior_predictive_checks.ipynb | ❌ not built | Sample before seeing data. Does it produce plausible CFB scores? Fix priors if it generates 0-point or 150-point games. |
| 24 | model_05_posterior_checks.ipynb | ❌ not built | R-hat < 1.01, trace plots, energy plots, ESS. Confirm convergence. Investigate divergences. |
| 25 | model_06_holdout_evaluation.ipynb | ❌ not built | First look at 2025 holdout. Overall Brier score, calibration curve. Baseline before subgroup breakouts. |
| 26 | model_07_evaluation_by_conference_tier.ipynb | ❌ not built | Brier score and calibration by P4, G5, Independents. |
| 27 | model_08_evaluation_by_game_type.ipynb | ❌ not built | Rivalry games, cross-tier matchups, neutral site games. Quantify how model handles upsets. |
| 28 | model_09_evaluation_season_progression.ipynb | ❌ not built | Does calibration improve as season progresses? Conf game 1 vs conf game 8. |
| 29 | model_10_home_away_spread_accuracy.ipynb | ❌ not built | Home field advantage calibration. Spread accuracy by expected margin. |
| 30 | model_11_year_over_year_stability.ipynb | ❌ not built | Do 2023 model ratings predict 2024 performance? |
| 31 | model_12_refinement.ipynb | ❌ not built | Adjust based on evaluation findings. May require revisiting priors, hierarchy, or dropping features. |
| 32 | model_13_stress_testing.ipynb | ❌ not built | Edge cases: extreme weather, maximum travel, large timezone deltas, thin-data teams. |
| 33 | model_14_signoff.ipynb | ❌ not built | Work through evaluation_checklist.md item by item. Model not signed off until every item addressed. |

Gold layer begins Day 34.

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
| close_game_epa_per_play | anchor | yes | yes | no | all | none | not_applicable |
| close_game_def_epa_per_play | anchor | yes | yes | no | all | none | not_applicable |
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
Day 20 translates this into NumPyro code. Summary of distributions:

| Parameter | Distribution | Mean | SD | Type |
|---|---|---|---|---|
| mu_league (intercept) | Normal | 27.0 | 5.0 | Weakly informative |
| hfa_league | Normal | 2.5 | 1.5 | Informative |
| r_negbinom | HalfNormal | — | 5.0 | Weakly informative |
| mu_conference[c] | Normal (hyperprior) | 0.0 | HalfNormal(3.0) | Weakly informative |
| alpha_team[t] (attack) | Normal (hyperprior) | 0.0 | HalfNormal(0.4) | Weakly informative |
| delta_team[t] (defense) | Normal (hyperprior) | 0.0 | HalfNormal(0.4) | Weakly informative |
| hfa_team[t] | Normal (hyperprior) | 0.0 | HalfNormal(2.0) | Weakly informative |
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

## Evaluation Thresholds (from evaluation_checklist.md — Day 33 reference)
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

---

## Known Schema Facts — Use Exactly
- point_differential: derive as points_scored - points_allowed
- total_points: derive as points_scored + points_allowed
- conference does NOT exist in int_game_team_features — join to
  int_team_season_features on team_name and season
- int_game_environment has home_team and away_team, not team_name — join on
  game_id only, then filter f.team_name IN (e.home_team, e.away_team)
- All numeric columns from psycopg2 return as Decimal — cast entire numeric
  column list to float64 immediately
- Boolean columns (is_dome, is_high_wind, is_precipitation) — use
  .map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)
- opp_sp_rating_at_game_time exists in int_game_team_features
- pregame_elo, opponent_pregame_elo, postgame_elo, excitement_index exist in
  int_game_team_features
- game_script, game_script_avg_margin exist in int_game_team_features
- close_game_play_count, close_game_def_play_count exist in int_game_team_features
- sp_rating and conference: authoritative source is int_team_season_features
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
- stg.stg_game_weather — kickoff_hour (not yet promoted to int layer)
- raw.games — home/away points, teams, conference_game flag, ELO fields
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
| artifacts/evaluation_checklist.md | 39-item pass/fail checklist — Day 33 works through this |
| artifacts/ambiguity_resolution.md | 5 binding ambiguity decisions |
| artifacts/candidate_features.csv | 185 keep=True features — reference only |

---

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the model build table
3. Add any new locked decisions
4. Add key findings from the session
5. Rewrite the confirmation gate to reflect what the next session must understand
6. Commit: git add docs/model_session_state.md && git commit -m "docs: update model session state after Day X" && git push