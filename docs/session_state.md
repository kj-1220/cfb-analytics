# CFB Analytics — Session State

## Last Updated
2026-05-03

---

## ⚠️ CRITICAL — What This Model Does
This model predicts spread, moneyline, and over/under for any FBS conference game.
It predicts each team's score distribution for a specific upcoming game. Spread,
moneyline, and over/under are derived from those two score distributions via Monte
Carlo simulation.

Goes live: September 24, 2026. This is a date marker only. The model predicts every
FBS conference game from that date forward — for the remainder of the 2026 season
and every season after. It is not built for any specific game or matchup. It must
predict any FBS conference game credibly.

Every feature must earn its place by improving prediction of a specific game outcome.
Season-level aggregations and year-over-year correlations are prior construction tools
only — they inform how confident the model should be in its team quality estimates
going into a game. They are not the end goal. The end goal is: given two specific
teams playing a specific game, what is the distribution of scores, and what does that
imply for spread, moneyline, and over/under.

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
- Do not proceed to the next cell until the current one has been confirmed to run correctly

---

## ⚠️ CRITICAL — Correct EDA Methodology
Every feature must be evaluated against all three tests. All three together constitute
a complete verdict. A feature that passes only one or two tests does not have a
complete verdict.

**Test 1 — Game-level prediction accuracy**
Does this feature improve prediction of:
- Point differential (spread and moneyline signal)
- Total points scored (over/under signal)
- Score distribution variance (moneyline signal specifically)

These are three separate tests. A feature can be relevant for spread and irrelevant
for over/under, or vice versa. They must be evaluated and reported separately.

**Test 2 — Within-season trajectory**
Does the predictive improvement from Test 1 hold across the arc of a conference
season:
- Conference game 1: only the prior exists, no in-season evidence
- Conference games 2–4: posterior beginning to develop
- Conference games 5–8: posterior well-informed
- Conference games 9–12: fully informed posterior

A feature that only works with a full season of data is not useful. The model must
predict conference game 1 with nothing but the prior. Features must be evaluated
at each stage of that trajectory.

**Test 3 — YoY stability**
Is the feature stable enough year over year to build a reliable prior from, so the
model is not starting blind each season.

**Output separation requirement**
Every verdict must state separately:
- Spread signal: yes/no, partial r, threshold cleared
- Over/under signal: yes/no, partial r, threshold cleared
- Moneyline variance signal: yes/no, finding
- Within-season trajectory: holds / degrades / only works late season
- YoY stability: r value, stable/unstable verdict

---

## ⚠️ CRITICAL — Confirmation Gate
This section is specific to the next notebook being built. It is rewritten at the
end of every session to reflect what the next session must understand before
touching anything.

**Next notebook: eda_03_epa_deep_dive.ipynb (Day 8 rebuild)**

Answer these three questions in your own words before writing any code. Do not quote
the session state. If you cannot answer from understanding, you have not read
carefully enough.

1. The EPA deep dive must evaluate features against spread, over/under, and moneyline
separately. Explain specifically how close_game_epa_per_play could affect spread
differently than it affects total points scored — give a concrete example of a game
scenario where it would predict one but not the other.

2. The within-season trajectory test matters because this model predicts conference
game 1 with only the prior. Explain what data is actually available to the model at
conference game 1 for an EPA feature, and why that changes how you evaluate whether
EPA belongs in the model.

3. The old EPA notebook found R²=0.772 for the close-game EPA anchor pair against
point differential. Explain why that number alone is not sufficient to conclude EPA
belongs in the model under the correct methodology, and what additional tests are
required before a verdict can be issued.

---

## Project Goal
Hierarchical Negative Binomial model predicting score distributions for any FBS
conference game.
Outputs: spread, moneyline, over/under derived via Monte Carlo simulation from each
team's predicted score distribution.
Goes live: September 24, 2026. Date marker only — not a target game.

---

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team (confirmed Day 10)
- Likelihood: Negative Binomial (confirmed Day 6)
- Model form: points ~ NegBinom(mu, r), log(mu) = team_attack + opponent_defense +
  home_advantage + ...
- Dispersion parameter r ~ HalfNormal(), fit from data — should vary by conference
  given VMR range 5.2–8.1
- Priors seeded from: SP+ preseason rating, 3-year recruiting composite, transfer
  portal net, NIL proxy
- Conference-level pooling handles small sample size (12 games/team)
- Built in PyMC

---

## EDA Phase — Days 6–19
| Day | Notebook | Status | Decision Produced |
|---|---|---|---|
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | 🔴 rebuild required | Old methodology — missing over/under evaluation and within-season trajectory |
| 9 | eda_04_sp_ratings_recruiting.ipynb | 🔴 rebuild required | Old methodology — missing over/under evaluation and within-season trajectory |
| 10 | eda_05_hierarchy_structure.ipynb | 🔴 rebuild required | Old methodology — missing over/under evaluation and within-season trajectory |
| 11 | eda_06_environmental_features.ipynb | 🔴 rebuild required | Old methodology — missing over/under evaluation and within-season trajectory |
| 12 | eda_07_momentum_rolling_features.ipynb | 🔴 rebuild required | Old methodology — missing over/under evaluation and within-season trajectory |
| 13 | eda_08_elo_excitement.ipynb | ❌ not built | SP+/ELO divergence signal; excitement index as game-level over/under signal |
| 14 | Claude Code session | ❌ not started | Play-by-play schema exploration — style, tempo, positional, spatial, line play candidates |
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
| 28 | model_09_evaluation_season_progression.ipynb | Does calibration improve as season progresses? Conference game 1 is prior-driven. Conference game 8 has rolling data. Quantify improvement. |
| 29 | model_10_home_away_spread_accuracy.ipynb | Home field advantage calibration. Spread accuracy by expected margin. |
| 30 | model_11_year_over_year_stability.ipynb | Do 2023 model ratings predict 2024 performance? Tests whether team quality estimates are predictive not just descriptive. |
| 31 | model_12_refinement.ipynb | Adjust based on evaluation findings. May require revisiting priors, hierarchy, or dropping features. Likely a two-session day. |
| 32 | model_13_stress_testing.ipynb | Edge cases: extreme weather, maximum travel, large timezone deltas, teams with very few data points. Find where model breaks. |
| 33 | model_14_signoff.ipynb | Work through evaluation checklist from Day 18. Document every modeling decision, EDA finding that motivated it, and known limitations. Model not signed off until every checklist item addressed. |

