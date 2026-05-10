# CFB Analytics — Model Evaluation Checklist

**Project:** CFB Analytics — Hierarchical Negative Binomial Model  
**Created:** 2026-05-09  
**Source notebook:** `eda_12_evaluation_framework.ipynb`  
**Go-live date:** 2026-09-24  

## Purpose

Defines pass/fail criteria for model sign-off. Day 33 (model_14_signoff.ipynb) works through every item. Model is not signed off until every item has an explicit PASS or a documented exception with justification.

**Total items:** 39  
**Sign-off notebook:** `model_14_signoff.ipynb` (Day 33)  
**Sign-off rule:** Every item must record PASS or a documented exception with explicit justification. No item may be skipped.

## Dimensions

- [Convergence and Sampling Quality (5 items)](#convergence-and-sampling-quality)
- [Prior Predictive Checks (3 items)](#prior-predictive-checks)
- [Posterior Predictive Checks (4 items)](#posterior-predictive-checks)
- [Holdout Evaluation (2025 Season) (4 items)](#holdout-evaluation-2025-season)
- [Subgroup Evaluation (8 items)](#subgroup-evaluation)
- [Edge Case Stress Tests (6 items)](#edge-case-stress-tests)
- [Feature Contribution Checks (5 items)](#feature-contribution-checks)
- [Known Failure Modes (4 items)](#known-failure-modes)

---

## Convergence and Sampling Quality

### CONV-01 — R-hat for all parameters

**Threshold:** R-hat < 1.01 for every parameter in the model

**Pass condition:**

```
max(R-hat) < 1.01 with no individual parameter exceeding 1.01
```

**Notes:** Check team-level attack and defense parameters individually — do not rely on summary statistics alone. If any parameter exceeds 1.01, investigate before proceeding. R-hat between 1.01 and 1.05 requires documented justification. R-hat > 1.05 is an automatic FAIL.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### CONV-02 — Effective sample size

**Threshold:** ESS_bulk >= 400 and ESS_tail >= 400 for all parameters

**Pass condition:**

```
min(ESS_bulk) >= 400 and min(ESS_tail) >= 400
```

**Notes:** ESS between 200 and 400 requires documented justification. ESS < 200 for any parameter is an automatic FAIL. Pay particular attention to dispersion parameter r and conference-level hyperparameters.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### CONV-03 — Divergences

**Threshold:** Divergence count = 0 after tuning

**Pass condition:**

```
Zero divergences in the post-warmup sample
```

**Notes:** Any divergences require investigation of the model geometry — do not simply increase target_accept and rerun. If divergences persist after reparameterization attempts, document the structural cause before proceeding.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### CONV-04 — Trace plots

**Threshold:** All chains mix visually — no trends, no chain separation, no sticking

**Pass condition:**

```
Visual inspection of trace plots for all top-level parameters shows stationary, well-mixed chains
```

**Notes:** Inspect at minimum: league-level intercept, conference-level hyperparameters, dispersion parameter r, home field advantage, and at least one team-level attack and defense parameter per conference. Document any chain that shows non-stationarity.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### CONV-05 — Energy plots (BFMI)

**Threshold:** BFMI > 0.3 for all chains

**Pass condition:**

```
min(BFMI across chains) > 0.3
```

**Notes:** BFMI between 0.2 and 0.3 requires documented justification. BFMI < 0.2 indicates the sampler is not exploring the posterior efficiently and is an automatic FAIL.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Prior Predictive Checks

### PRIOR-01 — Score range plausibility

**Threshold:** 95% of prior predictive samples fall within 0–70 points per team. Zero samples below 0. Fewer than 1% of samples above 80 points.

**Pass condition:**

```
Prior predictive distribution produces no negative scores, fewer than 1% of samples above 80, and 95th percentile <= 70
```

**Notes:** Sample at least 500 prior predictive games. If the prior generates 0-point or 150-point games, the priors are miscalibrated — fix before fitting. This check runs before any data is seen.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### PRIOR-02 — Score variance consistency with observed VMR

**Threshold:** Prior predictive VMR falls within 3.0–10.0

**Pass condition:**

```
Variance-to-mean ratio of prior predictive score samples is between 3.0 and 10.0
```

**Notes:** Observed VMR range from EDA: 4.95–7.16 (2022–2024). Prior predictive VMR should be wider than observed (priors are uncertain) but not implausibly wide. VMR < 2.0 suggests under-dispersed priors. VMR > 15.0 suggests over-dispersed priors.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### PRIOR-03 — Plausible total points distribution

**Threshold:** Prior predictive mean total points between 40 and 65. 95% interval does not extend below 10 or above 120.

**Pass condition:**

```
40 <= mean(prior predictive total points) <= 65 and P2.5 >= 10 and P97.5 <= 120
```

**Notes:** Observed mean total points 2022–2024: approximately 52–56. Prior mean should be in plausible CFB territory. Extremes indicate a prior specification error.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Posterior Predictive Checks

### POST-01 — Overall score distribution fit

**Threshold:** Posterior predictive mean within ±2 points of observed mean. Posterior predictive SD within ±3 points of observed SD.

**Pass condition:**

```
abs(posterior_predictive_mean - observed_mean) <= 2.0 and abs(posterior_predictive_sd - observed_sd) <= 3.0
```

**Notes:** Compute separately for points_scored and points_allowed. A model that fits the mean but not the variance has a dispersion problem.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### POST-02 — Conference-level calibration

**Threshold:** Posterior predictive mean within ±3 points of observed conference mean for all 10 FBS conferences individually

**Pass condition:**

```
All 10 conferences pass the ±3 point mean check. Flag any conference outside ±5 points as a hard FAIL.
```

**Notes:** Check all 10 conferences: ACC, American Athletic, Big 12, Big Ten, Conference USA, Mid-American, Mountain West, Pac-12, SEC, Sun Belt. A conference that consistently over- or under-predicts has a conference-level prior or pooling problem.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### POST-03 — Dispersion parameter adequacy

**Threshold:** Posterior predictive VMR per conference within 1.5x of observed VMR for that conference

**Pass condition:**

```
max(posterior_predictive_VMR / observed_VMR) <= 1.5 and min(posterior_predictive_VMR / observed_VMR) >= 0.67 across all conferences
```

**Notes:** If any conference shows systematic VMR miscalibration, add conference-specific dispersion parameter r as specified in the model architecture decision (Day 10). Single r is the starting assumption — this check is the gate for whether that assumption holds.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### POST-04 — Tail behavior — high-scoring and low-scoring games

**Threshold:** Posterior predictive frequency of games with total points >= 70 within ±3pp of observed frequency. Posterior predictive frequency of games with total points <= 30 within ±3pp of observed frequency.

**Pass condition:**

```
Both tail frequency checks pass within ±3 percentage points
```

**Notes:** Tail calibration matters for over/under prediction. A model that gets the mean right but underestimates tail probability will systematically miscalibrate over/under lines in extreme games.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Holdout Evaluation (2025 Season)

### HOLD-01 — Overall Brier score vs baseline

**Threshold:** Brier score lower than a naive baseline using only SP+ delta

**Pass condition:**

```
model_brier_score < sp_only_baseline_brier_score on the full 2025 holdout set
```

**Notes:** The SP+-only baseline uses pregame SP+ rating differential to generate win probabilities via logistic regression. If the full model does not beat this baseline, the additional features are not earning their complexity. Also report vs a coin-flip baseline (Brier = 0.25) for reference.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### HOLD-02 — Calibration curve — win probability

**Threshold:** Predicted win probabilities within ±5pp of observed win frequencies across all decile buckets (0–10%, 10–20%, ... 90–100%)

**Pass condition:**

```
All decile buckets with n >= 20 games pass the ±5pp check. No bucket with n >= 20 exceeds ±8pp.
```

**Notes:** Buckets with n < 20 are reported but not gated. Systematic over-confidence (predicted > observed in high-probability buckets) and systematic under-confidence are distinct failure modes — report separately.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### HOLD-03 — Spread accuracy by expected margin bucket

**Threshold:** Mean absolute spread error <= 14 points overall. No expected-margin bucket (0–7, 7–14, 14–21, 21+) has MAE exceeding 18 points.

**Pass condition:**

```
overall_MAE <= 14.0 and max(bucket_MAE across margin buckets with n >= 20) <= 18.0
```

**Notes:** MAE thresholds calibrated against typical CFB spread accuracy benchmarks. If the model consistently underestimates margin in blowouts (21+ bucket), the dispersion parameter or team-strength hierarchy has a structural problem.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### HOLD-04 — Over/under calibration

**Threshold:** Predicted over probability within ±5pp of observed over frequency across total-points decile buckets

**Pass condition:**

```
All decile buckets with n >= 20 games pass the ±5pp check on over/under calibration
```

**Notes:** Report separately for dome games vs outdoor games and for games with wind_chill <= 25°F — these are the subpopulations where environmental features are expected to contribute.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Subgroup Evaluation

### SUB-01 — Brier score by conference tier — P4

**Threshold:** P4 Brier score <= 0.23

**Pass condition:**

```
p4_brier_score <= 0.23
```

**Notes:** P4 conferences: ACC, Big 12, Big Ten, SEC. P4 games have more data per team, so the model should calibrate better here than in G5. Threshold is tighter than overall.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-02 — Brier score by conference tier — G5

**Threshold:** G5 Brier score <= 0.25

**Pass condition:**

```
g5_brier_score <= 0.25
```

**Notes:** G5 conferences: American Athletic, Conference USA, Mid-American, Mountain West, Pac-12 (remnant), Sun Belt. G5 teams have thinner data — some degradation vs P4 is acceptable, but the model must remain credible. If G5 Brier > 0.25, investigate whether conference-level pooling is providing adequate regularization.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-03 — Calibration by individual conference

**Threshold:** Win probability calibration within ±8pp of observed frequency for each of the 10 FBS conferences individually (in decile buckets with n >= 10)

**Pass condition:**

```
All 10 conferences pass the ±8pp calibration check in buckets with n >= 10
```

**Notes:** Report all 10 conferences: ACC, American Athletic, Big 12, Big Ten, Conference USA, Mid-American, Mountain West, Pac-12, SEC, Sun Belt. A conference that systematically fails calibration despite passing overall indicates a conference-level prior or pooling problem.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-04 — Rivalry games

**Threshold:** Brier score for rivalry games within ±0.03 of overall Brier score

**Pass condition:**

```
abs(rivalry_brier_score - overall_brier_score) <= 0.03
```

**Notes:** Rivalry games are defined from the raw.games rivalry flag or a curated list. These games have higher upset rates and crowd effects. If rivalry_brier >> overall_brier, the model is not accounting for rivalry dynamics. Report rivalry upset rate vs model-implied upset rate.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-05 — Cross-tier matchups (P4 vs G5)

**Threshold:** Brier score for cross-tier games <= 0.22. Mean predicted win probability for P4 favorites between 0.72 and 0.88.

**Pass condition:**

```
cross_tier_brier_score <= 0.22 and 0.72 <= mean_p4_win_prob_vs_g5 <= 0.88
```

**Notes:** Cross-tier matchups are the games where the model's strength separation is most directly tested. If the model assigns P4 teams < 72% win probability on average vs G5, it is under-differentiating. If > 88%, it is over-differentiating. Both are calibration failures.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-06 — Neutral site games

**Threshold:** Brier score for neutral site games within ±0.03 of overall Brier score. Mean predicted home advantage for neutral site games between -1.5 and +1.5 points.

**Pass condition:**

```
abs(neutral_site_brier_score - overall_brier_score) <= 0.03 and abs(mean_neutral_site_home_advantage) <= 1.5
```

**Notes:** Neutral site games have no home field advantage. If the model systematically assigns home advantage to neutral games, the home field feature is not correctly conditioned on venue type.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-07 — Season progression — conference game 1 (prior-driven)

**Threshold:** Brier score for conf game 1 <= 0.26. Calibration within ±10pp of observed frequency.

**Pass condition:**

```
conf_game_1_brier_score <= 0.26 and conf_game_1_calibration_error <= 0.10
```

**Notes:** At conf game 1, rolling features are null — model runs entirely on prior (SP+, recruiting) and pregame ELO. Degraded performance vs later games is expected. The gate here is that the model produces credible estimates, not that it matches later-season accuracy.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### SUB-08 — Season progression — conference games 5–8 (posterior-informed)

**Threshold:** Brier score for conf games 5–8 <= 0.23

**Pass condition:**

```
conf_games_5_8_brier_score <= 0.23
```

**Notes:** By games 5–8 the posterior has accumulated meaningful in-season data. If Brier does not improve from conf game 1 to games 5–8, the rolling features are not contributing. Report improvement trajectory: game 1, games 2–4, games 5–8, games 9–12.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Edge Case Stress Tests

### EDGE-01 — Extreme elevation differential (>= 2000ft threshold)

**Threshold:** Spread MAE for elevation-triggered games (away_elevation_delta_ft >= 2000) within ±4 points of overall spread MAE

**Pass condition:**

```
abs(elevation_triggered_MAE - overall_MAE) <= 4.0
```

**Notes:** EDA confirmed signal concentrates in Mountain West and Big 12 above the 2000ft threshold. YoY r = 0.8255. If elevation-triggered games show systematically higher MAE, the threshold-activated feature is not correctly specified.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### EDGE-02 — Extreme travel distance (>= 1500mi threshold)

**Threshold:** Spread MAE for travel-triggered games (away_travel_distance_mi >= 1500) within ±4 points of overall spread MAE

**Pass condition:**

```
abs(travel_triggered_MAE - overall_MAE) <= 4.0
```

**Notes:** EDA confirmed spread signal only — no O/U signal. YoY r = 0.6562 (below anchor threshold but included as supporting). Report n for this subpopulation — may be small in 2025 holdout.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### EDGE-03 — Large timezone delta (abs >= 2hr threshold)

**Threshold:** Spread MAE for timezone-triggered games (abs(away_tz_delta_hrs) >= 2) within ±4 points of overall spread MAE

**Pass condition:**

```
abs(timezone_triggered_MAE - overall_MAE) <= 4.0
```

**Notes:** EDA confirmed spread signal only. Signal strengthens at abs >= 3hr (r = -0.3103, n = 38). Report separately for abs >= 2hr and abs >= 3hr subpopulations.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### EDGE-04 — Extreme cold weather (wind_chill <= 25°F)

**Threshold:** Over/under calibration error for cold-weather games (wind_chill <= 25°F) within ±8pp of observed over frequency

**Pass condition:**

```
cold_weather_ou_calibration_error <= 0.08
```

**Notes:** EDA confirmed O/U signal only at wind_chill <= 25°F (r = 0.3373, n = 71). No spread signal. If the model does not lower total point predictions in extreme cold, the wind_chill feature is not activating correctly.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### EDGE-05 — Teams with thin conference game history in training data

**Threshold:** Brier score for games involving teams with <= 10 conference games in 2022–2024 training data within ±0.04 of overall Brier score

**Pass condition:**

```
abs(thin_data_team_brier_score - overall_brier_score) <= 0.04
```

**Notes:** Thin-data teams include: teams that joined a conference late in the training window, teams that played reduced schedules, and new FBS programs. Conference-level pooling should regularize these teams toward the conference mean. If thin-data games show substantially higher Brier, pooling is insufficient.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### EDGE-06 — Teams that changed conferences between seasons

**Threshold:** Brier score for games involving conference-switching teams within ±0.04 of overall Brier score

**Pass condition:**

```
abs(conference_switcher_brier_score - overall_brier_score) <= 0.04
```

**Notes:** Conference assignment is historically accurate by season (locked decision). Teams switching conferences between 2024 and 2025 appear in a new conference pool in 2025 with only prior-based estimates. The model must handle this gracefully via SP+ and EPA priors.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Feature Contribution Checks

### FEAT-01 — Close-game EPA anchor pair — direction

**Threshold:** Posterior mean coefficient for close_game_epa_per_play is positive. Posterior mean coefficient for close_game_def_epa_per_play is negative. Both 94% HDI exclude zero.

**Pass condition:**

```
close_game_off_epa_coef > 0 with 94% HDI excluding zero and close_game_def_epa_coef < 0 with 94% HDI excluding zero
```

**Notes:** EDA anchor: off EPA r = +0.5988 with point_differential, def EPA r = -0.6134. If either coefficient is in the wrong direction, the model has a specification error. If either HDI includes zero, the feature is not contributing — investigate collinearity.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FEAT-02 — SP+ prior weight — present at game 1, not aggressively decayed

**Threshold:** Effective SP+ weight at conf game 1 >= 0.15 (partial r equivalent). Effective SP+ weight at conf games 9–12 >= 0.10. Weight does not drop below 0.10 at any point in the season arc.

**Pass condition:**

```
sp_weight_game_1 >= 0.15 and sp_weight_games_9_12 >= 0.10 and min(sp_weight_season_arc) >= 0.10
```

**Notes:** EDA finding (Day 9): SP+ partial r = 0.2240 at conf game 1 after EPA control. Games 9–12 r = 0.2609 — prior remains relevant throughout season. Do not aggressively down-weight SP+ as games accumulate. Measure effective weight via posterior sensitivity analysis or leave-one-out comparison.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FEAT-03 — Conference-specific features fire only in confirmed conferences

**Threshold:** Posterior mean coefficient for each conference-specific feature is meaningfully non-zero (94% HDI excludes zero) only in the conferences where EDA confirmed signal

**Pass condition:**

```
Conference-specific features do not show strong posterior weight in conferences where EDA found null signal
```

**Notes:** Examples: last3_off_epa_avg confirmed in ACC, Conference USA, Mid-American, Mountain West, SEC — not in American Athletic, Big 12, Big Ten, Pac-12, Sun Belt. days_since_last_game confirmed in American Athletic and Big 12 only. If a feature fires broadly in non-confirmed conferences, the conference-level pooling structure is not correctly specified.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FEAT-04 — Threshold-activated features activate correctly

**Threshold:** Elevation, travel, and timezone features show near-zero posterior contribution in games below their respective thresholds and meaningfully non-zero contribution above thresholds

**Pass condition:**

```
Below-threshold posterior contribution indistinguishable from zero. Above-threshold posterior contribution 94% HDI excludes zero.
```

**Notes:** Thresholds: elevation >= 2000ft, travel >= 1500mi, timezone abs >= 2hr, wind_chill <= 25°F. These are modeled as indicator×magnitude interactions. Verify the indicator is correctly coded — a linear specification would spread signal across the full range and dilute the threshold effect.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FEAT-05 — Recruiting prior — Sun Belt direction check

**Threshold:** Posterior mean recruiting prior weight for Sun Belt is <= 0 or recruiting is excluded from the Sun Belt prior entirely

**Pass condition:**

```
Sun Belt recruiting prior weight is non-positive or feature is correctly excluded for Sun Belt
```

**Notes:** EDA finding (Day 9): Sun Belt rec↔diff_r = -0.2665. Recruiting is negatively correlated with outcomes in Sun Belt. Using it as a positive prior signal in Sun Belt is a specification error. Either exclude recruiting from the Sun Belt prior or allow the conference-specific weight to be negative.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Known Failure Modes

### FAIL-01 — Conf game 1 without rolling features — graceful handling

**Threshold:** No null predictions at conf game 1. Model produces a complete score distribution for every game in the holdout set regardless of rolling feature availability.

**Pass condition:**

```
Zero null or degenerate predictions (point mass, infinite variance) at conf game 1 in the 2025 holdout
```

**Notes:** Rolling features are null at conf game 1. Null handling strategy: Approach A — impute with season-to-date prior (locked decision). Verify imputation is correctly applied and that the model does not silently propagate nulls into the likelihood.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FAIL-02 — G5 teams with thin data — reasonable estimates

**Threshold:** No G5 team with <= 10 training games produces a posterior mean score more than 20 points from its conference mean

**Pass condition:**

```
max(abs(thin_g5_team_posterior_mean - conference_mean)) <= 20.0
```

**Notes:** Conference-level pooling should pull thin-data teams toward the conference mean. A team with 3–5 training games should not receive extreme posterior estimates. If it does, the pooling hyperprior is too weak or the team-level variance is too high.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FAIL-03 — Cross-tier matchups — no extreme miscalibration

**Threshold:** No cross-tier game produces a posterior win probability outside the range 0.05–0.98 for the stronger team. Mean absolute calibration error for cross-tier games <= 0.10.

**Pass condition:**

```
All cross-tier posterior win probabilities within 0.05–0.98 and cross_tier_mean_calibration_error <= 0.10
```

**Notes:** Win probabilities of 0.99+ or 0.01- are computationally generated certainty that CFB does not support. Even the most extreme mismatches carry upset probability. Hard-code a floor/ceiling if necessary, but investigate the root cause — this usually indicates the team-level attack/defense parameters are diverging.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

### FAIL-04 — Sun Belt recruiting prior direction

**Threshold:** See FEAT-05

**Pass condition:**

```
See FEAT-05
```

**Notes:** Duplicate gate: Sun Belt recruiting prior direction is critical enough to check from both the feature contribution angle (FEAT-05) and the known failure mode angle (FAIL-04). Day 33 must check both items and document that both were reviewed.

**Day 33 result:** ☐ PASS &nbsp;&nbsp; ☐ FAIL &nbsp;&nbsp; ☐ EXCEPTION

**Day 33 notes:**

> *(record finding here)*

---

## Sign-Off

All 39 items must be marked PASS or EXCEPTION before sign-off is granted. An EXCEPTION requires an explicit written justification explaining why the failure does not disqualify the model from production use. Undocumented failures are not exceptions — they are failures.

| Field | Value |
|---|---|
| Items passed | |
| Items failed | |
| Documented exceptions | |
| Sign-off granted | ☐ YES &nbsp; ☐ NO |
| Signed off by | |
| Sign-off date | |
| Notebook | `model_14_signoff.ipynb` |
