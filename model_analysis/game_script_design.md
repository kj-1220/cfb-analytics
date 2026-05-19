# Game Script — Locked Design and EDA 4 Planning
*Recorded May 18, 2026 — pre-EDA 2 coding session*

---

## Background and Motivation

Game script features are derived from `raw.plays` using the score differential at the time
of each play. They capture how teams behave and perform under different competitive
pressures — information that season-level aggregates obscure by mixing together plays
from blowouts, close games, and deficit situations.

**Two distinct layers:**

- **Distribution layer** — how much time does each team spend in each game script bucket.
  This is a team identity characteristic independent of how they perform within each bucket.
- **Performance layer** — EPA per play, rush rate within each bucket. Measures execution
  quality conditional on the situation.

**Key design principle:** College football thresholds are wider than NFL equivalents.
Scoring is lower on average, games stay closer longer, and the talent gap between
conference opponents is wider. Thresholds calibrated accordingly.

---

## Bucket Definitions

| Bucket | Score differential at time of play |
|---|---|
| Neutral | Within ±10 |
| Ahead | Leading 11–20 |
| Blowout lead | Leading 21+ |
| Behind | Trailing 11–20 |
| Blowout deficit | Trailing 21+ |

**Garbage time filter:** Leading 28+ in Q4. Plays meeting this definition are excluded
from all bucket calculations. Not a feature bucket — a filter only.

Score differential is defined from the perspective of the team whose features are being
computed. Positive = leading, negative = trailing.

---

## Metrics Computed Per Bucket

| Metric | Neutral | Ahead | Blowout lead | Behind | Blowout deficit |
|---|---|---|---|---|---|
| Play count | ✓ | ✓ | ✓ | ✓ | ✓ |
| EPA per play (off) | ✓ | ✓ | — | ✓ | ✓ |
| EPA per play (def) | ✓ | ✓ | — | ✓ | ✓ |
| Rush rate | ✓ | ✓ | ✓ | ✓ | ✓ |
| Pct of total plays | ✓ | ✓ | ✓ | ✓ | ✓ |

EPA excluded from blowout lead — too contaminated by personnel and motivation decisions
to be a clean signal. Rush rate retained because it captures game management and personnel
decisions that are themselves informative.

---

## Why Garbage Time Matters for Total Points

Early blowouts inflate total points through garbage time scoring against depleted defenses.
A game ending 59-21 where the blowout was established by halftime is not the same scoring
environment as a game ending 59-21 because both offenses were genuinely explosive for four
quarters. The garbage time filter (leading 28+ in Q4) excludes plays from the period where
winning teams deploy backups and losing teams accumulate low-value passing yards against
prevent coverage. This is the primary mechanism by which game script features become
contaminated for total points prediction.

---

## Season-Level Feature

**`gs_neutral_pct_volatility`** — standard deviation of neutral-play percentage across
games within a season. One value per team-season. Written to `int_team_season_features`.

Captures whether a team consistently plays in contested games or swings between blowout
and deficit situations across their schedule. Strong prior for the total model — teams
involved in high-variance scoring environments have systematically different total points
distributions than teams that grind out close games every week.

---

## CTD Construction

All per-game metrics aggregated to cumulative averages through the prior game in the
season. Game N uses the average of Games 1 through N-1. Identical CTD pattern used
for all other rolling features in this build.

Week 5 is the first game in the prediction window. Teams will have 1–4 prior games
of CTD data at that point depending on bye weeks and schedule. Expected and consistent
with all other CTD features — the prior carries more weight when CTD sample is thin,
which is the intended Bayesian behavior.

---

## Schema Destination

### `int_game_team_features` — CTD columns (gs_ prefix)

```
gs_neutral_plays_ctd
gs_neutral_off_epa_ctd
gs_neutral_def_epa_ctd
gs_neutral_rush_rate_ctd
gs_neutral_pct_ctd

gs_ahead_plays_ctd
gs_ahead_off_epa_ctd
gs_ahead_def_epa_ctd
gs_ahead_rush_rate_ctd
gs_ahead_pct_ctd

gs_blowout_lead_plays_ctd
gs_blowout_lead_rush_rate_ctd
gs_blowout_lead_pct_ctd

gs_behind_plays_ctd
gs_behind_off_epa_ctd
gs_behind_def_epa_ctd
gs_behind_rush_rate_ctd
gs_behind_pct_ctd

gs_blowout_deficit_plays_ctd
gs_blowout_deficit_off_epa_ctd
gs_blowout_deficit_def_epa_ctd
gs_blowout_deficit_rush_rate_ctd
gs_blowout_deficit_pct_ctd
```

### `int_team_season_features` — season-level

```
gs_neutral_pct_volatility
```

---

## Candidate Feature Flags for candidate_features.csv

