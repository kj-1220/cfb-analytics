CFB Model — Rebuild Plan
Written May 17, 2026. This document is the source of truth for the rebuild.

Why We Are Rebuilding
The previous build failed because architectural decisions were made in conversation
and locked without empirical validation. Notebooks confirmed decisions rather than
tested them. The following structural failures were identified:

NegBin2 likelihood failed posterior checks on Day 26 — structural, not fixable
alpha_team and delta_team added no predictive value — removed Day 26
Conference as pooling unit was assumed, not tested — ICC 0.02–0.05 was marginal
Two independent score distributions combined via Monte Carlo — causally wrong
Weather applied as a spread feature — wrong, weather affects total not spread
Feature engineering scattered mid-EDA rather than completed before analysis
Temporal train/test split used without justification — no leakage exists in this data
Training window 2022–2024 included seasons that may not reflect the current game
Every notebook confirmed a prior decision rather than evaluated competing approaches


What Is Settled Before Any Notebook Runs
These decisions were made from reasoning and data in this conversation.
They do not get reopened in subsequent sessions without explicit direction.
Why Bayesian
Early season data sparsity. With only 3 non-conference games before conference
play begins, there is not enough observed performance to make reliable predictions.
Bayesian inference lets the model start with an informed prior seeded by SP+ and
recruiting, then update as conference games accumulate. The prior carries the model
until the data can speak. This is the core reason — not uncertainty quantification,
not score distributions. Those are outputs of the approach.
Why Hierarchical
Conferences have genuinely different playing styles. The pooling structure reflects
that teams within a conference share stylistic characteristics that justify borrowing
strength from conference peers. The specific pooling unit — conference, data-driven
clusters, or something else — is an open empirical question the EDA must answer.
Targets
Point differential and total points as joint correlated targets.
Not two independent score distributions. Football is one game with a single flow.
The final scores of both teams are downstream of that single game process.

Spread/moneyline: driven by matchup quality, execution, team strength
Total/over-under: driven by pace, weather, style, scoring environment
Weather enters the total model. Not the spread model.
Matchup archetype features enter the total model primarily.

Model Structure Question — Not Yet Decided
Whether this is a single Bayesian model with week-aware prior weighting or
separate early/late season models is an empirical question. The EDA must show
whether early and late season look like one process with changing weights or
two genuinely different data generating processes. This decision is made in
EDA Final, not before.

Global Constants — Hardcoded Everywhere
These values appear at the top of every notebook and every handoff prompt.
They never change. They never get overridden.
pythonRANDOM_SEED = 42
TRAIN_SEASONS = [2022, 2023, 2024, 2025]
TEST_SIZE = 0.20
CONFERENCE_GAMES_ONLY = True
EXCLUDE_INDEPENDENTS = True
# Recency weighting: 2022 discounted relative to 2023-2025
# Specific weighting scheme determined empirically in EDA
Training Window Rationale
NIL formally began July 1, 2021. By the 2022-2023 portal cycle NIL and the
transfer portal were deeply intertwined. The game changed structurally in 2024-2025
with conference realignment and larger NIL budgets. 2023-2025 is the most relevant
window. 2022 is included with recency discounting to improve sample size without
treating it as equally informative as more recent seasons.
Game Counts (conference games only, FBS non-independents)

2022: 523 games
2023: 546 games
2024: 538 games
2025: 548 games
Total pool: 2,155 games
Training (~80%): ~1,724 games
Test (~20%): ~431 games

Split Design

Random 80/20 split using RANDOM_SEED = 42
No temporal boundary — individual games are the prediction unit,
features are computed from pre-game information, no leakage exists
Stratification by season and week to be evaluated in EDA 1


Rules Every Session Must Follow

Read this document before doing anything else
One cell at a time. Wait for output before writing the next cell
Do not decide anything in conversation that should be decided from data
Every notebook tests competing approaches — it does not confirm prior decisions
Every decision made in a notebook must be supported by output from that notebook
When something fails, stop and ask. Do not iterate independently
Do not rewrite a verified cell
FBS Independents excluded and asserted after every load
Conference games only — assert after every load
Season filter: season IN (2022, 2023, 2024, 2025) — mandatory
RANDOM_SEED = 42 — mandatory everywhere a random operation occurs
Cast all Decimal columns to float64 immediately after loading
Do not re-standardize features that are already standardized
Do not introduce model components that were not requested
Do not reference previous build decisions as justification for anything —
every decision in the rebuild comes from rebuild EDA output


