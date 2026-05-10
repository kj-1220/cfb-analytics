# Prior Specification Draft — Day 19

This document specifies every prior distribution the hierarchical Negative Binomial
model will use. It is not PyMC code. Day 20 (model_01_prior_specification.ipynb)
translates this into PyMC code. Every prior is traceable to a YoY r value, partial r,
or named EDA finding. No prior may be invented in Day 20 without a corresponding
entry here.

---

## 1. League-Level Priors

### 1.1 Intercept (league baseline scoring)
- **Parameter:** mu_league
- **Distribution:** Normal
- **Mean:** 27.0
- **SD:** 5.0
- **Type:** Weakly informative
- **Justification:** FBS mean points scored per team per game 2022–2024 is
  approximately 27. SD of 5 allows the posterior to move freely while ruling
  out implausible baselines (e.g. 0 or 60 points).

### 1.2 Home field advantage baseline
- **Parameter:** hfa_league
- **Distribution:** Normal
- **Mean:** 2.5
- **SD:** 1.5
- **Type:** Informative
- **Justification:** Day 10 confirmed league-level HFA = +2.48 points (p<0.001).
  Prior centered at 2.5 with SD 1.5 encodes this finding while allowing the
  posterior to update. No conference-level HFA layer — team-level deviations
  handle within-conference variation (team HFA SD = 4.85 pts confirmed Day 10).

### 1.3 Dispersion parameter r
- **Parameter:** r_negbinom
- **Distribution:** HalfNormal
- **SD:** 5.0
- **Type:** Weakly informative
- **Justification:** Day 6 confirmed VMR range 4.95–7.16 (ratio 1.447), below
  the 1.5 threshold for conference-specific dispersion. Start with a single
  league-level r. Add conference-specific r only if posterior predictive checks
  show systematic miscalibration by conference. HalfNormal constrains r > 0.

---

## 2. Conference-Level Priors

### 2.1 Conference scoring offset hyperprior
- **Parameter:** mu_conference[c] for each conference c
- **Distribution:** Normal, centered on league intercept
- **Mean:** 0.0 (offset from league baseline)
- **SD hyperprior:** HalfNormal(SD=3.0)
- **Type:** Weakly informative
- **Justification:** Day 10 confirmed conference ICC is marginal (0.02–0.05)
  but pooling still improves small-sample estimates. Hyperprior SD of 3.0
  allows realistic conference-level scoring differences while regularizing
  toward the league mean.

### 2.2 Conference-level home field deviation
- **Decision:** Not modeled as a separate layer.
- **Justification:** Day 10 found conference HFA range of 4.19 pts but team-level
  HFA SD of 4.85 pts absorbs this variation. A conference-level HFA layer is not
  justified given marginal conference ICC.

### 2.3 Conference-specific feature weights
- Features with conference_scope restrictions (see final_features.csv) receive
  zero weight outside their confirmed conference list. This is implemented as a
  conference membership indicator multiplied by the feature coefficient, not as
  a separate prior layer.

---

## 3. Team-Level Priors

### 3.1 Team attack parameter
- **Parameter:** alpha_team[t] (log-scale offensive strength)
- **Distribution:** Normal, centered on conference mean
- **Mean:** 0.0 (offset from conference baseline)
- **SD hyperprior:** HalfNormal(SD=0.4)
- **Type:** Weakly informative
- **Justification:** Day 10 team ICC for points_scored = 0.1394 — substantial,
  justifies team-level parameters. YoY r for raw scoring = 0.35–0.49, too
  unstable to use directly; prior is anchored by SP+ and EPA instead.

### 3.2 Team defense parameter
- **Parameter:** delta_team[t] (log-scale defensive strength, points allowed)
- **Distribution:** Normal, centered on conference mean
- **Mean:** 0.0 (offset from conference baseline)
- **SD hyperprior:** HalfNormal(SD=0.4)
- **Type:** Weakly informative
- **Justification:** Symmetric with attack parameter. Day 10 team ICC for
  point_differential = 0.1925 — strongest ICC finding, justifies separate
  attack and defense parameters.

### 3.3 Team home field deviation
- **Parameter:** hfa_team[t]
- **Distribution:** Normal, centered on league HFA
- **Mean:** 0.0 (deviation from league hfa_league)
- **SD hyperprior:** HalfNormal(SD=2.0)
- **Type:** Weakly informative
- **Justification:** Day 10 team HFA SD = 4.85 pts. Hyperprior SD of 2.0 on
  the log scale allows substantial team-level variation while regularizing
  sparse teams toward the league baseline.

