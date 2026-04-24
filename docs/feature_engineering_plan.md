# Feature Engineering Plan

**Target game:** Liberty vs Coastal Carolina, September 24, 2026
**Designed:** Day 4 (2026-04-23)
**Status:** SQL ready for all Day 5 models. Day 6 features scoped, not yet SQL-ready.

---

## Grain decision

The Bayesian model uses a hierarchical Poisson likelihood that updates on sequential evidence. The likelihood function needs each team's state *immediately before each specific game* — season-level grain would collapse the sequential structure and make the rolling window features meaningless. All momentum features therefore live at game grain.

---

## Day 5 models — three new silver models

### 1. `int_game_environment`
**Grain:** one row per game
**Schema:** `int`
**Status:** SQL ready

| Column | Description | Source |
|---|---|---|
| `venue_elevation_ft` | Absolute altitude of game venue | `stg_venues.elevation_feet` via `stg_games.venue_id` |
| `away_elevation_delta_ft` | Game venue elevation − away team home venue elevation (positive = ascending) | Same, via `home_venue_by_team_season` CTE |
| `away_elevation_ascent_ft` | `GREATEST(away_elevation_delta_ft, 0)` — harmful direction only | Derived |
| `is_dome` | Whether game venue is a dome | `stg_venues.dome` via `stg_games.venue_id` |
| `away_travel_distance_mi` | Great-circle distance between away team home venue and game venue | `earth_distance(ll_to_earth(...))` / 1609.344 |
| `away_tz_delta_hrs` | Signed timezone offset: game venue UTC offset − away home venue UTC offset. Positive = traveling east (losing time) | `COALESCE(stg_venues.timezone, state CASE)` + Postgres `AT TIME ZONE` for DST |

**Design notes:**
- Travel distance uses the Postgres `earthdistance` extension (`cube` + `earthdistance` modules), installed and wired into `dbt_project.yml` via `on-run-start` hooks so it survives container recreation.
- Timezone resolved via `COALESCE(stg_venues.timezone, state-based CASE statement)`. The IANA timezone column in `stg_venues` covers 38.7% of FBS game venues and correctly handles all split-timezone edge cases (Neyland Stadium = `America/New_York`, Sun Bowl = `America/Denver`, Nashville venues = `America/Chicago`). The state CASE only fires for venues where state → timezone is unambiguous.
- DST is handled automatically by Postgres `AT TIME ZONE` applied to the game's actual start timestamp — no hardcoded summer offsets.
- Both target game venues have `America/New_York` in `stg_venues.timezone`: Williams Stadium (Liberty, Lynchburg VA) and Brooks Stadium (Coastal Carolina, Conway SC). `away_tz_delta_hrs = 0` for the target game.
- `home_games_in_dome_pct` was considered and dropped — near-zero variance for FBS teams (only a handful of FCS permanent-dome programs). `is_dome` retained as a game-level boolean.

**Join path for away team home venue:**
No direct team → venue FK exists anywhere in the schema. Away team home venue is derived by taking `MODE() WITHIN GROUP (ORDER BY venue_id)` across non-neutral home games for that team-season in `stg_games`. This CTE (`home_venue_by_team_season`) is shared across elevation, travel distance, and timezone calculations.

---

### 2. `int_game_team_features`
**Grain:** one row per team per game (UNION ALL pattern — each game produces two rows)
**Schema:** `int`
**Status:** SQL ready

| Column | Description | Source |
|---|---|---|
| `last3_games_epa_avg` | Rolling average offensive EPA per play over the 3 games immediately preceding this game | `raw.plays.ppa` aggregated to game level, window function |
| `last3_games_win_pct` | Win rate over the 3 games immediately preceding this game | `stg_games` win/loss, window function |
| `days_since_last_game` | Calendar days of rest before this game | `LAG(game_date)` window function |
| `opp_sp_rating_at_game_time` | Opponent's prior-year final SP+ rating | `stg_sp_ratings` joined on `season - 1` |

**Leakage-free window design:**

All rolling features use `ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING` in the window frame:

```sql
AVG(off_epa_per_play) OVER (
    PARTITION BY team_name, season
    ORDER BY game_date, game_id      -- game_id breaks same-day ties
    ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
)
```

