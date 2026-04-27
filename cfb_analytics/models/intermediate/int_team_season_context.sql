{{
  config(
    materialized='table',
    schema='int'
  )
}}

with base as (
    select * from {{ ref('int_team_season_features') }}
),

/*
  close_game_epa_season: season averages of garbage-time filtered EPA.
  Aggregated from int_game_team_features where close_game_play_count > 0
  ensures we only average games where competitive plays existed.
*/
close_game_epa_season as (
    select
        team_name,
        season,
        round(avg(close_game_epa_per_play)::numeric, 4)        as close_game_epa_per_play_season_avg,
        sum(close_game_play_count)                              as close_game_plays_total
    from {{ ref('int_game_team_features') }}
    where close_game_play_count > 0
    group by team_name, season
),

/*
  game_script_dist: season distribution of game script labels.
  Five percentage columns sum to 1.0 per team-season.
*/
game_script_dist as (
    select
        team_name,
        season,
        round(avg(case when game_script = 'dominant'      then 1.0 else 0.0 end)::numeric, 3) as pct_games_dominant,
        round(avg(case when game_script = 'comfortable'   then 1.0 else 0.0 end)::numeric, 3) as pct_games_comfortable,
        round(avg(case when game_script = 'competitive'   then 1.0 else 0.0 end)::numeric, 3) as pct_games_competitive,
        round(avg(case when game_script = 'deficit'       then 1.0 else 0.0 end)::numeric, 3) as pct_games_deficit,
        round(avg(case when game_script = 'large_deficit' then 1.0 else 0.0 end)::numeric, 3) as pct_games_large_deficit
    from {{ ref('int_game_team_features') }}
    where game_script is not null
    group by team_name, season
),

/*
  close_game_count: fast approximation from final scores.
  Games where abs(home_points - away_points) <= 14.
  Known limitation: garbage-time scoring can pull blowouts
  toward false competitiveness. Retained as fast proxy;
  EDA will determine if plays-based version should replace it.
*/
close_game_flags_score as (
    select home_team as team_name, season,
           case when abs(home_points - away_points) <= 14 then 1 else 0 end as is_close
    from {{ ref('stg_games') }}
    where season_type = 'regular'
      and home_points is not null

    union all

    select away_team as team_name, season,
           case when abs(home_points - away_points) <= 14 then 1 else 0 end as is_close
    from {{ ref('stg_games') }}
    where season_type = 'regular'
      and home_points is not null
),

close_game_count_score as (
    select
        team_name,
        season,
        sum(is_close)                                           as close_game_count
    from close_game_flags_score
    group by team_name, season
),

/*
  close_game_count_plays_based: blowout-resistant version.
  Games where the score was within 14 points for >= 50% of
  regulation plays. Correctly excludes games that were
  blowouts despite a close final score.
*/
regulation_plays as (
    select
        game_id,
        offense                                                 as team_name,
        season,
        count(*)                                                as total_plays,
        count(*) filter (
            where abs(offense_score - defense_score) <= 14
        )                                                       as plays_within_14
    from {{ source('raw', 'plays') }}
    where season_type = 'regular'
      and period between 1 and 4
    group by game_id, offense, season
),

close_game_flags_plays as (
    select
        team_name,
        season,
        case
            when plays_within_14::numeric / nullif(total_plays, 0) >= 0.50
            then 1 else 0
        end                                                     as is_close_plays_based
    from regulation_plays
),

close_game_count_plays as (
    select
        team_name,
        season,
        sum(is_close_plays_based)                               as close_game_count_plays_based
    from close_game_flags_plays
    group by team_name, season
),