EDA Structure
EDA 1 — Scoring Distributions and Conference Clustering
Purpose: Characterize the outcome distributions for both targets. Establish
whether the distribution family and structure differs across the season and across
conferences. Cluster conferences on outcome characteristics. This notebook does
not test predictive features and does not require the feature inventory.
Questions this notebook must answer:

What distribution family best fits point differential? Test: Normal, Log-Normal,
Skew-Normal, Student-T, NegBin2 (as comparison only). Let the data decide.
What distribution family best fits total points? Test same families separately.
Does the outcome distribution look meaningfully different in early season vs
late season? If variance is higher early and tightens late, that informs how
much uncertainty the prior needs to carry.
Do conferences cluster naturally by outcome characteristics — scoring means,
variance, tail behavior, blowout frequency — or does the P4/G5 label capture
the real grouping structure? Cluster on outcome characteristics only.
Do not decide number of clusters in advance. Let elbow and silhouette scores
decide. Clustering here is a finding to carry forward, not a locked pooling
decision.
Does the distribution shift across seasons 2022–2025? Is 2022 meaningfully
different from 2024–2025 in ways that justify discounting it?
Should the train/test split be stratified on season and week, or is pure
random sufficient? Evaluate representativeness of both approaches.

Features needed: Outcomes and game context only.

points scored, points allowed, point differential, total points
season, week, conference, is_dome, is_neutral, home/away indicator
No predictive features required

Feature inventory does not need to precede this notebook.
Session state this notebook must produce:

Locked distribution family for point differential with full justification
Locked distribution family for total points with full justification
Conference cluster assignments and what outcome characteristics define
each cluster — carried forward to EDA Final pooling decision
Quantified assessment of whether 2022 looks meaningfully different from
2023–2025 — informs recency weighting scheme in feature EDAs
Early vs late season structural finding — sharp break or gradual transition —
carried forward to EDA 3
Decision on train/test split stratification with justification


EDA 2 — Feature Engineering and Inventory
Purpose: Build every derived feature into the schema, then enumerate the
complete candidate feature list. This is the engineering pass. Every subsequent
EDA pulls from this inventory and tests only — no subsequent notebook builds
features. All engineering decisions made here are locked after this notebook runs.
Part 1 — dbt model updates (engineering pass):
Build into the int schema everything that was scattered across later notebooks
in the previous build. This includes but is not limited to:

Wind chill (derived weather feature)
Offense and defense archetypes (KMeans clustering — k determined empirically
in this notebook, not assumed in advance)
Matchup features: offense_archetype_matchup, defense_archetype_matchup,
home_off_vs_away_def_matchup, away_off_vs_home_def_matchup
Style delta features: rush_rate_std_downs_delta, rush_rate_pass_downs_delta
Close game play count delta
ELO/SP+ divergence
Any other derived features not currently in the schema

Part 2 — inventory:

Enumerate every column in every int table against the current schema
Resolve duplicates by authoritative source
Flag downstream derived columns
Produce candidate_features.csv — the complete starting list for all
subsequent EDAs

Session state this notebook must produce:

Every feature built into the schema with full construction details:

KMeans k selected and why (elbow and silhouette evidence)
Clustering feature space used and why
Divergence calculation parameters locked with values
Any threshold decisions with justification


candidate_features.csv row count and breakdown by authoritative table
Any schema facts discovered during engineering that affect downstream notebooks
All engineering decisions are locked after this notebook — they do not get
revisited in subsequent sessions


EDA 3 — Season Segment Boundary
Purpose: Establish empirically at what point in the season observed performance
overtakes the prior as the dominant signal. This boundary is used by every
subsequent feature EDA to break out early vs late season signal. It must be
established before feature signal testing begins.
Questions this notebook must answer:

At what week does the predictive power of prior-seed features (SP+, recruiting)
begin to decline relative to observed performance features (EPA, rolling metrics)?
Is the transition a sharp break at a specific week or a gradual shift?
Does the boundary differ by target — does it occur at a different point for
spread vs total?
Does the boundary differ by conference or tier?
Is there a single boundary that applies across features, or does each feature
category have its own crossover point?

Session state this notebook must produce:

Empirical season segment boundary or boundaries — specific week or week range
with supporting evidence, not an assumption
Whether the transition is sharp or gradual
Whether the boundary differs by target
Whether the boundary differs by conference or tier
Whether a single boundary applies or feature-specific boundaries are needed
How this boundary is to be applied as the standard season segment breakout
in every subsequent feature EDA


