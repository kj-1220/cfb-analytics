# CFB Analytics Platform

An AI-powered college football analytics platform built on a warehouse-first, medallion architecture. The platform generates win probabilities, spread predictions, and AI-authored match previews by combining a Bayesian hierarchical model with Claude as an interpretation layer.

**Live target:** Liberty vs Coastal Carolina — September 24, 2026 (first Sun Belt conference play Saturday)

---

## What It Does

- Ingests structured CFB data from multiple sources into a Postgres data warehouse
- Cleans and conforms raw data through a dbt silver layer
- Builds a wide feature table ready for exploratory data analysis and model training
- Runs a three-level Bayesian hierarchical model to produce win probability, spread, and moneyline outputs
- Serves predictions and qualitative context to Claude via a FastAPI backend
- Claude reasons over model outputs — it never predicts directly

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                             │
│  collegefootballdata.com  │  The Odds API  │  247Sports/Rivals  │
│  SP+ / ESPN FPI           │  PFF+ (manual export, RAG only)     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     BRONZE LAYER  (schema: raw)                 │
│  raw.games        │  raw.teams         │  raw.venues            │
│  raw.sp_ratings   │  raw.recruiting    │  raw.odds              │
│  raw.team_stats   │  raw.advanced_stats│  raw.plays             │
│                                                                 │
│  Source-native. Minimal transformation. Append-only.           │
└───────────────────────────┬─────────────────────────────────────┘
                            │  dbt
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SILVER LAYER  (schemas: stg, int)           │
│                                                                 │
│  STAGING (stg) — one view per raw table                        │
│  stg.stg_games          Clean types, parse start_date          │
│  stg.stg_teams          FBS only, location + timezone          │
│  stg.stg_venues         Elevation meters → feet, lat/lon       │
│  stg.stg_sp_ratings     SP+ composite + unit ratings           │
│  stg.stg_recruiting     Class composites, typed                │
│  stg.stg_advanced_stats snake_case, EPA + havoc features       │
│  stg.stg_team_stats     Box score stats + derived metrics      │
│                                                                 │
│  INTERMEDIATE (int) — wide join table                          │
│  int.int_team_season_features                                  │
│    One row per FBS team per season (2022–2025)                 │
│    ~552 rows │ all candidate features │ EDA input              │
└───────────────────────────┬─────────────────────────────────────┘
                            │  EDA → feature selection
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GOLD LAYER  (schemas: mart, semantic)      │
│                                                                 │
│  MART TABLES                                                    │
│  mart.team_features      Selected + engineered features        │
│  mart.upcoming_games     Schedule with context                 │
│  mart.historical_games   Results with feature snapshots        │
│  mart.predictions        Model outputs (written by Bayesian)   │
│  mart.conf_standings     Live conference standings             │
│                                                                 │
│  SEMANTIC LAYER — certified metric definitions                 │
│  rolling_epa_diff  │  form_score      │  travel_index          │
│  conf_strength     │  recruiting_composite                     │
│  (Claude reads these — never computes them)                    │
└──────────┬────────────────────────────┬────────────────────────┘
           │                            │
           ▼                            ▼
┌──────────────────────┐    ┌───────────────────────────────────┐
│   BAYESIAN MODEL     │    │         RAG CORPUS                │
│   (Python / PyMC)    │    │   schema: rag  │  pgvector        │
│                      │    │                                   │
│  3-level hierarchy:  │    │  PFF+ grade summaries             │
│  league → conf → team│    │  Conference style profiles        │
│                      │    │  Scheme + coaching tendencies     │
│  Priors:             │    │  Rivalry history                  │
│  roster_strength_index    │  Environmental records            │
│  = SP+ preseason     │    │  Glossary                         │
│  + recruiting 3yr avg│    │                                   │
│  + transfer portal   │    │  (same Postgres instance,         │
│  + NIL proxy         │    │   no separate vector DB)          │
│                      │    └───────────────────┬───────────────┘
│  Adjusters:          │                        │
│  elevation, travel,  │                        │
│  timezone, kickoff   │                        │
│                      │                        │
│  Outputs → Monte Carlo                        │
│  win prob │ spread   │                        │
│  moneyline           │                        │
└──────────┬───────────┘                        │
           │                                    │
           └──────────────┬─────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FASTAPI BACKEND                            │
│                                                                 │
│  Claude tools:                                                  │
│  get_metric()   get_prediction()   retrieve_knowledge()        │
│  get_conf_context()                                             │
│                                                                 │
│  Claude never predicts. It reasons over outputs.               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      REACT FRONTEND                             │
│  Conference dashboard  │  Team profiles  │  Matchup page       │
│  Season outlook        │  AI analyst chat│  Metric explorer    │
│  CFP tracker                                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Sources