final as (
    select
        -- keys
        b.team_name,
        b.season,
        b.conference,

        -- -------------------------
        -- OFFENSIVE EFFICIENCY
        -- -------------------------
        b.off_epa_per_play,
        b.off_epa_total,
        b.off_passing_epa,
        b.off_rushing_epa,
        b.off_success_rate,
        b.off_pass_success_rate,
        b.off_rush_success_rate,
        b.off_explosiveness,
        b.off_std_downs_success_rate,
        b.off_pass_downs_success_rate,
        b.off_std_downs_epa,
        b.off_pass_downs_epa,

        round(
            (b.pass_attempts + b.rush_attempts)::numeric
            / nullif(b.stat_games, 0),
        2)                                                      as plays_per_game,

        round(
            b.off_epa_per_play
            * ((b.pass_attempts + b.rush_attempts)::numeric / nullif(b.stat_games, 0)),
        4)                                                      as off_epa_total_per_game,

        round(
            b.avg_points_scored
            / nullif(b.total_yards::numeric / nullif(b.stat_games, 0), 0),
        4)                                                      as scoring_efficiency_ratio,

        round(
            b.rush_attempts::numeric
            / nullif(b.pass_attempts + b.rush_attempts, 0),
        3)                                                      as rush_rate,

        b.off_power_success,
        b.off_stuff_rate,
        b.off_line_yards,
        b.off_second_level_yards,
        b.off_open_field_yards,
        b.off_pts_per_opp,

        -- -------------------------
        -- DEFENSIVE EFFICIENCY
        -- -------------------------
        b.def_epa_per_play,
        b.def_epa_total,
        b.def_passing_epa,
        b.def_rushing_epa,
        b.def_success_rate,
        b.def_pass_success_rate,
        b.def_rush_success_rate,
        b.def_explosiveness,
        b.def_std_downs_success_rate,
        b.def_pass_downs_success_rate,
        b.def_std_downs_epa,
        b.def_pass_downs_epa,
        b.def_power_success,
        b.def_stuff_rate,
        b.def_line_yards,
        b.def_second_level_yards,
        b.def_open_field_yards,
        b.def_pts_per_opp,
        b.def_havoc_total,
        b.def_havoc_front_seven,
        b.def_havoc_db,

        round(b.sacks::numeric / nullif(b.stat_games, 0), 3)           as sacks_per_game,
        round(b.tackles_for_loss::numeric / nullif(b.stat_games, 0), 3) as tfl_per_game,
        round(b.third_down_conversions::numeric
            / nullif(b.third_down_attempts, 0), 3)                     as off_third_down_conv_rate,

        -- -------------------------
        -- EPA DIFFERENTIAL
        -- -------------------------
        b.epa_differential,

        -- -------------------------
        -- FIELD POSITION
        -- -------------------------
        b.off_field_position_avg_start,
        b.def_field_position_avg_start,
        b.off_field_position_predicted_pts,
        b.def_field_position_predicted_pts,

        -- -------------------------
        -- TURNOVERS
        -- -------------------------
        round(
            (b.interceptions_gained + b.fumbles_recovered)::numeric
            / nullif(b.stat_games, 0),
        3)                                                      as turnovers_forced_per_game,

        round(
            (b.interceptions_thrown + b.fumbles_lost)::numeric
            / nullif(b.stat_games, 0),
        3)                                                      as turnovers_lost_per_game,

        round(
            (b.interceptions_gained + b.fumbles_recovered
                - b.interceptions_thrown - b.fumbles_lost)::numeric
            / nullif(b.stat_games, 0),
        3)                                                      as turnover_margin_per_game,

        -- -------------------------
        -- PENALTIES
        -- -------------------------
        round(b.penalties::numeric / nullif(b.stat_games, 0), 2)       as penalties_per_game,
        round(b.penalty_yards::numeric / nullif(b.stat_games, 0), 2)   as penalty_yards_per_game,

        -- -------------------------
        -- GAME RESULTS
        -- -------------------------
        b.games_played,
        b.wins,
        b.losses,
        b.win_pct,
        b.avg_points_scored,
        b.avg_points_allowed,
        b.avg_point_diff,
        b.home_games,
        b.away_games,
        b.neutral_site_games,

        -- -------------------------
        -- SP+ RATINGS
        -- -------------------------
        b.sp_rating,
        b.sp_ranking,
        b.sp_offense,
        b.sp_defense,
        b.sp_special_teams,
        b.sp_offense_ranking,
        b.sp_defense_ranking,

        -- -------------------------
        -- RECRUITING
        -- -------------------------
        b.recruiting_3yr_avg,
        b.current_class_rank,

        -- -------------------------
        -- GAME SCRIPT DISTRIBUTION
        -- -------------------------
        gsd.pct_games_dominant,
        gsd.pct_games_comfortable,
        gsd.pct_games_competitive,
        gsd.pct_games_deficit,
        gsd.pct_games_large_deficit,

        -- -------------------------
        -- CLOSE GAME EPA (garbage-time filtered)
        -- -------------------------
        cge.close_game_epa_per_play_season_avg,
        cge.close_game_plays_total,

        -- -------------------------
        -- CLOSE GAME COUNTS
        -- -------------------------
        cgcs.close_game_count,
        cgcp.close_game_count_plays_based

    from base b
    left join game_script_dist gsd
        on gsd.team_name = b.team_name
        and gsd.season   = b.season
    left join close_game_epa_season cge
        on cge.team_name = b.team_name
        and cge.season   = b.season
    left join close_game_count_score cgcs
        on cgcs.team_name = b.team_name
        and cgcs.season   = b.season
    left join close_game_count_plays cgcp
        on cgcp.team_name = b.team_name
        and cgcp.season   = b.season
)

select * from final