### 3.4 SP+ prior seed
- **Parameter:** sp_weight (coefficient on SP+ rating)
- **Distribution:** Normal
- **Mean:** 0.0
- **SD:** 1.0
- **Type:** Informative
- **Justification:** YoY r = 0.7740 — strong stability. Prior decay confirmed:
  spread partial r = 0.2240 at conf game 1, does not decay monotonically
  (games 9-12 r = 0.2609). Do not aggressively down-weight as games accumulate.
  SP+ components (sp_offense, sp_defense) excluded — less stable than composite.
- **Conference variation:** American Athletic and Mid-American show strongest
  SP+ signal at game 1 (r > 0.40). Conference USA and Pac-12 have insufficient
  sample at game 1 — use league-level weight for those.

### 3.5 Recruiting prior seed
- **Parameter:** rec_weight[c] (conference-specific coefficient on recruiting_3yr_avg)
- **Distribution:** Normal
- **Mean:** 0.0
- **SD:** 0.5
- **Type:** Informative
- **Justification:** YoY r = 0.9779 — extremely stable. Prior weight is
  conference-specific:
  - Big Ten: moderate weight (rec↔sp_r = 0.7456, rec↔diff_r = 0.6601)
  - SEC: moderate weight (rec↔sp_r = 0.6730, rec↔diff_r = 0.6153)
  - All other conferences: low weight
  - Sun Belt: weight must be non-positive (rec↔diff_r = -0.2665). Recruiting
    composite does not predict positive outcomes in Sun Belt — using it as a
    positive prior signal would introduce systematic error. This is a hard
    constraint and appears as a checklist item in evaluation_checklist.md.

---

## 4. Game-Level Feature Priors

### 4.1 Close-game EPA anchor pair
- **Features:** close_game_epa_per_play, close_game_def_epa_per_play
- **Distribution:** Normal(0, 0.5) each
- **Type:** Weakly informative
- **Justification:** Joint model anchors. Spread partial r = 0.5988 and -0.6134
  at conf game 1. O/U partial r = 0.4237 and 0.4473. YoY r = 0.4331 and 0.4224.
  Signal holds across full season trajectory. SD of 0.5 allows substantial effect
  while ruling out implausible coefficients.

### 4.2 Pregame ELO
- **Feature:** pregame_elo
- **Distribution:** Normal(0, 0.3)
- **Type:** Weakly informative
- **Justification:** Spread partial r = 0.1702; holds at conf game 1 (r = 0.1870).
  YoY r = 0.8452 — highly stable game-level predictor. Spread signal only; O/U
  signal absent.

### 4.3 ELO/SP+ divergence
- **Feature:** elo_sp_divergence
- **Distribution:** Normal(0, 0.2)
- **Type:** Weakly informative
- **Justification:** Spread r = 0.1650 after SP+ controlled. Smaller SD than
  pregame_elo because this is an interaction-style feature capturing disagreement
  between two rating systems. Computed in notebook; add to dbt only after model
  confirms value. (Ambiguity 5 resolved: include.)

### 4.4 Rolling momentum features
- **Features:** last3_win_pct, last3_off_epa_avg, last3_def_epa_avg,
  last3_points_scored_avg, last3_points_allowed_avg
- **Distribution:** Normal(0, 0.3) each
- **Type:** Weakly informative
- **Justification:** Conference-specific spread signal from conf game 2. Null at
  conf game 1 — handled by null_handling = impute_season_prior (replace with
  season-to-date average, consistent with Approach A early-season null handling
  confirmed as locked decision).
- **Conference scope:** Applied only within confirmed conference lists per
  final_features.csv. last3_win_pct applied across all conferences.

### 4.5 Environmental features (threshold-activated)
- **Features:** away_elevation_delta_ft, away_travel_distance_mi, away_tz_delta_hrs,
  wind_chill
- **Distribution:** Normal(0, 0.3) for elevation/travel/timezone;
  Normal(0, 0.2) for wind_chill
- **Type:** Weakly informative
- **Justification:** All are threshold-activated — signal only emerges above
  specific thresholds. Modeled as indicator×magnitude interaction:
  - away_elevation_delta_ft: active when delta >= 2000 ft (YoY r = 0.8255)
  - away_travel_distance_mi: active when distance >= 1500 mi (YoY r = 0.6562)
  - away_tz_delta_hrs: active when abs(delta) >= 2 hr (YoY r = 0.6710);
    direction negative
  - wind_chill: active when <= 40°F and NOT is_dome; O/U signal only
  When threshold not met, feature value = 0 (null_handling = zero).

