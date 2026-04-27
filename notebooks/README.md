# CFB Analytics — EDA & Model Build Plan

## Overview

This folder contains all Jupyter notebooks for the EDA and model build phases of the CFB Analytics Platform. EDA runs Days 6–14. Model build runs Days 15–28. The Gold layer does not begin until Day 29 — after the model is signed off.

The goal of EDA is not to produce charts. It is to make decisions. Every notebook in this folder should answer specific questions that change what goes into the model or how it is structured. If a notebook does not produce at least one actionable decision, it did not accomplish its goal.

The model is a hierarchical Poisson model built in PyMC. It predicts a score distribution for each team in a given matchup. Spread, moneyline, and over/under are derived from those distributions via Monte Carlo simulation. The model must be evaluated as a general system across the full range of FBS matchups — not tuned toward any single game.

---

## Folder Structure

```
notebooks/
├── README.md                          ← this file
│
├── eda/
│   ├── eda_01_scoring_distributions.ipynb
│   ├── eda_02_feature_inventory.ipynb
│   ├── eda_03_epa_deep_dive.ipynb
│   ├── eda_04_sp_ratings_recruiting.ipynb
│   ├── eda_05_hierarchy_structure.ipynb
│   ├── eda_06_environmental_features.ipynb
│   ├── eda_07_momentum_rolling_features.ipynb
│   ├── eda_08_game_script_close_games.ipynb
│   └── eda_09_evaluation_framework.ipynb
│
└── model/
    ├── model_01_prior_specification.ipynb
    ├── model_02_architecture.ipynb
    ├── model_03_first_fit.ipynb
    ├── model_04_prior_predictive_checks.ipynb
    ├── model_05_posterior_checks.ipynb
    ├── model_06_holdout_evaluation.ipynb
    ├── model_07_evaluation_by_conference_tier.ipynb
    ├── model_08_evaluation_by_game_type.ipynb
    ├── model_09_evaluation_season_progression.ipynb
    ├── model_10_home_away_spread_accuracy.ipynb
    ├── model_11_year_over_year_stability.ipynb
    ├── model_12_refinement.ipynb
    ├── model_13_stress_testing.ipynb
    └── model_14_signoff.ipynb
```

---

## Connection

All notebooks connect to Postgres via SQLAlchemy.

```python
from sqlalchemy import create_engine, text
engine = create_engine("postgresql+psycopg2://postgres:postgres@127.0.0.1:5455/postgres")
```

---

## EDA Phase — Days 6–14

The guiding principle: every EDA day answers a specific question that affects model design.
The questions are listed explicitly for each day below.

---

### Day 6 — Scoring Distributions & Poisson Assumption
**Notebook:** `eda/eda_01_scoring_distributions.ipynb`

**Questions to answer:**
- What does the distribution of points scored look like across all FBS games 2022–2025?
- Is scoring roughly Poisson distributed — is the mean close to the variance?
- If variance is substantially larger than the mean (overdispersion), the model needs negative binomial instead of Poisson. This is a model architecture decision that must be made here.
- How does scoring vary by conference, by season, and by home vs away?
- What is the baseline home scoring advantage across the dataset?

**Decision this day produces:**
Poisson vs negative binomial likelihood. This cannot be deferred.

---

### Day 7 — Feature Inventory & Deduplication
**Notebook:** `eda/eda_02_feature_inventory.ipynb`

**Questions to answer:**
- Which columns appear in more than one int table?
- For every duplicated column, which table is the authoritative source?
- After deduplication, what is the full candidate feature list for the model?
- Are there columns in int_team_season_features (102 cols) or int_team_season_context (87 cols) that are clearly downstream calculations of other columns in the same table?

**Decision this day produces:**
A single flat candidate feature list. No modeling proceeds against columns not on this list.

---

### Day 8 — EPA Deep Dive
**Notebook:** `eda/eda_03_epa_deep_dive.ipynb`

**Questions to answer:**
- How correlated are off_epa_per_play, def_epa_per_play, close_game_epa_per_play, and rolling EPA from int_game_team_features?
- What is the relationship between EPA and actual points scored per game?
- How stable is a team's EPA from one season to the next? High stability supports using EPA as a strong prior seed. Low stability means wider priors.
- Does off_epa_per_play and def_epa_per_play together explain most of the variance in point differential, or is there meaningful residual variance that other features need to explain?

**Decision this day produces:**
Which EPA features are redundant with each other. Whether EPA is stable enough to anchor priors.

---