Gold layer begins Day 34.

---

## What The Next Session Must Build
Rebuild eda_03_epa_deep_dive.ipynb — Day 8, using the correct three-test methodology.

Every EPA feature must be evaluated against:
1. Game-level prediction of point differential — spread signal
2. Game-level prediction of total points scored — over/under signal
3. Score distribution variance — moneyline signal
4. Within-season trajectory across conference games 1, 2–4, 5–8, 9–12
5. YoY stability — r value and stable/unstable verdict

Every verdict must report spread, over/under, and moneyline findings separately.

---

## Artifacts Status
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 154 features, keep=True only |
| artifacts/epa_feature_verdict.csv | 🔴 invalid | Produced under old methodology — rebuild Day 8 |
| artifacts/sp_recruiting_verdict.csv | 🔴 invalid | Produced under old methodology — rebuild Day 9 |
| artifacts/hierarchy_verdict.csv | 🔴 invalid | Produced under old methodology — rebuild Day 10 |
| artifacts/environment_verdict.csv | 🔴 invalid | Produced under old methodology — rebuild Day 11 |
| artifacts/momentum_verdict.csv | 🔴 invalid | Produced under old methodology — rebuild Day 12 |

---

## YoY Benchmarks (valid — methodology-independent)
- off_epa_per_play YoY r = 0.423
- def_epa_per_play YoY r = 0.393
- sp_rating YoY r = 0.761, 95% CI [0.718, 0.803]
- away_elevation_delta_ft YoY r = 0.863 — stable
- away_travel_distance_mi YoY r = 0.723 — unstable

These numbers are valid because YoY stability is methodology-independent. They will
be used as benchmarks in the rebuilt notebooks but do not constitute complete verdicts
on their own.

---

## Known Schema Facts — Use Exactly
- point_differential does not exist — derive as points_scored - points_allowed
- total_points does not exist — derive as points_scored + points_allowed
- Two distinct defensive EPA columns — do not confuse:
  - def_epa_per_play_allowed in int_game_team_features — GAME-LEVEL
  - def_epa_per_play in int_team_season_features — SEASON-LEVEL
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

---

## Source Tables
- int.int_game_team_features — game-level team performance including pregame_elo,
  excitement_index
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context including conference
- int.int_team_season_features — season-level team features, 534 rows, FBS only

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
All other teams evaluated on actual season-accurate conference membership.

---

## Locked Decisions — Do Not Revisit
- Likelihood: Negative Binomial (Day 6 — scoring distribution math, not EDA verdicts)
- Three-level hierarchy: league → conference → team (Day 10 — ICC is a data structure
  question, methodology-independent)
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
- FBS Independents: not a pooling group — Notre Dame routes to P4, UConn routes
  to G5 by team name
- No tiers within conferences: team-level parameters handle within-conference spread
- Early-season null handling: Approach A — impute with season-to-date prior
- Style/tempo analysis: delta approach first, clustering second (Days 15–16)
- SP+/ELO divergence: compute in notebook first, add to dbt only if proven valid
- Portal and NIL: deprioritized — revisit only if model underperforms in evaluation

## Decisions Pending Rebuild Confirmation
The following were made under the old methodology and cannot be treated as locked
until the rebuilt notebooks confirm them:
- No environmental feature as model adjuster
- No last3_* rolling features in model
- No bye week adjustment term
- Weather features redundant after EPA control (spread and over/under)
- High wind asymmetry finding
- away_travel_distance_mi supporting-unstable only in max stress population
- is_dome not a spread or over/under term
- Recruiting requires conference-specific treatment
- def_epa_per_play_allowed (game-level) redundant as model feature

---

## Data Added (2026-05-01)
- Added to raw.games: home_pregame_elo, away_pregame_elo, home_postgame_elo,
  away_postgame_elo, excitement_index
- Added to stg_games: all five columns
- Added to int_game_team_features: pregame_elo, opponent_pregame_elo, postgame_elo,
  excitement_index
- ELO flipped correctly to team perspective
- Coverage: pregame_elo 6,478/29,472 rows (100% within FBS conferences),
  excitement_index 12,066/29,472 rows
- ELO/SP+ correlation: r=0.8625

## Data Fixes Applied (prior sessions)
- Conference assignment by season from game records (not static snapshot)
- 18 FCS transition team-seasons removed — row count 552 → 534
- 161 FBS venues missing elevation data — fetched via Open-Meteo API, seed now
  603 unique venues

---

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the EDA table
3. Add any new locked decisions — move from pending to locked only when rebuilt
   notebook confirms under correct methodology
4. Add key findings — spread, over/under, and moneyline reported separately
5. Rewrite the confirmation gate to reflect what the next session must understand
6. Update what the next session must build
7. Commit: git add docs/session_state.md && git commit -m "docs: update session
   state after Day X" && git push