### 4.6 Style/tempo delta features
- **Features:** rush_rate_std_downs_delta, rush_rate_pass_downs_delta,
  off_pts_per_opportunity_delta, def_pts_per_opportunity_allowed_delta,
  off_success_rate_pass_delta, def_success_rate_pass_allowed_delta,
  off_epa_pass_delta, def_epa_pass_allowed_delta
- **Distribution:** Normal(0, 0.3) each
- **Type:** Weakly informative
- **Justification:** Spread signal confirmed in Day 15 at game level. Rush tendency
  (rush_rate_std_downs_delta) is the most consistent — holds across all season
  buckets including game 1 (r = 0.2965–0.3628). Pass efficiency deltas confirmed.
  YoY stability insufficient for prior seeding (best r = 0.4890 for
  rush_rate_std_downs); treated as game-level predictors only.

### 4.7 Sack-rate mismatch features (moneyline variance)
- **Features:** off_sack_rate_allowed_delta, def_sack_rate_delta
- **Distribution:** Normal(0, 0.2)
- **Type:** Weakly informative
- **Justification:** Moneyline variance candidates. Abs residual variance partial
  r = ±0.0919. Smaller SD than spread features — weaker signal, more regularization
  needed. These affect the dispersion component of the model, not the mean.

### 4.8 Style archetype matchup features
- **Features:** offense_archetype_matchup, defense_archetype_matchup,
  home_off_vs_away_def_matchup, away_off_vs_home_def_matchup
- **Distribution:** Normal(0, 0.3) each
- **Type:** Weakly informative
- **Justification:** O/U signal confirmed — strongest EDA 10 finding (eta² up to
  0.39). Weak secondary spread signal. Not valid for moneyline variance. Not stable
  for prior seeding (offense retention 0.26–0.35 YoY, defense 0.25–0.40 YoY).
  (Ambiguity 2 resolved: include with deployable pregame version requirement.)
- **CONDITION:** Deployable pregame or rolling version must be tested before
  September 24, 2026 production launch. If no pregame version clears signal tests,
  these four features are dropped at that stage.

### 4.9 Days since last game (bye week)
- **Feature:** days_since_last_game
- **Distribution:** Normal(0, 0.2)
- **Type:** Weakly informative
- **Justification:** Bye week signal (>= 12 days) in American Athletic and Big 12
  only. Threshold-activated; zero outside confirmed conferences.
- **Conference scope:** American Athletic, Big 12 only.

### 4.10 Rolling EPA conference-specific features
- **Features:** last3_off_epa_avg, last3_def_epa_avg (repeated here for clarity
  on conference scope)
- **Distribution:** Normal(0, 0.3) each
- **Conference scope:**
  - last3_off_epa_avg: ACC, Mid-American, SEC
  - last3_def_epa_avg: American Athletic, Big Ten, Conference USA,
    Mid-American, Pac-12, Sun Belt
- **Justification:** Conference lists differ between offense and defense —
  do not consolidate. (Ambiguity 3 resolved: include with explicit lists.)

---

## Summary: Parameter Count

| Layer          | Parameters                                      | Count |
|----------------|-------------------------------------------------|-------|
| League         | mu_league, hfa_league, r_negbinom               | 3     |
| Conference     | mu_conference[c] × 10 conferences               | 10    |
| Team           | alpha_team[t], delta_team[t], hfa_team[t],      |       |
|                | sp_weight, rec_weight[c]                        | 3N+1+10|
| Game-level     | 23 feature coefficients (see final_features.csv)| 23    |

N = number of teams in training data (approximately 130 FBS teams × 3 seasons).

---

## Day 20 Instructions

1. Translate every prior above into a `pm.` distribution call.
2. Every parameter must have a comment citing this document and the EDA finding.
3. Do not invent priors. If a parameter is not listed here, stop and flag it.
4. Conference-specific feature weights are implemented as coefficient × conference
   indicator — do not create separate conference-level coefficient distributions
   for game-level features unless the prior specification explicitly calls for it.
5. Sun Belt recruiting weight must be non-positive. Implement as a constraint or
   as a separate non-positive prior for that conference's recruiting coefficient.
