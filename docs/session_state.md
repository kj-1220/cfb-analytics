cat > ~/cfb-analytics/docs/session_state.md << 'EOF'
# CFB Analytics — Session State

## Last Updated
2026-04-29

## Project Goal
Hierarchical Negative Binomial model predicting score distributions for FBS college football games.
Outputs: win probability, spread, moneyline, over/under via Monte Carlo simulation.
Goes live: September 24, 2026 — Liberty vs Coastal Carolina.

## Model Architecture (locked)
- Three-level hierarchy: league → conference → team (confirmed Day 10)
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
| 6 | eda_01_scoring_distributions.ipynb | ✅ complete | Negative Binomial likelihood — overdispersion confirmed across all conference-season cells, VMR 3.56–8.05 |
| 7 | eda_02_feature_inventory.ipynb | ✅ complete | 154 candidate features locked in candidate_features.csv (updated from 152 after re-run) |
| 8 | eda_03_epa_deep_dive.ipynb | ✅ complete | Game-level close-game EPA pair is joint model anchor; season-level EPA anchors priors; off YoY r=0.423, def YoY r=0.393 |
| 9 | eda_04_sp_ratings_recruiting.ipynb | ✅ complete | SP+ anchor candidate YoY r=0.761; recruiting supporting but signal varies significantly by P4 conference — see findings |
| 10 | eda_05_hierarchy_structure.ipynb | ✅ complete | Three-level hierarchy confirmed; ICC 0.07–0.09 across all metrics; team spread justifies team level |
| 11 | eda_06_environmental_features.ipynb | ❌ not built | Which environmental features have empirical support — conference-stratified analysis |
| 12 | eda_07_momentum_rolling_features.ipynb | ❌ not built | Whether rolling features add signal beyond season averages |
| 13 | eda_08_game_script_close_games.ipynb | ❌ not built | Whether game script belongs in model and in what role |
| 14 | eda_09_evaluation_framework.ipynb | ❌ not built | Written evaluation checklist for model sign-off |

## What The Next Session Must Do (2026-04-30)
Build `notebooks/eda/eda_06_environmental_features.ipynb` — Day 11

Critical methodology requirement — do NOT evaluate globally:
- Elevation: stratify by conference tier. Tier 1 (Mountain West, Big 12), Tier 2 (Pac-12, WAC). Exclude SEC, ACC, Big Ten east, AAC entirely from elevation analysis.
- Travel: filter to games where away_travel_distance_mi > 500. Test robustness at 750+. Do not evaluate globally.
- The question is not whether elevation has a global effect. It is whether elevation adds signal beyond what the conference prior already captures within conferences where it is relevant.

## What Must Happen on 2026-05-01
Transfer portal ingestion:
- CFBD API key resets May 1 (1,000 call free tier limit)
- Endpoint: apinext.collegefootballdata.com — v2 API
- Pull transfer portal data for seasons 2022, 2023, 2024, 2025 (~4 API calls)
- Fields needed: season, fromTeam, toTeam, rating, stars, position, eligibility
- Build raw.transfer_portal table
- Build stg_transfer_portal staging view
- Aggregate to team-season level: sum of incoming ratings, sum of outgoing ratings, net portal score
- Add portal_net_rating column to int_team_season_features
- Re-run EDA 4 with portal data added to recruiting analysis

## Data Fixes Applied This Session
Three dbt fixes were made and committed today:

**Fix 1 — Conference assignment by season (not static snapshot)**
- Problem: int_team_season_features joined stg_teams on team_name only, assigning current conference to all seasons. Oregon showed Big Ten for 2022-2023.
- Fix: Added conf_by_season CTE deriving conference from stg_games.home_conference/away_conference — historically accurate by season.
- Commit: "fix: derive conference from game records by season, not static team snapshot"

**Fix 2 — FCS team filter**
- Problem: FCS-to-FBS transition teams (Delaware, North Dakota State, Sacramento State, etc.) were appearing in int_team_season_features — 18 rows across 8 teams.
- Fix: Added fbs_conferences CTE and inner join to spine, filtering to 11 legitimate FBS conferences only.
- Commit: "fix: filter FCS teams from int_team_season_features using FBS conference allowlist"
- Row count: 552 → 534

