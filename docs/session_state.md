cat > ~/cfb-analytics/docs/session_state.md << 'EOF'
# CFB Analytics — Session State

## Last Updated
2026-04-29

## Project Goal
Hierarchical Negative Binomial model predicting score distributions for FBS college football games.
Outputs: win probability, spread, moneyline, over/under via Monte Carlo simulation.
Goes live: September 24, 2026 — Liberty vs Coastal Carolina.

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team (confirmed Day 10 — needs re-validation after data fix)
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
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete — unaffected by data fix | Negative Binomial likelihood — overdispersion confirmed across all 40 conference-season cells, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ⚠️ needs re-run | candidate_features.csv must be regenerated against fixed conference data |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ likely unaffected — confirm | EPA does not use conference directly — re-run to confirm findings unchanged |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ⚠️ needs re-run | G5 recruiting collapse finding may change — Pac-12 teams were misclassified as P4 in 2022-2023 |
| 10 | eda_05_hierarchy_structure.ipynb | ⚠️ needs re-run | ICC numbers, tier splits, conference means all based on wrong assignments |
| 11 | eda_06_environmental_features.ipynb | ❌ not built | Which environmental features have empirical support |
| 12 | eda_07_momentum_rolling_features.ipynb | ❌ not built | Whether rolling features add signal beyond season averages |
| 13 | eda_08_game_script_close_games.ipynb | ❌ not built | Whether game script belongs in model and in what role |
| 14 | eda_09_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |

## Re-Run Order (mandatory before proceeding to Day 11)
1. EDA 2 — regenerate candidate_features.csv
2. EDA 4 — re-evaluate recruiting G5 collapse with correct Pac-12 classification
3. EDA 5 — recompute ICC, tier splits, conference means
4. EDA 3 — confirm EPA findings unchanged (conference not used directly)

## What The Next Session Must Do
1. Read this file
2. Re-run notebooks in the order above
3. Compare findings to prior results — flag any that changed materially
4. Only proceed to Day 11 once all re-runs are confirmed clean

## Data Fix Applied — 2026-04-29
**Problem:** `int_team_season_features` was assigning conference from a static snapshot of current team membership (`stg_teams`) rather than historically accurate season-by-season membership. This caused teams like Oregon, USC, UCLA, and Washington to show Big Ten for 2022 and 2023 when they were actually playing in the Pac-12 those seasons. Similarly, Arizona, Arizona State, Colorado, and Utah showed Big 12 for 2022-2023 instead of Pac-12.

**Root cause:** The spine CTE in `int_team_season_features.sql` joined `stg_teams` on `team_name` only with no season condition.

**Fix:** Added `team_seasons_conf` and `conf_by_season` CTEs that derive conference from `stg_games.home_conference` and `away_conference` — recorded at game time, historically accurate by season. Conference is now joined on both `team_name` and `season`.

**Verified:** Oregon shows Pac-12 for 2022-2023 and Big Ten for 2024-2025. Full dbt run PASS=14, dbt test PASS=12, zero errors.

**Committed:** `fix: derive conference from game records by season, not static team snapshot`

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
- Notre Dame: Power Four — route by team name not conference label
- UConn: Group of Five — route by team name not conference label
- FCS-to-FBS transitions: excluded
- recruiting_3yr_avg: high school recruiting only
- Conference assignment: historically accurate by season from game records — not static team snapshot
- Pac-12 in dataset: G5 for all seasons — the teams in raw data were never the real Pac-12 (Boise State, Fresno State, Colorado State, San Diego State, Utah State, Texas State, Oregon State, Washington State)
- FBS Independents: not a pooling group — Notre Dame routes to P4, UConn routes to G5 by team name
- No tiers within conferences: team-level parameters handle within-conference spread naturally

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

Pac-12 falls through to G5. FBS Independents handled by team name conditions. All other teams evaluated on actual season-accurate conference membership.

## Key Findings From Completed Notebooks (pre-fix — re-validate on re-run)

### Day 6 — Scoring Distributions (unaffected)
- 2,835 FBS games, 2022–2025
- Home VMR 6.388, Away VMR 6.515, pooled VMR 6.627
- Every conference in every season is overdispersed — no exceptions
- Big Ten most overdispersed (VMR 6.74–8.05), ACC least (VMR 5.20–5.60)
- Pac-12 2025 VMR=3.56 outlier — post-realignment small n artifact
- Decision locked: Negative Binomial

### Day 7 — Feature Inventory (re-run required)
- 152 keep=True features — count expected to hold, verify after re-run
- 10 dropped: 7 join keys, 1 non-authoritative duplicate, 2 derived

### Day 8 — EPA Deep Dive (likely unaffected — confirm)
- Game-level joint anchor pair: close_game_epa_per_play + close_game_def_epa_per_play, R²=0.772
- Season-level anchors: off_epa_per_play R²=0.779, def_epa_per_play YoY r=0.393
- YoY: off r=0.423, def r=0.393 — priors should be wider
- def_epa_per_play_allowed, last3_off_epa_avg, last3_def_epa_avg — all redundant
- close_game_def_epa_per_play built in Day 8 — authorized anchor despite not being in candidate_features.csv

### Day 9 — SP+ & Recruiting (re-run required)
- SP+ partial r=0.399 after EPA, YoY r=0.761 — anchor candidate (likely unchanged)
- Recruiting → win_pct R²=0.103 overall
- Recruiting G5 collapse: R²≈0.000 — MAY CHANGE after Pac-12 reclassification
- Recruiting verdict may shift if former Pac-12 teams (now correctly G5) show different recruiting signal

### Day 10 — Hierarchy Structure (re-run required)
- Pre-fix ICC: scored=0.075, point_diff=0.099, off_epa=0.075, def_epa=0.064
- Pre-fix tier split: P4=304, G5=248
- All findings need recomputation with correct conference assignments
- Three-level hierarchy expected to be confirmed — but verify

## Candidate Features
- Authoritative list: artifacts/candidate_features.csv
- Total features: 152 (verify after EDA 2 re-run)
- Only keep=True columns are authorized
- Exception: close_game_def_epa_per_play authorized anchor despite not being in list

## Artifacts Written
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ⚠️ re-run required | Regenerate after EDA 2 re-run |
| artifacts/epa_feature_verdict.csv | ✅ likely valid | Confirm after EDA 3 re-run |
| artifacts/sp_recruiting_verdict.csv | ⚠️ re-run required | Recruiting G5 finding may change |
| artifacts/hierarchy_verdict.csv | ⚠️ re-run required | All numbers based on wrong conference assignments |

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
- int.int_team_season_features — season-level team features including historically accurate conference

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
10. Use the canonical assign_tier function defined above — do not modify it

## How To Update This File
At the end of every session:
1. Update the date
2. Move completed notebooks to ✅ in the EDA table with the decision they produced
3. Add any new locked decisions
4. Add key findings from completed notebooks
5. Update what the next session must do
6. Commit: git add docs/session_state.md && git commit -m "docs: update session state after Day X" && git push
EOF