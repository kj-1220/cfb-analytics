{{
  config(
    materialized='table',
    schema='int'
  )
}}

with base as (
    select * from {{ ref('int_team_season_features') }}
),

final as (
    select
        -- keys
        team_name,
        season,
        conference,

        -- -------------------------
        -- OFFENSIVE EFFICIENCY
        -- -------------------------
        off_epa_per_play,
        off_epa_total,
        off_passing_epa,
        off_rushing_epa,
        off_success_rate,
        off_pass_success_rate,
        off_rush_success_rate,
        off_explosiveness,
        off_std_downs_success_rate,
        off_pass_downs_success_rate,
        off_std_downs_epa,
        off_pass_downs_epa,

        round(
            (pass_attempts + rush_attempts)::numeric
            / nullif(stat_games, 0),
        2)                                                          as plays_per_game,

        round(
            off_epa_per_play
            * ((pass_attempts + rush_attempts)::numeric / nullif(stat_games, 0)),
        4)                                                          as off_epa_total_per_game,

        round(
            avg_points_scored
            / nullif(total_yards::numeric / nullif(stat_games, 0), 0),
        4)                                                          as scoring_efficiency_ratio,

        round(
            rush_attempts::numeric
            / nullif(pass_attempts + rush_attempts, 0),
        3)                                                          as rush_rate,

        off_power_success,
        off_stuff_rate,
        off_line_yards,
        off_second_level_yards,
        off_open_field_yards,
        off_pts_per_opp,

        -- -------------------------
        -- DEFENSIVE EFFICIENCY
        -- -------------------------
        def_epa_per_play,
        def_epa_total,
        def_passing_epa,
        def_rushing_epa,
        def_success_rate,
        def_pass_success_rate,
        def_rush_success_rate,
        def_explosiveness,
        def_std_downs_success_rate,
        def_pass_downs_success_rate,
        def_std_downs_epa,
        def_pass_downs_epa,
        def_power_success,
        def_stuff_rate,
        def_line_yards,
        def_second_level_yards,
        def_open_field_yards,
        def_pts_per_opp,
        def_havoc_total,
        def_havoc_front_seven,
        def_havoc_db,

        round(sacks::numeric / nullif(stat_games, 0), 3)           as sacks_per_game,
        round(tackles_for_loss::numeric / nullif(stat_games, 0), 3) as tfl_per_game,
        round(third_down_conversions::numeric
            / nullif(third_down_attempts, 0), 3)                   as off_third_down_conv_rate,

        -- -------------------------
        -- EPA DIFFERENTIAL
        -- -------------------------
        epa_differential,

        -- -------------------------
        -- FIELD POSITION
        -- note: raw components kept; margin derived column removed —
        -- field_position_margin correlates with turnover patterns and
        -- game script rather than team quality. Individual columns
        -- retained for model to learn relationships independently.
        -- -------------------------
        off_field_position_avg_start,
        def_field_position_avg_start,
        off_field_position_predicted_pts,
        def_field_position_predicted_pts,

        -- -------------------------
        -- TURNOVERS
        -- -------------------------
        round(
            (interceptions_gained + fumbles_recovered)::numeric
            / nullif(stat_games, 0),
        3)                                                          as turnovers_forced_per_game,

        round(
            (interceptions_thrown + fumbles_lost)::numeric
            / nullif(stat_games, 0),
        3)                                                          as turnovers_lost_per_game,

        round(
            (interceptions_gained + fumbles_recovered
                - interceptions_thrown - fumbles_lost)::numeric
            / nullif(stat_games, 0),
        3)                                                          as turnover_margin_per_game,

        -- -------------------------
        -- PENALTIES
        -- -------------------------
        round(penalties::numeric / nullif(stat_games, 0), 2)       as penalties_per_game,
        round(penalty_yards::numeric / nullif(stat_games, 0), 2)   as penalty_yards_per_game,

        -- -------------------------
        -- GAME RESULTS
        -- -------------------------
        games_played,
        wins,
        losses,
        win_pct,
        avg_points_scored,
        avg_points_allowed,
        avg_point_diff,
        home_games,
        away_games,
        neutral_site_games,

        -- -------------------------
        -- SP+ RATINGS
        -- -------------------------
        sp_rating,
        sp_ranking,
        sp_offense,
        sp_defense,
        sp_special_teams,
        sp_offense_ranking,
        sp_defense_ranking,

        -- -------------------------
        -- RECRUITING
        -- -------------------------
        recruiting_3yr_avg,
        current_class_rank

    from base
)

select * from final
