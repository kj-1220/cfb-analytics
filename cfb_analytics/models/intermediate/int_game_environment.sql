{{
  config(
    materialized='table',
    schema='int'
  )
}}

/*
  int_game_environment
  Grain: one row per game (D1 only — FBS + FCS)
  Combines venue elevation, away team travel distance,
  timezone delta, and kickoff weather.
  Dome override: temperature=68, wind=0, precipitation=0 when is_dome=true.
*/

WITH d1_conferences AS (
    SELECT unnest(ARRAY[
        -- FBS
        'Big Ten', 'SEC', 'ACC', 'Big 12', 'Mountain West',
        'Sun Belt', 'American Athletic', 'Mid-American',
        'Conference USA', 'Pac-12', 'FBS Independents',
        -- FCS
        'CAA', 'MVFC', 'Big Sky', 'SWAC', 'Southern',
        'Southland', 'NEC', 'Patriot', 'Big South-OVC',
        'MEAC', 'Pioneer', 'Ivy'
    ]) AS conference
),

games AS (
    SELECT
        game_id,
        season,
        week,
        home_team,
        away_team,
        venue_id,
        neutral_site
    FROM {{ ref('stg_games') }}
    WHERE home_team IS NOT NULL
      AND away_team IS NOT NULL
      AND (
          home_conference IN (SELECT conference FROM d1_conferences)
          OR away_conference IN (SELECT conference FROM d1_conferences)
      )
),

venues AS (
    SELECT
        venue_id,
        dome,
        latitude,
        longitude,
        timezone,
        state
    FROM {{ ref('stg_venues') }}
),

elevations AS (
    SELECT
        venue_id,
        elevation_feet
    FROM {{ ref('venue_elevations') }}
),

weather AS (
    SELECT
        game_id,
        temperature_f,
        wind_speed_mph,
        wind_gusts_mph,
        precipitation_inches,
        humidity_pct
    FROM {{ ref('stg_game_weather') }}
),

home_venue_by_team_season AS (
    SELECT
        home_team                                               AS team,
        season,
        MODE() WITHIN GROUP (ORDER BY venue_id)                AS home_venue_id
    FROM {{ ref('stg_games') }}
    WHERE neutral_site = false
      AND home_team IS NOT NULL
      AND venue_id IS NOT NULL
      AND (
          home_conference IN (SELECT conference FROM d1_conferences)
          OR away_conference IN (SELECT conference FROM d1_conferences)
      )
    GROUP BY home_team, season
),

away_team_home_venue AS (
    SELECT
        hvts.team,
        hvts.season,
        hvts.home_venue_id,
        v.latitude                                             AS home_lat,
        v.longitude                                            AS home_lon,
        COALESCE(e.elevation_feet, 0)                          AS away_home_elevation_ft,
        COALESCE(
            v.timezone,
            CASE v.state
                WHEN 'AL' THEN 'America/Chicago'
                WHEN 'AK' THEN 'America/Anchorage'
                WHEN 'AZ' THEN 'America/Phoenix'
                WHEN 'AR' THEN 'America/Chicago'
                WHEN 'CA' THEN 'America/Los_Angeles'
                WHEN 'CO' THEN 'America/Denver'
                WHEN 'CT' THEN 'America/New_York'
                WHEN 'DE' THEN 'America/New_York'
                WHEN 'FL' THEN 'America/New_York'
                WHEN 'GA' THEN 'America/New_York'
                WHEN 'HI' THEN 'Pacific/Honolulu'
                WHEN 'ID' THEN 'America/Boise'
                WHEN 'IL' THEN 'America/Chicago'
                WHEN 'IN' THEN 'America/Indiana/Indianapolis'
                WHEN 'IA' THEN 'America/Chicago'
                WHEN 'KS' THEN 'America/Chicago'
                WHEN 'KY' THEN 'America/New_York'
                WHEN 'LA' THEN 'America/Chicago'
                WHEN 'ME' THEN 'America/New_York'
                WHEN 'MD' THEN 'America/New_York'
                WHEN 'MA' THEN 'America/New_York'
                WHEN 'MI' THEN 'America/Detroit'
                WHEN 'MN' THEN 'America/Chicago'
                WHEN 'MS' THEN 'America/Chicago'
                WHEN 'MO' THEN 'America/Chicago'
                WHEN 'MT' THEN 'America/Denver'
                WHEN 'NE' THEN 'America/Chicago'
                WHEN 'NV' THEN 'America/Los_Angeles'
                WHEN 'NH' THEN 'America/New_York'
                WHEN 'NJ' THEN 'America/New_York'
                WHEN 'NM' THEN 'America/Denver'
                WHEN 'NY' THEN 'America/New_York'
                WHEN 'NC' THEN 'America/New_York'
                WHEN 'ND' THEN 'America/Chicago'
                WHEN 'OH' THEN 'America/New_York'
                WHEN 'OK' THEN 'America/Chicago'
                WHEN 'OR' THEN 'America/Los_Angeles'
                WHEN 'PA' THEN 'America/New_York'
                WHEN 'RI' THEN 'America/New_York'
                WHEN 'SC' THEN 'America/New_York'
                WHEN 'SD' THEN 'America/Chicago'
                WHEN 'TN' THEN 'America/Chicago'
                WHEN 'TX' THEN 'America/Chicago'
                WHEN 'UT' THEN 'America/Denver'
                WHEN 'VT' THEN 'America/New_York'
                WHEN 'VA' THEN 'America/New_York'
                WHEN 'WA' THEN 'America/Los_Angeles'
                WHEN 'WV' THEN 'America/New_York'
                WHEN 'WI' THEN 'America/Chicago'
                WHEN 'WY' THEN 'America/Denver'
                ELSE 'America/Chicago'
            END
        )                                                      AS away_home_tz
    FROM home_venue_by_team_season hvts
    LEFT JOIN venues v ON hvts.home_venue_id = v.venue_id
    LEFT JOIN elevations e ON hvts.home_venue_id = e.venue_id
),