### Day 9 — SP+ Ratings & Recruiting
**Notebook:** `eda/eda_04_sp_ratings_recruiting.ipynb`

**Questions to answer:**
- Does SP+ composite rating add predictive signal beyond EPA, or do they largely capture the same team quality signal?
- What is the relationship between recruiting_3yr_avg and on-field performance (EPA, win percentage)?
- How does the signal from SP+ and recruiting hold up at lower tiers — Group of Five programs specifically?
- How stable is SP+ rating year over year compared to EPA?

**Decision this day produces:**
Whether SP+ and recruiting belong in the model alongside EPA or whether one of them is redundant given the others.

---

### Day 10 — Hierarchy Structure
**Notebook:** `eda/eda_05_hierarchy_structure.ipynb`

**Questions to answer:**
- How much of the variance in scoring is between conferences vs within conferences?
- Are there conferences where within-conference variance is so high that conference-level pooling adds little value?
- Are there conferences that are outliers in ways that will dominate pooling (e.g., SEC scoring vs MAC scoring)?
- Does a three-level hierarchy (league → conference → team) fit the actual variance structure of the data, or does it need adjustment?

**Decision this day produces:**
Confirmation or adjustment of the hierarchy structure before the model is written.

---

### Day 11 — Environmental Features
**Notebook:** `eda/eda_06_environmental_features.ipynb`

**Questions to answer:**
- Does venue elevation show a measurable relationship with scoring outcomes or home team advantage in the data?
- Does away travel distance correlate with away team performance degradation?
- Does timezone delta (away_tz_delta_hrs) show up in scoring or win rate?
- What is the null rate on away_travel_distance_mi and is it high enough to affect usability?
- Are these features empirically supported in this dataset, or are they theoretically motivated but weak?

**Decision this day produces:**
Which environmental features have enough empirical support to include in the model. Features that are theoretically interesting but empirically flat get dropped.

---

### Day 12 — Momentum & Rolling Features
**Notebook:** `eda/eda_07_momentum_rolling_features.ipynb`

**Questions to answer:**
- Do last3_off_epa_avg and last3_win_pct predict next-game outcomes better than season-level averages?
- How much do the rolling features diverge from season averages mid-season? When do they converge?
- Is there a measurable bye week effect in days_since_last_game?
- How should Week 1 and Week 2 nulls be handled — impute with season priors, or treat early-season games as a separate case?

**Decision this day produces:**
Whether rolling features add signal beyond season averages. How to handle early-season nulls.

---

### Day 13 — Game Script & Close Game Signals
**Notebook:** `eda/eda_08_game_script_close_games.ipynb`

**Questions to answer:**
- Do pct_games_dominant, pct_games_competitive, and pct_games_deficit carry information about future outcomes beyond what EPA already captures?
- Is close_game_epa_per_play stable enough across 3–4 games per season to be a reliable signal?
- Is game script best used as a model input or as a covariate for interpreting EPA?
- Does close_game_count_plays_based serve as an adequate proxy for close_game_count (Pearson r > 0.90)?

**Decision this day produces:**
Whether game script and close game features belong in the model, and in what role.

---

### Day 14 — Evaluation Framework Design
**Notebook:** `eda/eda_09_evaluation_framework.ipynb`

**Questions to answer:**
- What is the holdout set? (2025 season, held out entirely — not individual games.)
- What metrics will be used? Primary: Brier score. Secondary: calibration curves.
- What evaluation dimensions will be tested?
  - Conference tier: Power Four vs Group of Five vs Independents
  - Game type: rivalry games, cross-tier matchups, neutral site games
  - Season progression: Week 1 through bowl games — does calibration improve as data accumulates?
  - Home/away: does home field advantage get modeled correctly?
  - Spread accuracy: broken out by expected margin
  - Year-over-year stability: do 2023 model ratings predict 2024 performance?
- What does the model need to demonstrate before it is trusted for production use?

**Decision this day produces:**
A written evaluation checklist. The model is not signed off until every item on this checklist is addressed.

---

## Model Build Phase — Days 15–28

---

### Day 15 — Prior Specification
**Notebook:** `model/model_01_prior_specification.ipynb`

Translate every EDA finding into a written prior distribution. Every parameter in the model needs a prior before any code is written. If a prior cannot be justified from something observed in EDA, go back and look.

Key priors to specify:
- League-level scoring rate
- Conference-level adjustments
- Team-level adjustments
- Home field advantage
- Environmental adjusters (only for features that survived Day 11)
- Momentum adjusters (only for features that survived Day 12)

