cat > ~/cfb-analytics/docs/session_state.md << 'EOF'
# CFB Analytics — Session State

## Last Updated
2026-04-29

## Project Goal
Hierarchical Negative Binomial model predicting score distributions for FBS college football games.
Outputs: win probability, spread, moneyline, over/under via Monte Carlo simulation.
Goes live: September 24, 2026 — Liberty vs Coastal Carolina.

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team (to be confirmed Day 10)
- Likelihood: Negative Binomial (confirmed Day 6)
- Model form: points ~ NegBinom(mu, r), log(mu) = team_attack + opponent_defense + home_advantage + ...
- Dispersion parameter r ~ HalfNormal(), fit from data — should be allowed to vary by conference given VMR range 5.2–8.1
- Priors seeded from: SP+ preseason rating, 3-year recruiting composite, transfer portal net, NIL proxy
- Conference-level pooling handles small sample size (12 games/team)
- Environmental adjusters: elevation, travel distance, timezone shift, kickoff time
- Built in PyMC

## EDA Phase — Days 6–14
| Day | Notebook | Status | Decision Produced |
|---|---|---|---|
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed across all 40 conference-season cells, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 152 candidate features locked in candidate_features.csv |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | Game-level close-game EPA pair is joint model anchor; season-level EPA anchors priors; off YoY r=0.423, def YoY r=0.393 — priors should be wider |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.761; recruiting supporting but collapses at G5 — requires tier-aware treatment |
| 10 | eda_05_hierarchy_structure.ipynb | ❌ not built | Variance decomposition between vs within conferences; confirm three-level hierarchy |
| 11 | eda_06_environmental_features.ipynb | ❌ not built | Which environmental features have empirical support |
| 12 | eda_07_momentum_rolling_features.ipynb | ❌ not built | Whether rolling features add signal beyond season averages |
| 13 | eda_08_game_script_close_games.ipynb | ❌ not built | Whether game script belongs in model and in what role |
| 14 | eda_09_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |

## What The Next Session Must Build
`notebooks/eda/eda_05_hierarchy_structure.ipynb` — Day 10

Questions to answer:
1. How much of the variance in scoring is between conferences vs within conferences?
2. Are there conferences where within-conference variance is so high that conference-level pooling adds little value?
3. Are there conferences that are outliers in ways that will dominate pooling?
4. Does a three-level hierarchy (league → conference → team) fit the actual variance structure, or does it need adjustment?

Decision this day produces: confirmation or adjustment of the hierarchy structure before the model is written.

## Key Findings From Completed Notebooks

### Day 6 — Scoring Distributions
- 2,835 FBS games, 2022–2025
- Home VMR 6.388, Away VMR 6.515, pooled VMR 6.627
- Every conference in every season is overdispersed — no exceptions
- Big Ten is most overdispersed (VMR 6.74–8.05), ACC is least (VMR 5.20–5.60)
- Pac-12 2025 VMR=3.56 is an outlier — post-realignment small n artifact, interpret cautiously

### Day 7 — Feature Inventory
- 235 total columns across 5 int tables
- 152 keep=True features
- 10 dropped: 7 join keys, 1 non-authoritative duplicate (win_pct), 2 derived (third_down_pct, fourth_down_pct)
- `close_game_def_epa_per_play` is NOT in candidate_features.csv — it was built in Day 8 as the defensive counterpart to close_game_epa_per_play

### Day 8 — EPA Deep Dive
- 12,007 game-level rows
- Season-level anchors (prior seeds): `off_epa_per_play` R²=0.779 vs avg points_scored, `def_epa_per_play` YoY r=0.393
- Game-level joint anchor pair: `close_game_epa_per_play` + `close_game_def_epa_per_play`, R²=0.772 jointly vs point_diff
- YoY stability: off r=0.423, def r=0.393 — both below 0.60 threshold, priors should be wider and less informative
- `def_epa_per_play_allowed` — redundant (|r|=0.971 with anchor pair, signal concentrated in blowouts)
- `last3_off_epa_avg` — redundant (residual |r|=0.086 ≤ 0.10)
- `last3_def_epa_avg` — redundant (residual |r|=0.054 ≤ 0.10)