**Fix 3 — All notebooks re-run against clean data**
- EDA 2: 152 → 154 keep=True features (close_game_def_epa_per_play and close_game_def_play_count now properly in candidate list)
- EDA 3: Unchanged — EPA analysis does not use conference
- EDA 4: Unchanged — recruiting G5 collapse finding held after Pac-12 reclassification
- EDA 5: ICC values shifted modestly (all remain above 0.05 threshold), hierarchy confirmed

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
- FCS-to-FBS transitions: excluded — filtered at dbt level
- recruiting_3yr_avg: high school recruiting only
- Conference assignment: historically accurate by season from game records — not static team snapshot
- Pac-12 in dataset: G5 for all seasons — teams in data were never the real Pac-12
- FBS Independents: not a pooling group — Notre Dame routes to P4, UConn routes to G5 by team name
- No tiers within conferences: team-level parameters handle within-conference spread naturally
- Three-level hierarchy: league → conference → team — confirmed by ICC analysis

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

## Key Findings From Completed Notebooks

### Day 6 — Scoring Distributions
- 2,835 FBS games, 2022–2025
- Home VMR 6.388, Away VMR 6.515, pooled VMR 6.627
- Every conference in every season is overdispersed — no exceptions
- Big Ten most overdispersed (VMR 6.74–8.05), ACC least (VMR 5.20–5.60)
- Decision locked: Negative Binomial. r ~ HalfNormal(), should vary by conference.

### Day 7 — Feature Inventory
- 154 keep=True features (updated after re-run)
- 10 dropped: 7 join keys, 1 non-authoritative duplicate, 2 derived
- close_game_def_epa_per_play and close_game_def_play_count now properly in candidate list

### Day 8 — EPA Deep Dive
- Game-level joint anchor pair: close_game_epa_per_play + close_game_def_epa_per_play, R²=0.772
- Season-level anchors: off_epa_per_play R²=0.779, def_epa_per_play YoY r=0.393
- YoY: off r=0.423, def r=0.393 — both below 0.60, priors should be wider
- def_epa_per_play_allowed — redundant (|r|=0.971 with anchor pair)
- last3_off_epa_avg — redundant (residual |r|=0.086)
- last3_def_epa_avg — redundant (residual |r|=0.054)

### Day 9 — SP+ & Recruiting
- SP+ partial r=0.399 after EPA, YoY r=0.761 — anchor candidate
- Recruiting → win_pct R²=0.103 overall — supporting
- Recruiting G5 collapse: R²≈0.000 — signal absent below P4
- Recruiting within P4 varies significantly by conference:
  - Big Ten: rec→off_epa R²=0.369, rec→win_pct R²=0.390 — strong signal
  - SEC: rec→win_pct R²=0.236 but rec→off_epa R²=0.048 — predicts wins not EPA
  - ACC: rec→off_epa R²=0.095, rec→win_pct R²=0.054 — weak
  - Big 12: rec→off_epa R²=0.004, rec→win_pct R²=0.066 — essentially zero
- Recruiting YoY stability very high across all P4 conferences (r=0.929–0.968)
- Leading indicator test (season N rec → season N+1 outcomes):
  - Big Ten: R²=0.254–0.309 — reliable leading indicator
  - SEC: R²=0.034–0.271 — predicts wins but not EPA
  - ACC/Big 12: R²<0.113 — unreliable as leading indicator
- ⚠️ Recruiting cannot be a flat feature even within P4 — requires conference-specific treatment
- ⚠️ Transfer portal ingestion needed May 1 — portal decouples from HS recruiting especially in Big 12

### Day 10 — Hierarchy Structure
- 534 team-seasons, 136 teams, 11 conferences, 4 seasons (post-fix)
- Tier split: P4=246, G5=288 (Pac-12 correctly G5)
- ICC values: scored=0.093, point_diff=0.088, off_epa=0.094, def_epa=0.070
- All ICC above 0.05 threshold — conference pooling justified
- No conference outliers (all z scores within ±1.5)
- Within-conference team SD range: 8.743–13.772, mean=10.356 — team level clearly justified
- Decision: THREE-LEVEL HIERARCHY CONFIRMED — league → conference → team
- FBS Independents (Notre Dame + UConn) has high within-variance (72.05) — handled by assign_tier routing, not pooling group

## Candidate Features
- Authoritative list: artifacts/candidate_features.csv
- Total features: 154 keep=True
- Only keep=True columns are authorized for use in any notebook

## Artifacts Written
| File | Status | Notes |
|---|---|---|
| artifacts/candidate_features.csv | ✅ authoritative | 154 features, keep=True only — updated after re-run |
| artifacts/epa_feature_verdict.csv | ✅ valid | Day 8 output, 7 rows, confirmed unchanged |
| artifacts/sp_recruiting_verdict.csv | ✅ valid | Day 9 output, confirmed unchanged |
| artifacts/hierarchy_verdict.csv | ✅ valid | Day 10 output, post-fix numbers |

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
- int.int_team_season_features — season-level team features, 534 rows, FBS only, historically accurate conference

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