game_venue_details AS (
    SELECT
        g.game_id,
        g.season,
        g.week,
        g.home_team,
        g.away_team,
        g.venue_id,
        COALESCE(v.dome, false)                                AS is_dome,
        v.latitude                                             AS venue_lat,
        v.longitude                                            AS venue_lon,
        COALESCE(e.elevation_feet, 0)                          AS venue_elevation_ft,
        COALESCE(
            v.timezone,
            CASE v.state
                WHEN 'AL' THEN 'America/Chicago'
                WHEN 'AK' THEN 'America/Anchorage'
                WHEN 'AZ' THEN 'America/Phoenix'
                WHEN 'AR' THEN 'America/Chicago'
                WHEN 'CA' THEN 'America/Los_Angeles'
                WHEN 'CO' THEN 'America/Denver'
                WHEN 'CT' THEN 'America/New_York'
                WHEN 'DE' THEN 'America/New_York'
                WHEN 'FL' THEN 'America/New_York'
                WHEN 'GA' THEN 'America/New_York'
                WHEN 'HI' THEN 'Pacific/Honolulu'
                WHEN 'ID' THEN 'America/Boise'
                WHEN 'IL' THEN 'America/Chicago'
                WHEN 'IN' THEN 'America/Indiana/Indianapolis'
                WHEN 'IA' THEN 'America/Chicago'
                WHEN 'KS' THEN 'America/Chicago'
                WHEN 'KY' THEN 'America/New_York'
                WHEN 'LA' THEN 'America/Chicago'
                WHEN 'ME' THEN 'America/New_York'
                WHEN 'MD' THEN 'America/New_York'
                WHEN 'MA' THEN 'America/New_York'
                WHEN 'MI' THEN 'America/Detroit'
                WHEN 'MN' THEN 'America/Chicago'
                WHEN 'MS' THEN 'America/Chicago'
                WHEN 'MO' THEN 'America/Chicago'
                WHEN 'MT' THEN 'America/Denver'
                WHEN 'NE' THEN 'America/Chicago'
                WHEN 'NV' THEN 'America/Los_Angeles'
                WHEN 'NH' THEN 'America/New_York'
                WHEN 'NJ' THEN 'America/New_York'
                WHEN 'NM' THEN 'America/Denver'
                WHEN 'NY' THEN 'America/New_York'
                WHEN 'NC' THEN 'America/New_York'
                WHEN 'ND' THEN 'America/Chicago'
                WHEN 'OH' THEN 'America/New_York'
                WHEN 'OK' THEN 'America/Chicago'
                WHEN 'OR' THEN 'America/Los_Angeles'
                WHEN 'PA' THEN 'America/New_York'
                WHEN 'RI' THEN 'America/New_York'
                WHEN 'SC' THEN 'America/New_York'
                WHEN 'SD' THEN 'America/Chicago'
                WHEN 'TN' THEN 'America/Chicago'
                WHEN 'TX' THEN 'America/Chicago'
                WHEN 'UT' THEN 'America/Denver'
                WHEN 'VT' THEN 'America/New_York'
                WHEN 'VA' THEN 'America/New_York'
                WHEN 'WA' THEN 'America/Los_Angeles'
                WHEN 'WV' THEN 'America/New_York'
                WHEN 'WI' THEN 'America/Chicago'
                WHEN 'WY' THEN 'America/Denver'
                ELSE 'America/Chicago'
            END
        )                                                      AS venue_tz
    FROM games g
    LEFT JOIN venues v ON g.venue_id = v.venue_id
    LEFT JOIN elevations e ON g.venue_id = e.venue_id
),