### Day 9 — SP+ & Recruiting
- 533 team-seasons, 136 teams, 4 seasons (2022–2025)
- SP+ partial r=0.399 after partialling out EPA — well above 0.20 independence threshold
- EPA+SP+ joint R²=0.740 vs win_pct vs EPA alone 0.691 — meaningful 5-point gain
- SP+ YoY r=0.761, 95% CI [0.718, 0.803], n=397 — dramatically more stable than EPA
- SP+ verdict: anchor candidate
- Recruiting → win_pct R²=0.103 overall — barely clears 0.10 retention threshold
- Recruiting at P4: R²=0.085–0.140 across EPA and win_pct outcomes
- Recruiting at G5: R²=0.000–0.001 — collapses entirely
- Recruiting verdict: supporting, but signal is concentrated entirely in Power Four
- ⚠️ Recruiting cannot be used as a flat feature across the full FBS population — requires either a conference-tier interaction term or restriction to P4 games. Flagged for Day 10+ modeling decisions.

## Locked Decisions — Do Not Revisit
- Likelihood: Negative Binomial
- Elevation computation: earthdistance extension (not Python seed)
- Timezone: COALESCE(IANA timezone, state CASE) hybrid
- Momentum grain: game level (not season level)
- opp_sp_rating: prior year (season - 1) to prevent leakage
- field_position_margin: dropped
- havoc: always def_havoc_* columns, never off_havoc_*
- Weather dome override: temp=68, wind=0, precip=0 when is_dome=true
- D1 filter: FBS + FCS only via conference allowlist
- Notre Dame: Power Four
- UConn: Group of Five
- FCS-to-FBS transitions: excluded
- recruiting_3yr_avg: high school recruiting only

## P4/G5 Classification
- P4 conferences: ACC, Big 12, Big Ten, Pac-12, SEC
- Notre Dame → P4 (independent)
- UConn → G5
- All others → G5

## YoY Benchmarks
- off_epa_per_play YoY r = 0.423
- def_epa_per_play YoY r = 0.393
- sp_rating YoY r = 0.761, 95% CI [0.718, 0.803]

## Candidate Features
- Authoritative list: artifacts/candidate_features.csv
- Total features: 152
- Only keep=True columns are authorized for use in any notebook
- Do not reference any column not on this list
- Exception: close_game_def_epa_per_play was built in Day 8 and is an authorized anchor despite not being in candidate_features.csv

## Artifacts Written
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 152 features, keep=True only |
| artifacts/epa_feature_verdict.csv | ✅ valid | Day 8 output, 7 rows |
| artifacts/sp_recruiting_verdict.csv | ✅ valid | Day 9 output |

## Known Schema Facts — Use Exactly
- point_differential does not exist as a column — derive as points_scored - points_allowed
- Defensive EPA column is def_epa_per_play_allowed — not def_epa_per_play
- int_game_environment has home_team and away_team, not team_name — join on game_id only, then filter f.team_name IN (e.home_team, e.away_team)
- conference comes from int_team_season_context, joined on team_name and season
- All numeric columns from psycopg2 return as Decimal — cast entire numeric column list to float64 immediately after building the dataframe
- Connection: host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres

## Source Tables
- int.int_game_team_features — game-level team performance
- int.int_game_environment — game-level venue and weather
- int.int_team_season_context — season-level team context including conference

## Connection Pattern (psycopg2 only — no SQLAlchemy passed to pandas)
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

## Rules Every Session Must Follow
1. Read this file before touching anything else
2. Read artifacts/candidate_features.csv — only keep=True columns are authorized
3. Run schema introspection query before writing any SQL — never guess column names
4. Write complete cells only — never partial fixes or incremental edits
5. Use existing helpers — never redefine logic that already exists in the notebook
6. Cast all Decimal columns to float64 immediately after loading
7. Do not rewrite verified cells
8. Do not close the DB connection until the notebook is complete
9. If a required column is not in the schema output, stop and say so — do not proceed

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the EDA table with the decision they produced
3. Add any new locked decisions
4. Add key findings from the completed notebook to the findings section
5. Update what the next session must build
6. Commit: git add docs/session_state.md && git commit -m "docs: update session state after Day X" && git push
EOF