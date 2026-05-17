# Ambiguity Resolution — Day 19

Five features finished EDA with open questions. Each receives a binding binary
decision below. These decisions are encoded in master_verdict.csv and
final_features.csv. They are final — no further deliberation in model build.

---

## Ambiguity 1 — close_game_play_count_delta

**Question:** Include as conference-specific spread feature for the 6 confirmed
conferences, or exclude on complexity grounds?

**Decision: INCLUDE**

**Justification:** Spread partial r=0.1834 full population (p<0.0001); holds from
conf game 1 (r=0.1676); confirmed in ACC, American Athletic, Big 12, Mid-American,
Pac-12, Sun Belt. Signal is not tautological (raw r=0.2256). The conference scope
is explicit and the feature is available at all information states. Complexity cost
is low — one additional feature with a known conference allowlist.

**Scope:** ACC, American Athletic, Big 12, Mid-American, Pac-12, Sun Belt only.
Not applied in Big Ten, Conference USA, Mountain West, or SEC.

---

## Ambiguity 2 — Style archetype matchup features

**Question:** Include as game-level O/U features with a deployable pregame version
requirement, or exclude until a pregame version is tested?

**Decision: INCLUDE** (with condition)

**Justification:** O/U signal is the strongest EDA 10 finding — eta² = 0.39 for
defense matchup, 0.37 for offense matchup. Signal held broadly across tiers,
seasons, and conferences. The in-game version cannot be used in production directly,
but the signal magnitude justifies retaining the features with an explicit condition:
a deployable pregame or rolling version must be tested before the model goes live.
If no pregame version clears signal tests, these features are dropped at that stage.

**Condition:** Deployable pregame version required before September 24, 2026
production launch. Features flagged for pregame version development in model build.

**Scope:** All four matchup features included (offense_archetype_matchup,
defense_archetype_matchup, home_off_vs_away_def_matchup,
away_off_vs_home_def_matchup). O/U signal only. Not used for spread or
moneyline variance.

---

## Ambiguity 3 — last3_off_epa_avg and last3_def_epa_avg conference lists

**Question:** Include as conference-specific features with explicit conference
lists, or consolidate into a single rolling EPA feature and let conference-level
pooling handle the variation?

**Decision: INCLUDE with explicit conference lists**

**Justification:** The conference-specific signal is real and the lists are
different for offense and defense — consolidating would lose that structure.
Conference-level pooling regularizes within-conference variation but does not
substitute for the binary include/exclude signal difference between conferences.
The explicit lists are: last3_off_epa_avg → ACC, Mid-American, SEC;
last3_def_epa_avg → American Athletic, Big Ten, Conference USA, Mid-American,
Pac-12, Sun Belt. Both are null at conf game 1 and handled by null_handling =
impute_season_prior.

---

## Ambiguity 4 — rush_rate_std_downs and rush_rate_pass_downs as prior seeds

**Question:** Include as weak prior seeds (YoY r = 0.4890 and 0.4648) or exclude
on grounds that YoY stability below 0.5 is insufficient for a prior seed role?

**Decision: EXCLUDE as prior seeds**

**Justification:** YoY r below 0.5 is insufficient to seed a prior — the signal
is too unstable to anchor a parameter before any in-season data arrives. Both
features are retained as game-level supporting predictors (spread signal confirmed
in Day 15), but they do not receive prior_seed role and do not contribute to prior
specification. Their in-game signal is captured through the game-level feature
pathway, not through prior seeding.

---

## Ambiguity 5 — elo_sp_divergence

**Question:** Include as game-level predictor computed in notebook, or exclude
until model confirms value?

**Decision: INCLUDE** (computed in notebook)

**Justification:** Spread r=0.1650 after SP+ controlled — ELO adds signal beyond
SP+ for spread prediction. The compute-in-notebook-first constraint is already a
locked decision. Including it here means Day 20 writes a prior for it and the model
build tests it. If it fails to improve the model, it is dropped in refinement
(Day 31). Excluding it now would mean losing a confirmed signal without testing it
in the model. The cost of including a weak feature is lower than the cost of
prematurely excluding a confirmed one.
