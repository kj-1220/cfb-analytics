# CFB Analytics Platform

An AI-powered college football analytics and betting research platform. Combines a calibrated Bayesian hierarchical model with Claude as a reasoning layer to produce win probabilities, spread predictions, and AI-authored match previews for every FBS game.

**Live target:** September 24, 2026 — Liberty vs Coastal Carolina (Sun Belt conference opener)  
**CBB parallel track:** January 3, 2027 — first P6 conference play Saturday

> Claude never predicts. It reasons over outputs the statistical model has already produced.

---

## What This Does

- Ingests structured CFB data from multiple APIs into a Postgres warehouse
- Cleans and conforms raw data through a dbt silver layer
- Builds mart tables and a certified semantic layer for model consumption
- Runs a three-level Bayesian hierarchical model producing win probability, spread, moneyline, and full score distributions via Monte Carlo simulation
- Maintains a RAG vector corpus of game narratives, conference identity profiles, environmental records, and coaching scheme history
- Serves model outputs and qualitative context to Claude via a FastAPI tool-use interface
- Claude reasons over predictions and RAG chunks to generate match previews, probability explanations, and conference context
- Displays everything in a React frontend built for game-day betting research

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          RAW DATA SOURCES                            │
│  CFBD API            │  The Odds API     │  SP+ / ESPN FPI           │
│  Games, stats, plays │  Live lines       │  Rating priors            │
│  247Sports / Rivals  │  PFF+ (manual)    │                           │
│  Recruiting composites│  RAG corpus only │                           │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    BRONZE LAYER  (schema: raw)                       │
│  Append-only. Source-native. Minimal transformation.                 │
│                                                                      │
│  raw.games (14,744)      raw.teams (1,902)    raw.venues (840)       │
│  raw.sp_ratings (538)    raw.recruiting (1,184) raw.odds (20+)       │
│  raw.team_stats (534)    raw.advanced_stats (552)                    │
│  raw.plays (1,073,640)   raw.game_weather (~14,282, ingesting)       │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │  dbt run
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    SILVER LAYER  (schemas: stg, int)                 │
│                                                                      │
│  STAGING VIEWS (stg) — one per raw table                            │
│  stg_games · stg_teams · stg_venues · stg_sp_ratings                │
│  stg_recruiting · stg_advanced_stats · stg_team_stats                │
│  stg_game_weather (Day 4)                                            │
│                                                                      │
│  INTERMEDIATE TABLES (int)                                           │
│  int_team_season_features — 552 rows                                 │
│  One row per FBS team per season (2022–2025)                         │
│  Full offensive + defensive profile. EDA input, nothing dropped      │
│                                                                      │
│  int_team_season_context — 552 rows                                  │
│  Derived ratios: pace, EPA differentials, havoc, turnovers,          │
│  field position, penalties, scoring efficiency (off + def)           │
│                                                                      │
│  int_game_team_features — 29,472 rows                                │
│  One row per team per game. Rolling off + def EPA, points,           │
│  win pct (3-game windows), rest days, opp SP+ (prior year)          │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │  EDA → feature selection
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    GOLD LAYER  (schemas: mart, semantic)             │
│                                                                      │
│  MART TABLES                                                         │
│  mart.team_features        Selected + engineered features            │
│  mart.upcoming_games       Schedule with venue and odds context      │
│  mart.historical_games     Results with feature snapshots at game time│
│  mart.predictions          Model outputs (written by Bayesian model) │
│  mart.conf_standings       Standings + conference race projections   │
│                                                                      │
│  SEMANTIC LAYER — certified metric definitions                       │
│  rolling_epa_diff  ·  form_score  ·  travel_index                   │
│  conf_strength  ·  recruiting_composite                              │
│  Claude reads these. Never computes them.                            │
└──────────┬───────────────────────────────────┬───────────────────────┘
           │                                   │
           ▼                                   ▼
┌─────────────────────────┐       ┌────────────────────────────────────┐
│   BAYESIAN MODEL        │       │   RAG CORPUS (schema: rag)         │
│   Python / PyMC         │       │   pgvector — same Postgres instance│
│                         │       │                                    │
│   3-level hierarchy:    │       │   Game narratives                  │
│   league → conf → team  │       │   Box scores · drive write-ups     │
│                         │       │   Rivalry history · ATS context    │
│   Priors seeded from    │       │                                    │
│   roster_strength_index:│       │   Conference identity              │
│   SP+ preseason rating  │       │   Tempo profiles · run/pass tend.  │
│   3-yr recruiting avg   │       │   Cross-conf matchup logs          │
│   Transfer portal net   │       │                                    │
│   NIL proxy             │       │   Environmental records            │
│                         │       │   High-altitude logs · travel dist │
│   Environmental adjusters       │   Weather outcomes · night/day     │
│   Elevation · Travel    │       │                                    │
│   Timezone · Kickoff    │       │   Coaching + scheme history        │
│                         │       │   Career records · scheme tags     │
│   Hierarchical Poisson  │       │   4th down tendencies · portal     │
│   + Monte Carlo (10k)   │       │                                    │
│                         │       │   Claude queries 3–5 chunks        │
│   → win prob            │       │   per matchup + context query      │
│   → predicted spread    │       │   Metadata filters: season,        │
│   → moneyline           │       │   conference, venue type           │
│   → score distribution  │       │                                    │
└──────────┬──────────────┘       └───────────────────┬────────────────┘
           │                                          │
           └──────────────────┬───────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         FASTAPI BACKEND                              │