---

### Day 16 — Model Architecture
**Notebook:** `model/model_02_architecture.ipynb`

Write the hierarchical Poisson model structure in PyMC. No fitting yet. Structure only. Three levels: league → conference → team. Document every design decision and the EDA finding that motivated it.

---

### Day 17 — First Fit on Training Data
**Notebook:** `model/model_03_first_fit.ipynb`

Fit the model on 2022–2024 training data. Do not touch the 2025 holdout. Record fit time, number of divergences, and initial parameter estimates.

---

### Day 18 — Prior Predictive Checks
**Notebook:** `model/model_04_prior_predictive_checks.ipynb`

Sample from the model before it sees data. Does it produce plausible college football scores? If it generates 0-point or 150-point games, the priors are wrong. Fix before moving forward.

---

### Day 19 — Posterior Checks & Convergence Diagnostics
**Notebook:** `model/model_05_posterior_checks.ipynb`

R-hat values (target < 1.01), trace plots, energy plots, effective sample size. Confirm the sampler converged. Investigate any divergences.

---

### Day 20 — Holdout Evaluation: Overall
**Notebook:** `model/model_06_holdout_evaluation.ipynb`

First look at the 2025 holdout set. Overall Brier score, calibration curve across all games. Establish the baseline before breaking out by subgroup.

---

### Day 21 — Evaluation by Conference Tier
**Notebook:** `model/model_07_evaluation_by_conference_tier.ipynb`

Brier score and calibration broken out by Power Four, Group of Five, and Independents separately. The model should perform reasonably across all tiers, not just the top.

---

### Day 22 — Evaluation by Game Type
**Notebook:** `model/model_08_evaluation_by_game_type.ipynb`

Performance on rivalry games, cross-tier matchups, and neutral site games. Rivalry games are expected to produce more upsets than equivalent non-rivalry games — quantify how the model handles this.

---

### Day 23 — Evaluation by Season Progression
**Notebook:** `model/model_09_evaluation_season_progression.ipynb`

Does calibration improve as the season progresses and more in-season data accumulates? Week 1 predictions are prior-driven. By Week 8 the model has rolling EPA and recent results. Quantify the improvement — this directly affects how much confidence to communicate to users for early-season predictions.

---

### Day 24 — Home/Away Calibration & Spread Accuracy
**Notebook:** `model/model_10_home_away_spread_accuracy.ipynb`

Does the model capture home field advantage correctly? Spread accuracy broken out by expected margin — a model that is well-calibrated on large favorites but unreliable on coin-flip games has limited practical value.

---

### Day 25 — Year-over-Year Stability
**Notebook:** `model/model_11_year_over_year_stability.ipynb`

Do teams the model rates highly in 2023 actually perform well in 2024? This tests whether the model's team quality estimates are genuinely predictive or just descriptive.

---

### Day 26 — Model Refinement
**Notebook:** `model/model_12_refinement.ipynb`

Adjust the model based on everything the evaluation found. This may require revisiting priors, adjusting the hierarchy, or dropping features that did not contribute. This is likely a two-hour session.

---

### Day 27 — Stress Testing
**Notebook:** `model/model_13_stress_testing.ipynb`

Edge cases: extreme weather games, maximum travel distance matchups, large timezone deltas, teams with very few data points (new programs, FCS opponents). Find where the model breaks and document it.

---

### Day 28 — Sign Off
**Notebook:** `model/model_14_signoff.ipynb`

Work through the evaluation checklist from Day 14. Document every modeling decision, the EDA finding that motivated it, and known limitations. The model is not signed off until every checklist item is addressed. This notebook becomes the permanent record of what the model does and why.

Gold layer begins Day 29.

---

## Key Principles

**EDA produces decisions, not charts.** Every notebook should end with a written decision or a written open question. If neither exists, the work is not done.

**The model is a general system.** It must perform credibly across the full range of FBS matchups — blue blood vs blue blood, mid-major vs mid-major, cross-tier, rivalry games, early season and late season. Evaluation is not a checkbox. It is a week of work.

**Priors must be defensible.** Every prior in the PyMC model must be traceable to something observed in EDA. If you cannot point to the notebook that motivated a prior, it is not justified.

**The holdout set is sacred.** The 2025 season is held out entirely and is not examined until Day 20. No peeking during model building.

**Gold layer waits.** The mart tables and semantic layer are not built until the model is signed off on Day 28. Building gold layer infrastructure around an unvalidated model is waste.
