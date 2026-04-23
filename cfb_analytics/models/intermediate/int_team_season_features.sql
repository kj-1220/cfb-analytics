with teams as (
    select * from {{ ref('stg_teams') }}
),
seasons as (
    select distinct home_team as team_name, season from {{ ref('stg_games') }}
    union
    select distinct away_team as team_name, season from {{ ref('stg_games') }}
),
spine as (
    select
        s.team_name, s.season, t.team_id, t.conference,
        t.city, t.state, t.latitude, t.longitude, t.timezone,
        t.primary_color, t.alt_color
    from seasons s
    inner join teams t on t.team_name = s.team_name
),
game_agg as (
    select
        team_name, season,
        count(*)                                                as games_played,
        sum(case when result = 'W' then 1 else 0 end)          as wins,
        sum(case when result = 'L' then 1 else 0 end)          as losses,
        round(avg(points_scored)::numeric, 2)                  as avg_points_scored,
        round(avg(points_allowed)::numeric, 2)                 as avg_points_allowed,
        round(avg(point_diff)::numeric, 2)                     as avg_point_diff,
        sum(case when home_away = 'home' then 1 else 0 end)    as home_games,
        sum(case when home_away = 'away' then 1 else 0 end)    as away_games,
        sum(case when neutral_site then 1 else 0 end)          as neutral_site_games
    from (
        select home_team as team_name, season, 'home' as home_away, neutral_site,
               home_points as points_scored, away_points as points_allowed,
               home_points - away_points as point_diff,
               case when home_points > away_points then 'W' else 'L' end as result
        from {{ ref('stg_games') }}
        union all
        select away_team as team_name, season, 'away' as home_away, neutral_site,
               away_points as points_scored, home_points as points_allowed,
               away_points - home_points as point_diff,
               case when away_points > home_points then 'W' else 'L' end as result
        from {{ ref('stg_games') }}
    ) game_rows
    group by team_name, season
),
rec as (
    select team_name, recruiting_year as season, recruiting_rank, recruiting_points
    from {{ ref('stg_recruiting') }}
),
rec_rolling as (
    select
        r1.team_name, r1.season,
        round((
            coalesce(r1.recruiting_points, 0) +
            coalesce(r2.recruiting_points, 0) +
            coalesce(r3.recruiting_points, 0)
        ) / nullif(
            (case when r1.recruiting_points is not null then 1 else 0 end +
             case when r2.recruiting_points is not null then 1 else 0 end +
             case when r3.recruiting_points is not null then 1 else 0 end), 0
        )::numeric, 2)                         as recruiting_3yr_avg,
        r1.recruiting_rank                     as current_class_rank
    from rec r1
    left join rec r2 on r2.team_name = r1.team_name and r2.season = r1.season - 1
    left join rec r3 on r3.team_name = r1.team_name and r3.season = r1.season - 2
),
final as (
    select
        -- spine
        sp_spine.team_name, sp_spine.season, sp_spine.team_id, sp_spine.conference,
        sp_spine.city, sp_spine.state, sp_spine.latitude, sp_spine.longitude, sp_spine.timezone,

        -- game results
        ga.games_played, ga.wins, ga.losses,
        round(ga.wins::numeric / nullif(ga.games_played, 0), 3) as win_pct,
        ga.avg_points_scored, ga.avg_points_allowed, ga.avg_point_diff,
        ga.home_games, ga.away_games, ga.neutral_site_games,

        -- SP+
        sp.sp_rating, sp.sp_ranking, sp.sp_offense, sp.sp_defense,
        sp.sp_special_teams, sp.sp_offense_ranking, sp.sp_defense_ranking,

        -- advanced / EPA
        adv.off_epa_per_play, adv.off_passing_epa, adv.off_rushing_epa,
        adv.def_epa_per_play, adv.def_passing_epa, adv.def_rushing_epa,
        adv.off_success_rate, adv.def_success_rate,
        adv.off_pass_success_rate, adv.off_rush_success_rate,
        adv.def_pass_success_rate, adv.def_rush_success_rate,
        adv.off_explosiveness, adv.def_explosiveness,
        adv.off_power_success, adv.def_power_success,
        adv.off_stuff_rate, adv.def_stuff_rate,
        adv.off_line_yards, adv.def_line_yards,
        adv.off_open_field_yards, adv.def_open_field_yards,
        adv.off_pts_per_opp, adv.def_pts_per_opp,
        adv.total_havoc, adv.front_seven_havoc, adv.db_havoc,
        adv.off_std_downs_success_rate, adv.off_pass_downs_success_rate,
        adv.def_std_downs_success_rate, adv.def_pass_downs_success_rate,

        -- EPA differential
        round(coalesce(adv.off_epa_per_play, 0) - coalesce(adv.def_epa_per_play, 0), 4) as epa_differential,

        -- team stats
        ts.games_played                             as stat_games,
        ts.pass_attempts, ts.pass_completions, ts.passing_yards, ts.pass_tds,
        ts.interceptions_thrown, ts.rush_attempts, ts.rushing_yards, ts.rush_tds,
        ts.third_down_attempts, ts.third_down_conversions,
        ts.fourth_down_attempts, ts.fourth_down_conversions,
        ts.penalties, ts.penalty_yards,
        ts.fumbles_lost, ts.fumbles_recovered,
        ts.interceptions_gained, ts.turnovers,
        ts.sacks, ts.tackles_for_loss, ts.total_yards,
        ts.completion_pct, ts.yards_per_attempt, ts.third_down_pct, ts.fourth_down_pct,

        -- recruiting
        rec_rolling.recruiting_3yr_avg, rec_rolling.current_class_rank

    from spine sp_spine
    left join game_agg ga
        on ga.team_name = sp_spine.team_name and ga.season = sp_spine.season
    left join {{ ref('stg_sp_ratings') }} sp
        on sp.team_name = sp_spine.team_name and sp.season = sp_spine.season
    left join {{ ref('stg_advanced_stats') }} adv
        on adv.team_name = sp_spine.team_name and adv.season = sp_spine.season
    left join {{ ref('stg_team_stats') }} ts
        on ts.team_name = sp_spine.team_name and ts.season = sp_spine.season
    left join rec_rolling
        on rec_rolling.team_name = sp_spine.team_name and rec_rolling.season = sp_spine.season
)
select * from final