This guarantees the current game is never included in its own features. Behavior at season boundaries:
- Game 1 of season → `NULL` (no prior games — correct)
- Game 2 → window of 1 prior game
- Game 3 → window of 2 prior games
- Game 4+ → full 3-game window

Partitioning by `(team_name, season)` means no information crosses season boundaries. Week 1 nulls are expected and will be handled via imputation in PyMC.

**EPA source:**
`stg_advanced_stats` is season-level only and cannot power game-level rolling windows. Game-level EPA comes from `raw.plays.ppa` (PPA = EPA in CFBD terminology). `AVG(ppa)` naturally ignores NULLs — special-teams plays (Punt, Kickoff, Timeout) carry `ppa = NULL` and are excluded without an explicit filter. Skill-play null rate is 0.2–0.3%, negligible.

**`opp_sp_rating_at_game_time` — leakage decision:**

`stg_sp_ratings` contains exactly one row per team per season with no week or date column — these are **end-of-season final ratings**. Using the current-season rating to predict in-season games is severe leakage (the rating incorporates results of the game being predicted).

**Safe proxy: prior-year final SP+ (`season = game_season - 1`).** This is fully known before Week 1 and is what SP+ is designed for — each year's final rating is the prior for the next year's preseason projection. Known limitations:
- 2022 games have no 2021 SP+ in the dataset → `NULL` for all 2022 `opp_sp_rating_at_game_time`. Accept as missing; impute with league mean in PyMC.
- For the target game (Sep 24, 2026): join to `season = 2025` — both teams' 2025 final SP+ ratings are present and leakage-free.

---

### 3. `int_team_season_context`
**Grain:** one row per team per season
**Schema:** `int`
**Status:** SQL ready. All columns derived directly from `int_team_season_features` — no new joins required.

| Column | Formula | Notes |
|---|---|---|
| `scoring_efficiency_ratio` | `avg_points_scored / (total_yards / stat_games)` | `avg_yards_per_game` is not a stored column; derive from `total_yards / stat_games` |
| `turnover_margin_per_game` | `(interceptions_gained + fumbles_recovered - turnovers) / stat_games` | No `turnovers_forced` column exists; sum components |
| `epa_differential` | Already exists in `int_team_season_features` | Confirmed correct: max discrepancy from `off_epa_per_play - def_epa_per_play` is 0.000050 (floating-point rounding only) |

```sql
ROUND(
    avg_points_scored / NULLIF(total_yards::numeric / NULLIF(stat_games, 0), 0),
    4
) AS scoring_efficiency_ratio,

ROUND(
    (interceptions_gained + fumbles_recovered - turnovers)::numeric
    / NULLIF(stat_games, 0),
    4
) AS turnover_margin_per_game
```

---

## Day 6 features — scoped, not yet SQL-ready

### Weather pipeline
**Day 6 task — bronze ingestion + staging + int_game_environment additions**

Weather is non-optional for this model. The season spans August through January and covers three distinct risk categories:
- **Hurricane season / coastal exposure:** Coastal Carolina (Conway, SC) plays Atlantic-coast opponents in September. A tropical system can push 30+ mph sustained winds inland.
- **November Big Ten / cold-weather games:** Below-freezing temperatures and snow materially suppress scoring volume and flatten offenses. These games are systematic outliers in any EPA-based model.
- **Mountain West altitude + afternoon thunderstorms:** Late-summer afternoon games at Falcon Stadium (Colorado Springs), Folsom Field (Boulder), and War Memorial Stadium (Laramie) routinely see lightning delays and post-thunderstorm conditions.

Dome games are fully exempt — `is_dome = true` sets all weather features to neutral values at the `int_game_environment` layer, not in the raw or staging layers.

#### Kickoff time resolution

**Confirmed:** `stg_games.start_date` contains accurate UTC kickoff timestamps for 100% of games (e.g., `2022-11-13T00:00:00.000Z` = 7pm EST, confirmed against `raw.plays.wallclock` for the same game). The UTC hour-0 bucket (778 regular-season games) represents legitimate 7–8pm ET kickoffs, not date-only placeholders.