| Feature group | Prior strength | Primary target | Notes |
|---|---|---|---|
| Neutral-script EPA (off + def) | Standard | Spread + total | Cleanest game script signal. Total prior moderate due to scoring environment correlation. |
| Neutral rush rate | Standard | Spread + total | Playcalling identity. Cleaner for total than EPA-based features. |
| Neutral pct | Standard | Total primarily | Distribution layer. Clean causal story for total. |
| Ahead/behind EPA | Standard | Spread primarily | Execution under competitive pressure. Weaker total prior. |
| Ahead/behind rush rate | Standard | Spread primarily | Play calling adjustment. |
| Blowout lead/deficit rush rate | Standard | Spread primarily | Personnel and game management signal. |
| Blowout lead/deficit pct | Standard | Total primarily | How often team is in non-competitive territory. |
| Distribution pcts (all buckets) | Standard | Total primarily | Cleanest game script signal for total model. |
| gs_neutral_pct_volatility | Standard | Total primarily | Schedule variance proxy. Strong total prior. |
| Blowout lead/deficit EPA | Low prior | Spread only | Excluded from blowout lead. Contaminated by personnel in deficit. |

---

## What Is Explicitly Deferred

- **Clustering on game script distribution** — deferred to post-EDA 4. If distribution
  percentage features show strong signal, clustering becomes a motivated decision backed
  by evidence. Building it now is speculative architecture.
- **Delta features between buckets** — e.g. neutral EPA minus behind EPA as a measure
  of execution drop-off under pressure. Deferred to EDA 4. Build only if bucket-level
  features show signal worth refining.
- **Interaction terms between script buckets and style archetypes** — deferred to EDA Final.
- **Any total-model-specific game script features beyond what is listed** — EDA 4 decides.

---

## EDA 4 — Game Script Testing Plan

*These are the questions EDA 4 must answer for game script features specifically.
EDA 4 structure is not fully planned until EDA 2 inventory is complete — this section
records the game script questions so they are not lost.*

### Core signal questions

**1. Does neutral-script EPA outperform overall EPA?**
Test partial correlation of `gs_neutral_off_epa_ctd` vs `off_epa_per_play` (overall)
against point differential and total points separately. If neutral-script EPA adds
no signal over overall EPA, the additional construction complexity is not justified.
This is the most important test for the entire game script feature family.

**2. Do the bucket-specific EPAs have independent signal beyond neutral?**
After controlling for neutral-script EPA, do behind-script EPA or ahead-script EPA
add predictive value for spread? This tests whether execution under specific pressures
captures something beyond general quality.

**3. Do distribution percentages predict total points independently?**
Test `gs_neutral_pct_ctd`, `gs_blowout_lead_pct_ctd`, `gs_blowout_deficit_pct_ctd`
against total points. The hypothesis is that teams involved in more blowouts (either
direction) have systematically different total points distributions. This is the
cleanest game script signal for the total model.

**4. Does `gs_neutral_pct_volatility` predict total points?**
Teams with high volatility in how contested their games are should have wider total
points distributions. Test as a direct predictor and as a moderating variable.

**5. Is there a season segment interaction?**
Game script features derived from early-season games (weeks 1-4, pre-prediction window)
may be less stable than those derived from mid-season conference play. Test whether
CTD game script features have stronger signal in late-season weeks than early-season
weeks, consistent with the EDA 3 season segment boundary findings.

### Garbage time validation

**6. Does excluding garbage time plays change the signal?**
Compare feature values computed with and without the garbage time filter for a sample
of games. Verify that the filter meaningfully changes values for teams with frequent
blowouts and has minimal effect for teams that play close games throughout. This
validates that the filter is doing real work and not just reducing sample size.

### Clustering decision gate

**7. If distribution percentage features show signal — does clustering add anything?**
Only reached if Question 3 returns positive. Run KMeans on the five distribution
percentage features (pct of plays in each bucket). Test whether cluster membership
has predictive signal beyond the raw percentages. If yes, clusters enter the candidate
list. If no, raw percentages are sufficient and clustering is not pursued.

### Decision outputs EDA 4 must produce for game script

For each feature tested, the standard EDA 4 output applies:

- Signal vs point differential: partial r, conference scope, season segment breakdown
- Signal vs total points: partial r, conference scope, season segment breakdown
- YoY stability: stable enough to be a prior seed, a game-level predictor, or neither
- Verdict: include / exclude / conditional, with full justification from output

Additionally for game script specifically:
- Whether neutral-script features replace or supplement overall EPA features
- Whether the behind/ahead buckets add signal worth the schema complexity
- Whether clustering on distribution is warranted
- Whether any delta features (e.g. neutral minus behind EPA) should be built before EDA Final

---

## Implementation Note for EDA 2 Coding Session

Build Phase 1 only. No clustering, no delta features, no interaction terms.

**Source:** `raw.plays` — score differential at time of play, EPA, play type (run/pass),
down and distance for down-type classification.

**Join path:** `raw.plays` → `raw.games` for game metadata → `int_team_season_features`
for conference filters. Both teams must pass full rebuild pool filter.

**Output:** 24 CTD columns in `int_game_team_features` + 1 season-level column in
`int_team_season_features`. Full rebuild pool filter applied. All assertions scoped
to rebuild pool (3,458 team-rows), never against full table.