tz_offset_map (tz_name, utc_offset_hrs) AS (
    VALUES
        ('America/New_York',                 -5),
        ('America/Detroit',                  -5),
        ('America/Indiana/Indianapolis',     -5),
        ('America/Kentucky/Louisville',      -5),
        ('America/Chicago',                  -6),
        ('America/Denver',                   -7),
        ('America/Boise',                    -7),
        ('America/Phoenix',                  -7),
        ('America/Los_Angeles',              -8),
        ('America/Anchorage',                -9),
        ('Pacific/Honolulu',                -10)
),

assembled AS (
    SELECT
        gvd.game_id,
        gvd.season,
        gvd.week,
        gvd.home_team,
        gvd.away_team,
        gvd.venue_id,
        gvd.is_dome,
        gvd.venue_elevation_ft,
        COALESCE(athv.away_home_elevation_ft, 0)               AS away_home_elevation_ft,
        CASE
            WHEN gvd.venue_lat IS NOT NULL
             AND gvd.venue_lon IS NOT NULL
             AND athv.home_lat IS NOT NULL
             AND athv.home_lon IS NOT NULL
            THEN earth_distance(
                     ll_to_earth(gvd.venue_lat, gvd.venue_lon),
                     ll_to_earth(athv.home_lat, athv.home_lon)
                 ) / 1609.344
            ELSE NULL
        END                                                    AS away_travel_distance_mi,
        COALESCE(venue_tz_off.utc_offset_hrs, -6)
          - COALESCE(away_tz_off.utc_offset_hrs, -6)           AS away_tz_delta_hrs,
        w.temperature_f                                        AS raw_temperature_f,
        w.wind_speed_mph                                       AS raw_wind_speed_mph,
        w.wind_gusts_mph                                       AS raw_wind_gusts_mph,
        w.precipitation_inches                                 AS raw_precipitation_inches,
        w.humidity_pct
    FROM game_venue_details gvd
    LEFT JOIN away_team_home_venue athv
        ON  gvd.away_team = athv.team
        AND gvd.season    = athv.season
    LEFT JOIN tz_offset_map venue_tz_off
        ON  gvd.venue_tz      = venue_tz_off.tz_name
    LEFT JOIN tz_offset_map away_tz_off
        ON  athv.away_home_tz = away_tz_off.tz_name
    LEFT JOIN weather w
        ON  gvd.game_id = w.game_id
)

SELECT
    game_id,
    season,
    week,
    home_team,
    away_team,
    venue_id,
    is_dome,
    venue_elevation_ft,
    away_home_elevation_ft,
    (venue_elevation_ft - away_home_elevation_ft)              AS away_elevation_delta_ft,
    GREATEST(venue_elevation_ft - away_home_elevation_ft, 0)   AS away_elevation_ascent_ft,
    ROUND(away_travel_distance_mi::NUMERIC, 1)                 AS away_travel_distance_mi,
    away_tz_delta_hrs,
    CASE WHEN is_dome THEN 68 ELSE raw_temperature_f        END::NUMERIC AS temperature_f,
    CASE WHEN is_dome THEN 0  ELSE raw_wind_speed_mph       END::NUMERIC AS wind_speed_mph,
    CASE WHEN is_dome THEN 0  ELSE raw_wind_gusts_mph       END::NUMERIC AS wind_gusts_mph,
    CASE WHEN is_dome THEN 0  ELSE raw_precipitation_inches END::NUMERIC AS precipitation_inches,
    humidity_pct,
    CASE
        WHEN is_dome THEN false
        ELSE (raw_wind_speed_mph > 15 OR raw_wind_gusts_mph > 25)
    END                                                        AS is_high_wind,
    CASE
        WHEN is_dome THEN false
        ELSE (raw_precipitation_inches > 0.05)
    END                                                        AS is_precipitation,
    is_dome                                                    AS is_dome_adjusted_weather
FROM assembled