EDA 4+ — Feature Signal Testing
Planning deferred until EDA 2 inventory is complete.
The specific notebooks, their sequence, and their feature domain groupings
are determined after EDA 2 produces the complete candidate feature list.
Planning them before the inventory runs would repeat the same mistake as
the previous build — deciding structure before seeing data.
What is settled about these notebooks:

Every feature is tested against point differential and total points separately
Every feature is tested across season segments using the boundary from EDA 3
Season segment is a dimension within each feature test, not a separate notebook
No feature building occurs — every feature already exists in the schema from EDA 2
The recency weighting scheme for 2022 is tested empirically in at least
one of these notebooks and locked before model build begins

Standard output every feature EDA must produce for each feature tested:

Signal vs point differential: partial r, conference scope, season segment breakdown
Signal vs total points: partial r, conference scope, season segment breakdown
YoY stability: stable enough to be a prior seed, a game-level predictor, or neither
Verdict: include / exclude / conditional, with full justification from output


EDA Final — Synthesis and Model Structure Decisions
Purpose: Consolidate all findings from EDA 3 onwards. Make the structural
decisions that define what the model build phase is building. Every decision
in this notebook is supported by evidence from a prior notebook. Nothing is
decided here that was not first established empirically.
Decisions this notebook must make:

Single Bayesian model with week-aware prior weighting vs separate early/late
season models — based on EDA 3 season segment findings
What the pooling unit is — conference, data-driven clusters, or something else —
based on EDA 1 conference clustering and ICC findings from feature EDAs
Which features enter the spread model vs the total model vs both
What recency weighting scheme to apply to 2022 games — locked here from
empirical testing in feature EDAs
Final feature list — every included feature has a verdict supported by EDA output
Prior specification for every included feature

Output this notebook must produce:

final_features.csv — rebuilt from scratch, every verdict supported by
rebuild EDA output, not carried from previous build
prior_specification.md — one prior per feature, justified by EDA findings
model_architecture.md — structural decisions locked with evidence citations


Model Build Phase
Not planned yet. Planned after EDA Final is complete.
The model build phase is defined entirely by what EDA Final produces.
No model architecture decisions are made before that.

Connection Pattern (canonical — use exactly)
pythonimport psycopg2
import pandas as pd
import numpy as np

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

assign_tier Function (canonical — use exactly, do not modify)
pythonP4_CONFERENCES = {"ACC", "Big 12", "Big Ten", "SEC"}

def assign_tier(row):
    if row["team_name"] == "Notre Dame":
        return "P4"
    if row["team_name"] == "UConn":
        return "G5"
    if row["conference"] in P4_CONFERENCES:
        return "P4"
    return "G5"

Known Schema Facts

conference does NOT exist in int_game_team_features — join to
int_team_season_features on team_name and season
is_home does NOT exist in int_game_team_features — derive as
CASE WHEN f.team_name = g.home_team THEN 1 ELSE 0 END via join to raw.games
int_game_environment has home_team and away_team, not team_name —
join on game_id only, then expand to two team rows
All numeric columns from psycopg2 return as Decimal — cast to float64 immediately
Boolean columns: use
.map(lambda x: 1 if x is True else (0 if x is False else np.nan)).astype(float)
int_game_team_features granularity: two rows per game (one per team)
sp_rating and conference: authoritative source is int_team_season_features
Pac-12 in dataset: G5 for all seasons (post-realignment)
Notre Dame: P4 — route by team name not conference label
UConn: G5 — route by team name not conference label


Source Tables

int.int_game_team_features — game-level team performance
int.int_game_environment — game-level venue and weather
int.int_team_season_context — season-level team context
int.int_team_season_features — season-level features; authoritative for
conference and sp_rating
raw.games — home/away points, teams, conference_game flag
raw.plays — play-level table for derived features


FBS Integrity Check — Mandatory After Every Load
Both teams must have a row in int_team_season_features with
conference != 'FBS Independents'. conference_game = TRUE does not filter
out FCS or Independent opponents. The INNER JOIN to int_team_season_features
handles non-FBS teams. The conference != 'FBS Independents' filter handles
Independents. Both filters required. Assert after every load — if FBS
Independents appears, stop and fix before proceeding.

How To Update This Document
At the end of every session:

Update the date at the top
Add any new locked decisions with justification
Mark completed EDAs with findings summary
Update open questions if new ones have emerged
Commit: git add docs/cfb_model_rebuild_plan.md && git commit -m "docs: update rebuild plan after [session description]" && git push