| Source | What It Provides | Method |
|---|---|---|
| [collegefootballdata.com](https://collegefootballdata.com) | Games, teams, venues, advanced stats, plays, team stats, recruiting | REST API |
| [The Odds API](https://the-odds-api.com) | Live lines from 5 bookmakers | REST API |
| SP+ / ESPN FPI | Composite + unit ratings 2022–2025 | CFBD API |
| 247Sports / Rivals | Recruiting class composites 2020–2025 | CFBD API |
| PFF+ | Player grade summaries | Manual export — RAG corpus only |

---

## Bronze Layer — Raw Tables

| Table | Rows | Contents |
|---|---|---|
| `raw.games` | 14,744 | Game results 2022–2025 |
| `raw.teams` | 1,902 | All classifications — FBS/FCS/DII/DIII |
| `raw.venues` | 840 | Elevation, lat/lon, capacity, dome status |
| `raw.sp_ratings` | 538 | SP+ composite + unit ratings 2022–2025 |
| `raw.recruiting` | 1,184 | 247Sports composite class scores 2020–2025 |
| `raw.odds` | 20 | Live lines from The Odds API, 5 bookmakers |
| `raw.team_stats` | 534 | 63 box score categories per team per season |
| `raw.advanced_stats` | 552 | 68 EPA/efficiency features, offense + defense |
| `raw.plays` | 1,073,640 | Every snap 2022–2025 with PPA, week-by-week |

---

## Silver Layer — dbt Models

### Staging Views (`stg` schema)
One view per raw table. Type casting, renaming, filtering, and simple derivations only.

| Model | Key Transformations |
|---|---|
| `stg_games` | Cast types, parse `start_date`, filter to completed games |
| `stg_teams` | Filter to FBS only (`classification = 'fbs'`), keep location + timezone |
| `stg_venues` | Convert elevation meters → feet, carry lat/lon |
| `stg_sp_ratings` | Clean cast of composite + unit ratings |
| `stg_recruiting` | Clean cast, 3-year rolling average computed upstream in `int` |
| `stg_advanced_stats` | Rename all columns to snake_case, EPA + havoc features |
| `stg_team_stats` | Null-safe casts, derive `completion_pct`, `yards_per_attempt`, `third_down_pct`, `fourth_down_pct` |

### Intermediate Table (`int` schema)
| Model | Description |
|---|---|
| `int_team_season_features` | Wide join — one row per FBS team per season. All candidate features present. EDA input. Drop nothing. |

---

## Bayesian Model

Three-level hierarchical model: **league → conference → team**

**Roster Strength Index** (team prior seed):
- SP+ preseason rating
- 3-year recruiting composite (247Sports)
- Transfer portal net (quality-weighted)
- NIL valuation proxy (On3)

**Environmental adjusters:**
- Elevation (feet above sea level)
- Travel distance (miles)
- Timezone shift (hours)
- Kickoff time (west-coast teams at noon ET)

**Outputs via hierarchical Poisson scoring + Monte Carlo simulation:**
- Win probability
- Spread
- Moneyline

Model reads from `mart.team_features`, writes predictions to `mart.predictions`.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Database | PostgreSQL 15 (Docker, port 5455) |
| Transformation | dbt (postgres adapter) |
| Modeling | Python / PyMC (Bayesian) |
| Vector search | pgvector (same Postgres instance) |
| Backend | FastAPI |
| LLM | Claude (Anthropic) |
| Frontend | React |

---

## Local Setup

**Prerequisites:** Docker Desktop, Python 3.11+, dbt-postgres

```bash
# Clone the repo
git clone https://github.com/kj-1220/cfb-analytics.git
cd cfb-analytics

# Start the database
docker start cfb-pg

# Install Python dependencies
pip install -r requirements.txt

# Copy environment variables
cp .env.example .env
# Add CFBD_API_KEY and ODDS_API_KEY to .env

# Run dbt
cd cfb_analytics
dbt debug
dbt run
```

---

## Project Status

| Day | Goal | Status |
|---|---|---|
| Day 1 | Infra setup — Docker, Postgres, dbt, GitHub | ✅ Complete |
| Day 2 | Bronze layer — all 9 raw tables populated | ✅ Complete |
| Day 3 | Silver layer — 7 staging views + `int_team_season_features` | ✅ Complete |
| Day 4 | EDA — feature correlation, selection for Bayesian model | 🔲 Upcoming |
| Day 5 | Gold layer — mart tables + semantic layer | 🔲 Upcoming |
| Day 6 | Bayesian model build + Monte Carlo | 🔲 Upcoming |
| Day 7 | FastAPI backend + Claude integration | 🔲 Upcoming |
| Day 8 | React frontend | 🔲 Upcoming |
| **Live** | **Liberty vs Coastal Carolina** | **Sept 24, 2026** |

---

## Key Design Principles

- **Claude never predicts.** It reasons over outputs the statistical model and semantic layer have already produced. If a metric isn't defined in the semantic layer, it doesn't exist as far as Claude is concerned.
- **One database.** pgvector lives inside the same Postgres instance — no separate vector database. One connection string, simpler ops.
- **Keep every feature until EDA.** `int_team_season_features` is the EDA input table. Nothing is dropped until feature selection.
- **Bronze is immutable.** Raw tables are append-only source data. All transformation happens in silver and above.