**`raw.plays.wallclock`** is not a reliable fallback — many entries show `T00:00:00.000Z` (midnight placeholder), and play data covers only 5,881 of 14,468 FBS games. Do not use it for kickoff hour resolution.

**Kickoff hour derivation (primary):**
```python
# In the ingestion script, convert UTC start_date to venue local time
from datetime import datetime, timezone
import pytz

utc_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
local_dt = utc_dt.astimezone(pytz.timezone(venue_tz))
kickoff_hour = local_dt.hour   # pass this to Open-Meteo hourly index
kickoff_date = local_dt.date() # use local date, not UTC date — Hawai'i night games cross UTC midnight
```

The venue timezone (`venue_tz`) comes from the same `COALESCE(stg_venues.timezone, state CASE)` logic already designed for `away_tz_delta_hrs`.

---

#### Layer 1 — Bronze: `raw.game_weather`

**Source:** Open-Meteo Historical Weather API (free, no API key required)
**Endpoint:** `https://archive-api.open-meteo.com/v1/archive`
**Rate limit:** ~10,000 requests/day on free tier (~3,000–4,000 FBS games in the training set — fits in a single day's run)

**Input query per game:**
```
?latitude={venue_lat}
&longitude={venue_lon}
&start_date={local_kickoff_date}
&end_date={local_kickoff_date}
&hourly=temperature_2m,wind_speed_10m,wind_gusts_10m,precipitation,relative_humidity_2m,weather_code
&wind_speed_unit=mph
&temperature_unit=fahrenheit
&precipitation_unit=inch
&timezone=auto
```

Passing `timezone=auto` with venue coordinates tells Open-Meteo to return local-time hourly indices — avoids manual UTC offset math in the script. Select the hourly observation at index `kickoff_hour`.

**Ingestion logic (pseudocode):**
```python
import requests, psycopg2, time

conn = psycopg2.connect(...)

# Pull every FBS regular-season game with venue lat/lon
games = query("""
    SELECT g.game_id, g.start_date, v.venue_id,
           v.latitude, v.longitude, v.timezone
    FROM stg.stg_games g
    JOIN stg.stg_venues v ON v.venue_id = g.venue_id::integer
    WHERE g.season_type = 'regular'
      AND g.home_conference IS NOT NULL
      AND g.away_conference IS NOT NULL
      AND v.latitude IS NOT NULL
      -- Skip games already fetched (bronze is append-only)
      AND g.game_id NOT IN (SELECT game_id FROM raw.game_weather)
""")

for game in games:
    kickoff_dt = to_local(game.start_date, game.timezone)
    resp = requests.get("https://archive-api.open-meteo.com/v1/archive", params={
        "latitude": game.latitude, "longitude": game.longitude,
        "start_date": kickoff_dt.date(), "end_date": kickoff_dt.date(),
        "hourly": "temperature_2m,wind_speed_10m,wind_gusts_10m,precipitation,relative_humidity_2m,weather_code",
        "wind_speed_unit": "mph", "temperature_unit": "fahrenheit",
        "precipitation_unit": "inch", "timezone": "auto"
    })
    hour_idx = kickoff_dt.hour
    h = resp.json()["hourly"]
    insert_row(game.game_id, game.venue_id, kickoff_dt.date(), hour_idx,
               h["temperature_2m"][hour_idx], h["wind_speed_10m"][hour_idx],
               h["wind_gusts_10m"][hour_idx], h["precipitation"][hour_idx],
               h["relative_humidity_2m"][hour_idx], h["weather_code"][hour_idx])
    time.sleep(0.1)  # ~10 req/sec, well within free tier
```

**Table DDL:**
```sql
CREATE TABLE raw.game_weather (
    game_id            bigint        NOT NULL,
    venue_id           integer,
    game_date          date,
    kickoff_hour       smallint,
    temperature_f      numeric(5,1),
    wind_speed_mph     numeric(5,1),
    wind_gusts_mph     numeric(5,1),
    precipitation_in   numeric(5,3),
    humidity_pct       smallint,
    weather_code       smallint,
    fetched_at         timestamp     NOT NULL DEFAULT now(),
    PRIMARY KEY (game_id)
);
```

Bronze layer rules apply — rows are never updated or deleted. Re-runs skip already-fetched `game_id`s via the `NOT IN` filter in the query above.

---

#### Layer 2 — Staging: `stg_game_weather`

Standard staging only — column renaming, type casting, no feature engineering.

```sql
select
    game_id,
    venue_id,
    game_date,
    kickoff_hour,
    temperature_f,
    wind_speed_mph,
    wind_gusts_mph,
    precipitation_in                  as precipitation_inches,
    humidity_pct,
    weather_code
from {{ source('raw', 'game_weather') }}
```

No derived booleans, no dome adjustments, no thresholds at this layer.

---

#### Layer 3 — Features: additions to `int_game_environment`

All feature engineering and dome overrides happen here.

| Column | Type | Logic |
|---|---|---|
| `temperature_f` | numeric | Raw value from `stg_game_weather`. Meaningful below 35°F and above 95°F for scoring impact. |
| `wind_speed_mph` | numeric | Raw value. |
| `wind_gusts_mph` | numeric | Raw value. |
| `is_high_wind` | boolean | `wind_speed_mph > 15 OR wind_gusts_mph > 25` |
| `precipitation_inches` | numeric | Raw value. |
| `is_precipitation` | boolean | `precipitation_inches > 0.05` (filters drizzle/trace from meaningful rain) |
| `is_dome_adjusted_weather` | boolean | `true` when `is_dome = true` — signals that weather features below have been set to neutral |

**Dome override logic:**
```sql
case
    when is_dome then 68.0
    else temperature_f
end                              as temperature_f,

case
    when is_dome then 0.0
    else wind_speed_mph
end                              as wind_speed_mph,

case
    when is_dome then 0.0
    else wind_gusts_mph
end                              as wind_gusts_mph,

case
    when is_dome then false
    else wind_speed_mph > 15 or wind_gusts_mph > 25
end                              as is_high_wind,

case
    when is_dome then 0.0
    else precipitation_inches
end                              as precipitation_inches,

case
    when is_dome then false
    else precipitation_inches > 0.05
end                              as is_precipitation,

is_dome                          as is_dome_adjusted_weather
```

Neutral values: 68°F, 0 mph wind, 0 inches precipitation. These are chosen as inert for the model — not averages, but values that contribute near-zero weather signal, which is correct for a controlled indoor environment.

---

#### Layer 4 — Forward-looking fetch (production task)

A second script is required for live game prediction. Same structure as the historical fetch but against the Open-Meteo forecast API:

**Endpoint:** `https://api.open-meteo.com/v1/forecast`
**Same parameters**, but `start_date` / `end_date` are set to the upcoming game date.

**Operational cadence for target game (Liberty vs Coastal Carolina, Sep 24, 2026):**
- Run the forecast fetch the week of **September 21, 2026**
- The 7-day forecast window covers September 24 with sufficient lead time for sportsbook line movement analysis
- Re-run daily through game week to capture forecast updates — insert new rows with updated `fetched_at`, keep all versions for forecast tracking

**Note:** Forecast rows live in a separate table (`raw.game_weather_forecast`) to preserve the append-only integrity of `raw.game_weather` (historical actuals). Never mix forecast and observed values in the same table.

### Pace-adjusted stats
Derivable from existing columns in `int_team_season_features`. No new data required.

| Feature | Formula | Target |
|---|---|---|
| `plays_per_game` | `(pass_attempts + rush_attempts) / stat_games` | Spread / tempo proxy |
| `off_epa_total_per_game` | `off_epa_per_play × plays_per_game` | **Strongest Over/Under signal** — total EPA generated per game regardless of pace |

**Rationale:** A team with high EPA per play but low pace generates less total offense than a team with moderate EPA per play and high tempo. `off_epa_total_per_game` captures the production that actually ends up on the scoreboard.

### Game script and garbage-time filtering
**Day 6 task — additions to `int_game_team_features` and `int_team_season_context`**

#### Score column verification

`raw.plays.offense_score` and `raw.plays.defense_score` are **cumulative running totals** that reflect the score at the time each play runs. Confirmed against Alabama vs Texas A&M (2022): three plays before Alabama's first TD show 0-0; the TD play itself shows 7-0; Texas A&M's first subsequent play shows their perspective as 0-7. The score updates **on the scoring play itself**, not the following play.

Coverage: 100% populated across all 1,039,296 regular-season plays. `period` column: fully populated, values 1–4 for regulation and 5–9 for overtime (2,262 OT plays in the regular-season dataset).

Penalty plays show inconsistent scores in some rows but have 99.9% null `ppa` — they self-exclude from all `AVG(ppa)` calculations and require no special handling.

---

#### Feature 1 — `close_game_epa_per_play`

**Grain:** game level in `int_game_team_features`; season average in `int_team_season_context`

**Definition:** `AVG(ppa)` restricted to competitive game situations. Strips garbage-time drives that contaminate season-average EPA for dominant teams and prevent-defense sequences that inflate EPA for losing teams.

**Exclusion rules:**
- `period NOT IN (1,2,3,4)` — overtime excluded entirely (periods 5–9)
- `period >= 3 AND ABS(offense_score - defense_score) > 38` — blowout filter applies from Q3 onward
- `period = 4 AND ABS(offense_score - defense_score) > 28` — tighter Q4 cutoff captures prevent-defense sequences

Q1 and Q2 have no margin filter — all plays included regardless of score.

```sql
-- In int_game_team_features (game level per team)
with close_game_epa as (
    select
        p.game_id,
        p.offense                                        as team_name,
        avg(p.ppa)                                       as close_game_epa_per_play,
        count(p.ppa)                                     as close_game_play_count
    from raw.plays p
    where p.season_type = 'regular'
      and p.period between 1 and 4
      and not (p.period >= 3 and abs(p.offense_score - p.defense_score) > 38)
      and not (p.period = 4 and abs(p.offense_score - p.defense_score) > 28)
    group by p.game_id, p.offense
)

-- Season average in int_team_season_context
avg(close_game_epa_per_play)   as close_game_epa_per_play_season_avg,
sum(close_game_play_count)     as close_game_plays_total
```

---

#### Feature 2 — `game_script`

**Grain:** categorical label at game level in `int_game_team_features`; five percentage columns in `int_team_season_context`

**Definition:** each game is classified by the team's average offensive score differential across all plays they were on offense. Uses all plays including overtime — this is a game narrative feature, not an EPA quality filter.

| Label | Condition |
|---|---|
| `dominant` | avg margin > +21 |
| `comfortable` | avg margin +11 to +21 |
| `competitive` | avg margin −9 to +10 |
| `deficit` | avg margin −10 to −21 |
| `large_deficit` | avg margin < −21 |

**Rationale:** a team with 40% dominant games has a fundamentally different risk profile than one with 40% competitive games at the same season EPA. Dominant teams run up scores against weak opponents and see their EPA inflated; competitive teams are battle-tested but face higher variance. The distribution captures both offensive identity and defensive quality in a single compact representation.

```sql
-- Game-level classification (int_game_team_features)
with game_margins as (
    select
        p.game_id, p.season,
        p.offense                                        as team_name,
        avg(p.offense_score - p.defense_score)           as avg_margin
    from raw.plays p
    where p.season_type = 'regular'
    group by p.game_id, p.season, p.offense
),

game_script_labeled as (
    select
        game_id, season, team_name, avg_margin,
        case
            when avg_margin >   21 then 'dominant'
            when avg_margin >   10 then 'comfortable'
            when avg_margin >=  -9 then 'competitive'
            when avg_margin >= -21 then 'deficit'
            else                        'large_deficit'
        end                                              as game_script
    from game_margins
)

-- Season distribution (int_team_season_context)
select
    team_name, season,
    round(avg(case when game_script = 'dominant'      then 1.0 else 0.0 end), 3) as pct_games_dominant,
    round(avg(case when game_script = 'comfortable'   then 1.0 else 0.0 end), 3) as pct_games_comfortable,
    round(avg(case when game_script = 'competitive'   then 1.0 else 0.0 end), 3) as pct_games_competitive,
    round(avg(case when game_script = 'deficit'       then 1.0 else 0.0 end), 3) as pct_games_deficit,
    round(avg(case when game_script = 'large_deficit' then 1.0 else 0.0 end), 3) as pct_games_large_deficit
from game_script_labeled
group by team_name, season
```

---

#### Feature 3a — `close_game_count` (fast approximation)

**Grain:** team-season level in `int_team_season_context`. Reads from `stg_games` — no `raw.plays` join required.

**Definition:** number of regular-season games per team-season where the **final score** margin was ≤ 14 points.

**Model role:** reliability weight on `close_game_epa_per_play`. A team with 3 close games has a much noisier filtered-EPA estimate than one with 9. Used as a precision parameter in PyMC — higher count → tighter prior on close-game EPA, lower count → wider credible interval.

```sql
with close_game_flags as (
    select home_team as team_name, season,
           case when abs(home_points - away_points) <= 14 then 1 else 0 end as is_close
    from stg.stg_games
    where season_type = 'regular' and home_points is not null

    union all

    select away_team as team_name, season,
           case when abs(home_points - away_points) <= 14 then 1 else 0 end as is_close
    from stg.stg_games
    where season_type = 'regular' and home_points is not null
)

select team_name, season,
       sum(is_close)   as close_game_count
from close_game_flags
group by team_name, season
```

**Known limitation — garbage-time final score contamination:**

Final scores are not a clean signal for competitive game quality. A game that was 35–0 at halftime can end 49–28 because starters were pulled in the fourth quarter. That game would be classified as a close game (21-point final margin ≤ 14 is outside the threshold, but a 35–28 blowout-turned-close game would not). More critically, prevent-defense sequences and garbage-time drives systematically inflate scores in one direction, pulling final margins toward false competitiveness.

`close_game_epa_per_play` already handles this correctly — it uses in-play `offense_score` / `defense_score` from `raw.plays` and filters by margin *at the time of each play*, not the final score. `close_game_count` using final scores is therefore an inconsistent reliability weight for that feature. It is retained as a fast approximation pending EDA to determine whether the two versions diverge materially.

---

#### Feature 3b — `close_game_count_plays_based` (blowout-resistant)

**Grain:** team-season level in `int_team_season_context`. Requires `raw.plays`.

**Definition:** number of regular-season games per team-season where the in-game score differential was within 14 points for **at least 50% of regulation plays**.

This directly measures competitive game duration rather than final score proximity. A team that led 35–0 at halftime and won 49–28 records 0 competitive plays in Q3–Q4 and fails the 50% threshold — correctly excluded. A team that trailed 28–21 all game before a late TD wins 35–28 and correctly passes.

```sql
with regulation_plays as (
    select
        p.game_id,
        p.offense                                              as team_name,
        p.season,
        count(*)                                               as total_plays,
        count(*) filter (
            where abs(p.offense_score - p.defense_score) <= 14
        )                                                      as plays_within_14
    from raw.plays p
    where p.season_type = 'regular'
      and p.period between 1 and 4   -- regulation only
    group by p.game_id, p.offense, p.season
),

close_game_flags_plays as (
    select
        team_name, season,
        case
            when plays_within_14::numeric / nullif(total_plays, 0) >= 0.50
            then 1 else 0
        end                                                    as is_close_plays_based
    from regulation_plays
)

select team_name, season,
       sum(is_close_plays_based)   as close_game_count_plays_based
from close_game_flags_plays
group by team_name, season
```

**Compute cost:** requires a full `raw.plays` scan grouped by game and team — roughly the same cost as `close_game_epa_per_play`, which runs in the same CTE context. No additional join overhead.

**EDA decision point:** run both versions and compute the correlation between `close_game_count` and `close_game_count_plays_based` across team-seasons. If Pearson r > 0.90, the fast version is an adequate proxy. If r < 0.85, the garbage-time contamination is material and the plays-based version should replace it in the model.

---

---

## Phase 2 features — player continuity and roster stability

**Phase 2 does not block Day 5 or Day 6.** These features require additional data ingestion or fragile text parsing and are documented here for design alignment before implementation begins.

**Core problem:** college football has no mandated injury reporting. CFBD has no structured injury table. Player availability must be inferred from behavioral signals in the play-by-play data.

---

### Data availability audit

#### `raw.plays` — player identity

No structured passer, rusher, or player column exists. The full schema has 30 columns; the only player-identifiable field is `play_text` (free text). Format is consistent for most plays:

```
"Austin Reed pass complete to Malachi Corley for 6 yds to the WKent 31"
"Jakairi Moses run for 11 yds to the WKent 42 for a 1ST down"
"Austin Reed pass incomplete"
```

Extractable via regex:
- QB on dropback plays: `^(.+?)\s+pass\s+(complete|incomplete|intercepted|sack)`
- Primary ball carrier: `^(.+?)\s+run\s+for`

**Fragility:** option pitches, scrambles, wildcat formations, fumble recovery runs, and gadget plays produce non-standard text. Sufficient for identifying the primary QB by dropback volume across a season; insufficient for precise individual play attribution.

#### `raw.recruiting` — roster composition

Team-level class data only: `year`, `team`, `points`, `rank`, `commits`. No individual player records, no transfer flag, no eligibility year. Cannot support player-level continuity tracking.

#### Transfer portal — not in bronze layer

No transfer portal table exists. The CFBD API provides `/transferportal/players` with entry year, origin school, destination school, and position. This requires a new bronze table ingestion before `team_roster_turnover_index` can be built.

---

### Feature 1 — `qb_continuity_proxy`

**Phase:** 2a (buildable with current data via play_text parsing)
**Grain:** game level in `int_game_team_features`
**Model target:** spread and moneyline. QB change is the single largest mid-season signal in college football betting markets.

**Definition:**
- Identify the primary QB per team per season as the player with the most dropbacks across games 1–2 (pass completions + incompletions + sacks attributed to that player in play_text)
- Compute that player's dropback share per game going forward: `player_dropbacks / team_total_dropbacks`
- `qb_continuity_proxy = 0` if their share falls below 50% of their season-1-2 baseline for two consecutive games
- `qb_continuity_proxy = 1` otherwise (starter intact)

**Captures:** QB injury, benching, transfer mid-season, and academic suspension — all without requiring an injury report.

**Build path A — play_text regex (current data, fragile):**
```sql
-- Extract QB name from passing play_text
with dropbacks as (
    select
        game_id, season, week, offense          as team_name,
        regexp_match(
            play_text,
            '^(.+?)\s+pass\s+(complete|incomplete|intercepted)'
        )[1]                                    as qb_name
    from raw.plays
    where play_type in ('Pass Reception', 'Pass Incompletion',
                        'Passing Touchdown', 'Interception', 'Sack')
      and play_text is not null
      and season_type = 'regular'
),

-- Primary QB = highest dropback count in games 1-2 of season
primary_qb as (
    select team_name, season, qb_name,
           count(*)                             as early_dropbacks
    from dropbacks
    where week <= 2 and qb_name is not null
    group by team_name, season, qb_name
    qualify row_number() over (
        partition by team_name, season
        order by early_dropbacks desc
    ) = 1
),

-- Per-game share for primary QB
qb_game_share as (
    select d.game_id, d.season, d.week, d.team_name,
           count(*) filter (where d.qb_name = p.qb_name)::numeric
           / nullif(count(*), 0)               as primary_qb_share,
           max(p.early_dropbacks)::numeric
           / nullif(count(*), 0)               as baseline_share
    from dropbacks d
    join primary_qb p using (team_name, season)
    group by d.game_id, d.season, d.week, d.team_name
)

select *,
    case
        when primary_qb_share < 0.5 * baseline_share then 0
        else 1
    end                                        as qb_continuity_proxy
from qb_game_share
```

**Note:** `qualify` is not standard Postgres syntax — replace with a subquery using `WHERE rn = 1` after a `ROW_NUMBER()` window.

**Build path B — CFBD player game stats API (recommended, requires new bronze table):**

Ingest `/stats/player/games` from CFBD API into `raw.player_game_stats`. Columns include structured per-game passing attempts, completions, rushing carries by named player. Eliminates regex fragility entirely and correctly handles scrambles and wildcat. New bronze table required before this path is available.

---

### Feature 2 — `skill_position_continuity_proxy`

**Phase:** 2a (buildable with current data via play_text parsing)
**Grain:** game level in `int_game_team_features`

**Definition:** same logic as `qb_continuity_proxy` applied to the primary running back by carries in games 1–2. Dropback share replaced by carry share.

```sql
-- Extract primary ball carrier from rush play_text
regexp_match(play_text, '^(.+?)\s+run\s+for')[1]  as carrier_name
-- play_type IN ('Rush', 'Rushing Touchdown')
```

**Lower model impact than QB continuity** — losing a RB1 is significant but most FBS teams have viable depth at the position. Worth including as a feature but should receive a weaker prior in the model than `qb_continuity_proxy`.

Same build path A/B choice applies. Shares the `raw.player_game_stats` dependency for path B.

---

### Feature 3 — `team_roster_turnover_index`

**Phase:** 2b (requires new bronze table)
**Grain:** team-season level in `int_team_season_context`
**Model role:** moderates how much weight the model places on prior-year SP+ rating. High turnover = prior year SP+ is a weaker prior for current-season quality.

**What current data can support:**

`raw.recruiting` has team-level class rank and points per year. Year-over-year change in recruiting rank is a weak proxy for offseason roster change:

```sql
-- Weak proxy buildable now — recruiting rank delta, not true turnover
select
    team, year as season,
    rank as recruiting_rank,
    lag(rank) over (partition by team order by year) as prior_rank,
    rank - lag(rank) over (partition by team order by year) as rank_delta
from raw.recruiting
```

This captures recruiting trajectory but misses the core signal: how many starters from last year are still on the roster.

**What requires new ingestion:**

| New bronze table | CFBD endpoint | Key columns |
|---|---|---|
| `raw.transfer_portal` | `/transferportal/players` | `season`, `origin`, `destination`, `position`, `rating` |

With `raw.transfer_portal`, the index becomes:

```
team_roster_turnover_index =
  (transfers_out_rated + graduating_starters_proxy) /
  (returning_starters_proxy + transfers_in_rated)
```

Where `returning_starters_proxy` is approximated from `raw.player_game_stats` (players who had significant snaps/carries the prior season and are still on the roster this season).

**Build dependency:** `raw.player_game_stats` + `raw.transfer_portal` both required. Neither exists yet. This is a two-endpoint ingestion task before any SQL can be written.

---

### Phase 2 build sequence

| Step | Task | Dependency | Unlocks |
|---|---|---|---|
| 2a | `qb_continuity_proxy` via play_text regex | Current data | Immediate — fragile path |
| 2a | `skill_position_continuity_proxy` via play_text regex | Current data | Immediate — fragile path |
| 2b | Ingest `raw.player_game_stats` from CFBD `/stats/player/games` | CFBD_API_KEY in .env | Clean build paths for 2a features |
| 2b | Ingest `raw.transfer_portal` from CFBD `/transferportal/players` | CFBD_API_KEY in .env | `team_roster_turnover_index` |
| 2b | `team_roster_turnover_index` | Both new bronze tables | Season-level model prior moderation |

Recommendation: build path A for `qb_continuity_proxy` first as a proof-of-concept signal check. If the signal is significant in model validation, invest in path B before production.

---

## Data quality flags

| Issue | Severity | Resolution |
|---|---|---|
| `elevation_feet` coverage 38% in `stg_venues` | High — blocks elevation features | **First task Day 5:** USGS backfill script before any model building |
| 2022 `opp_sp_rating_at_game_time` = NULL (no 2021 SP+ in dataset) | Medium | Accept; impute with league mean in PyMC |
| 18 FCS team-seasons null on all stats columns | Low — benign | Propagates cleanly to `NULL` in derived ratios; no special handling needed. Teams: NDSU, Sacramento State, Delaware, Missouri State, Kennesaw State, Sam Houston, Jacksonville State |
| Same-week duplicate home appearances for 5 teams | Low | Handled: `ORDER BY game_date, game_id` in all window functions |
| `start_time_et` column in `stg_games` contains boolean values | Low — column unusable | Derive game time from `start_date::timestamptz AT TIME ZONE venue_tz` instead |
| `raw.plays.wallclock` unreliable for kickoff time | Low | Many entries are `T00:00:00.000Z` placeholders; coverage is 5,881 / 14,468 FBS games. Use `stg_games.start_date` exclusively for kickoff hour resolution |
| Weather fetch has no venue lat/lon for ~4% of FBS game venues | Low | `stg_venues.latitude` is null for 6 of 731 FBS game venues. These games get null weather features — impute with seasonal means in PyMC |