│                                                                      │
│  Claude tools:                                                       │
│  get_metric()  ·  get_prediction()  ·  retrieve_knowledge()         │
│  get_conf_context()                                                  │
│                                                                      │
│  Endpoints:                                                          │
│  GET  /predict        GET  /preview       GET  /explain              │
│  GET  /metrics/team   GET  /metrics/matchup                          │
│  GET  /conference     GET  /schedule      GET  /standings            │
│  POST /ask                                                           │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        REACT FRONTEND                                │
│                                                                      │
│  Matchup page       — win prob · spread · score dist · AI preview   │
│  Schedule view      — all games, sorted by model vs market edge      │
│  Conference dashboard — standings · EPA leaderboard · projections    │
│  Team profile       — metrics · trends · recruiting · schedule       │
│  Season outlook     — CFP tracker · conference race                  │
│  AI analyst chat    — freeform questions via POST /ask               │
│  Model info         — validation metrics · methodology · freshness   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Data Sources

| Source | What It Provides | Method |
|---|---|---|
| [collegefootballdata.com](https://collegefootballdata.com) | Games, teams, venues, plays, team stats, advanced stats, recruiting, SP+ | REST API |
| [The Odds API](https://the-odds-api.com) | Live lines from 5 bookmakers | REST API |
| SP+ / ESPN FPI | Composite + unit ratings 2022–2025 | Via CFBD API |
| 247Sports / Rivals | Recruiting class composites 2020–2025 | Via CFBD API |
| PFF+ | Player grade summaries | Manual export — RAG corpus only |
| On3 | NIL player valuations (NIL proxy) | Scrape — roster_strength_index component |

---

## Bayesian Model

**Architecture:** Three-level hierarchy — league → conference → team  
**Likelihood:** Hierarchical Poisson scoring model  
**Simulation:** 10,000 Monte Carlo draws per game  

### Roster Strength Index (team prior seed)
Four-component composite:
1. SP+ preseason rating
2. 3-year recruiting composite (247Sports)
3. Transfer portal net (quality-weighted, from CFBD API)
4. NIL valuation proxy (On3 player valuations)

### Environmental Adjusters
All four enter as multiplicative terms on the team scoring rate:

| Adjuster | Implementation |
|---|---|
| Elevation | Log-linear effect of venue elevation (ft). Affects teams playing above 5,000 ft. |
| Travel distance | Haversine distance between city centroids. Threshold: >1,000 miles. |
| Timezone shift | Hours of timezone difference × kickoff time penalty. Asymmetric (west coast noon ET is worst case). |
| Kickoff time | Day/night, weekday/Saturday splits. |

### Outputs
Every game gets a full posterior distribution, not just a point estimate:
- Win probability (home and away)
- Predicted spread (median of score differential posterior)
- Moneyline (converted from win probability with standard vig)
- Score distribution (full histogram stored as JSONB in `mart.predictions`)

### Validation Benchmark
The model is measured against the Vegas closing line — not against naive baselines. Beating the closing line on ATS record is the standard for edge.

---

## RAG Corpus

Four document categories chunked, embedded (`text-embedding-3-small`), and stored in `rag.documents` with pgvector:

| Category | Contents | Source |
|---|---|---|
| Game narratives | Box score summaries, drive write-ups, rivalry history, upset context ATS | Auto-generated from raw.games + raw.plays |
| Conference identity | Tempo profiles, run/pass tendencies, cross-conf matchup logs, neutral site records | Auto-generated from raw.advanced_stats |
| Environmental records | High-altitude logs, travel distance records, weather outcomes, night/day splits | Auto-generated from venue + game join |
| Coaching + scheme | Career records, scheme tags (4-2-5, Air Raid, etc.), 4th down tendencies, portal impact | Manually curated |

Claude queries the vector store with two query types per matchup — a matchup query ("Team A vs Team B history") and a context query ("Sun Belt at altitude, 2022–25") — plus metadata filters on season, conference, and venue type. Claude retrieves 3–5 chunks and reasons over them alongside model outputs. It never predicts from the chunks alone.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Database | PostgreSQL 15 (Docker local / managed production) |
| Vector search | pgvector (same Postgres instance — no separate vector DB) |
| Transformation | dbt (postgres adapter) |
| Bayesian model | Python / PyMC |
| Embedding | text-embedding-3-small (OpenAI) |
| Backend | FastAPI |
| LLM | Claude (Anthropic) via tool use |
| Frontend | React + Vite + Tailwind + recharts |
| Deployment | Railway (API + cron) · Vercel (frontend) |

---

## Weekly ETL Pipeline

Runs every Sunday at 6am throughout the CFB season:

1. Pull new game results from CFBD API → upsert `raw.games`
2. `dbt run` → refresh silver and gold layers
3. `run_predictions()` → generate Monte Carlo predictions for all games in next 14 days → write to `mart.predictions`
4. Generate new game narratives → embed → write to `rag.documents`
5. Refresh odds → `raw.odds` → `mart.upcoming_games`
6. Healthcheck: validate row counts, prediction coverage, data freshness

---

## Local Setup

**Prerequisites:** Docker Desktop, Python 3.11+, Node 18+, dbt-postgres

```bash
# Clone
git clone https://github.com/kj-1220/cfb-analytics.git
cd cfb-analytics

# Start database
docker start cfb-pg

# Python dependencies
pip install -r requirements.txt

# Environment variables
cp .env.example .env
# Add: CFBD_API_KEY, ODDS_API_KEY, ANTHROPIC_API_KEY

# Run dbt
cd cfb_analytics
dbt debug
dbt run

# Verify silver layer
psql "host=127.0.0.1 port=5455 dbname=postgres user=postgres password=postgres" \
  -c "select team_name, season, sp_rating, epa_differential from int.int_team_season_features where team_name in ('Liberty', 'Coastal Carolina') order by team_name, season;"
```

---

## Project Status

| Phase | Description | Status |
|---|---|---|
| 1 | Infrastructure — Docker, Postgres, dbt, GitHub | ✅ Complete |
| 2 | Bronze layer — 10 raw tables, 1M+ rows incl. game_weather | ✅ Complete |
| 3 | Silver layer — 8 staging views + 3 int tables (552 + 552 + 29,472 rows) | ✅ Complete |
| 3b | Defensive feature expansion — havoc bug fixed, field position investigated | ✅ Complete |
| 4 | int_game_environment — elevation, travel, timezone, weather additions | 🔲 Next |
| 4b | EDA — feature correlation and selection | 🔲 |
| 5 | Gold layer — mart tables + semantic layer | 🔲 |
| 6 | Bayesian model — hierarchical Poisson + Monte Carlo | 🔲 |
| 7 | RAG corpus — pgvector + 4 document categories | 🔲 |
| 8 | Claude integration — tool use + prompt engineering + eval | 🔲 |
| 9 | FastAPI backend — all endpoints + auth | 🔲 |
| 10 | React frontend — matchup page + dashboard + chat | 🔲 |
| 11 | Weekly ETL pipeline — automated season refresh | 🔲 |
| 12 | Integration testing + hardening | 🔲 |
| 13 | Production deployment | 🔲 |
| **Live** | **Liberty vs Coastal Carolina** | **Sept 24, 2026** |

**Realistic completion for a production-ready system: late July to mid-August 2026.**

---

## College Basketball Parallel Track

Same infrastructure. Same Postgres. Same dbt. Same FastAPI. Same React frontend. Sport-prefixed schemas (`cbb_`).

- **Target:** January 3, 2027 — first P6 conference play Saturday
- **Scope:** Big Ten, SEC, Big 12, ACC, Big East
- **V1 model:** Dixon-Coles adapted for CBB with Barttorvik ratings as strength input
- **V2 model:** Gaussian Process team strength estimator → Dixon-Coles (handles trajectory and momentum)
- **Data:** Barttorvik manual daily pulls — one snapshot per conference game day

---

## Key Design Principles

**Claude never predicts.** It reasons over outputs the statistical model has already produced. If a metric isn't defined in the semantic layer, it doesn't exist as far as Claude is concerned. Claude only states probabilities returned by `get_prediction()`.

**One database.** pgvector lives in the same Postgres instance. One connection string. No separate vector DB. Simpler ops.

**Bronze is immutable.** Raw tables are append-only. All transformation happens in silver and above. Never alter or truncate a raw table.

**The closing line is the benchmark.** A model that beats a coin flip is not impressive. A model with a positive ATS record against closing lines has edge. That is the standard.

**Keep every feature until EDA.** `int_team_season_features` is the EDA input table. Nothing is dropped until feature selection is complete and documented.
