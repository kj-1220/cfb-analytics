{{
  config(
    materialized='table',
    schema='int'
  )
}}

with games as (
    select
        game_id,
        season,
        week,
        start_date::date                                        as game_date,
        home_team,
        away_team,
        home_points,
        away_points,
        season_type
    from {{ ref('stg_games') }}
    where season_type = 'regular'
      and home_points is not null
      and away_points is not null
),

game_team_spine as (
    select
        game_id, season, week, game_date,
        home_team                                               as team_name,
        away_team                                               as opponent,
        home_points                                             as points_scored,
        away_points                                             as points_allowed,
        case when home_points > away_points then 1 else 0 end  as win
    from games

    union all

    select
        game_id, season, week, game_date,
        away_team                                               as team_name,
        home_team                                               as opponent,
        away_points                                             as points_scored,
        home_points                                             as points_allowed,
        case when away_points > home_points then 1 else 0 end  as win
    from games
),

game_off_epa as (
    select
        game_id,
        offense                                                 as team_name,
        avg(ppa)                                                as off_epa_per_play,
        count(ppa)                                              as off_play_count
    from {{ source('raw', 'plays') }}
    where season_type = 'regular'
    group by game_id, offense
),

game_def_epa as (
    select
        game_id,
        defense                                                 as team_name,
        avg(ppa)                                                as def_epa_per_play_allowed,
        count(ppa)                                              as def_play_count
    from {{ source('raw', 'plays') }}
    where season_type = 'regular'
    group by game_id, defense
),

/*
  close_game_epa: filtered EPA excluding garbage time and overtime.
  Exclusion rules:
    - OT entirely excluded (period NOT IN 1-4)
    - period >= 3 AND margin > 38 (blowout from Q3)
    - period  = 4 AND margin > 28 (prevent defense Q4)
  Q1 and Q2: all plays included regardless of score.
*/
close_game_epa as (
    select
        game_id,
        offense                                                 as team_name,
        avg(ppa)                                                as close_game_epa_per_play,
        count(ppa)                                              as close_game_play_count
    from {{ source('raw', 'plays') }}
    where season_type = 'regular'
      and period between 1 and 4
      and not (period >= 3 and abs(offense_score - defense_score) > 38)
      and not (period  = 4 and abs(offense_score - defense_score) > 28)
    group by game_id, offense
),

/*
  game_script: classify each game by the team's average score margin
  across all plays they were on offense (OT included — narrative feature).
*/
game_margins as (
    select
        game_id,
        season,
        offense                                                 as team_name,
        avg(offense_score - defense_score)                      as avg_margin
    from {{ source('raw', 'plays') }}
    where season_type = 'regular'
    group by game_id, season, offense
),

game_script_labeled as (
    select
        game_id,
        season,
        team_name,
        avg_margin,
        case
            when avg_margin >   21 then 'dominant'
            when avg_margin >   10 then 'comfortable'
            when avg_margin >=  -9 then 'competitive'
            when avg_margin >= -21 then 'deficit'
            else                        'large_deficit'
        end                                                     as game_script
    from game_margins
),

game_team_epa as (
    select
        s.game_id,
        s.season,
        s.week,
        s.game_date,
        s.team_name,
        s.opponent,
        s.points_scored,
        s.points_allowed,
        s.win,
        o.off_epa_per_play,
        o.off_play_count,
        d.def_epa_per_play_allowed,
        d.def_play_count,
        c.close_game_epa_per_play,
        c.close_game_play_count,
        g.game_script,
        g.avg_margin                                            as game_script_avg_margin
    from game_team_spine s
    left join game_off_epa o
        on o.game_id = s.game_id and o.team_name = s.team_name
    left join game_def_epa d
        on d.game_id = s.game_id and d.team_name = s.team_name
    left join close_game_epa c
        on c.game_id = s.game_id and c.team_name = s.team_name
    left join game_script_labeled g
        on g.game_id = s.game_id and g.team_name = s.team_name
),

rolling as (
    select
        game_id,
        season,
        week,
        game_date,
        team_name,
        opponent,
        points_scored,
        points_allowed,
        win,
        off_epa_per_play,
        def_epa_per_play_allowed,
        close_game_epa_per_play,
        close_game_play_count,
        game_script,
        game_script_avg_margin,

        round(avg(off_epa_per_play) over (
            partition by team_name, season
            order by game_date, game_id
            rows between 3 preceding and 1 preceding
        )::numeric, 4)                                          as last3_off_epa_avg,

        round(avg(win::numeric) over (
            partition by team_name, season
            order by game_date, game_id
            rows between 3 preceding and 1 preceding
        )::numeric, 3)                                          as last3_win_pct,

        round(avg(points_scored) over (
            partition by team_name, season
            order by game_date, game_id
            rows between 3 preceding and 1 preceding
        )::numeric, 2)                                          as last3_points_scored_avg,

        round(avg(def_epa_per_play_allowed) over (
            partition by team_name, season
            order by game_date, game_id
            rows between 3 preceding and 1 preceding
        )::numeric, 4)                                          as last3_def_epa_avg,

        round(avg(points_allowed) over (
            partition by team_name, season
            order by game_date, game_id
            rows between 3 preceding and 1 preceding
        )::numeric, 2)                                          as last3_points_allowed_avg,

        game_date - lag(game_date) over (
            partition by team_name, season
            order by game_date, game_id
        )                                                       as days_since_last_game

    from game_team_epa
),

opp_sp as (
    select
        team_name,
        season,
        sp_rating                                               as opp_sp_rating
    from {{ ref('stg_sp_ratings') }}
),

final as (
    select
        r.game_id,
        r.season,
        r.week,
        r.game_date,
        r.team_name,
        r.opponent,
        r.points_scored,
        r.points_allowed,
        r.win,

        -- current game EPA (outcome/label, not feature)
        r.off_epa_per_play,
        r.def_epa_per_play_allowed,

        -- garbage-time filtered EPA
        r.close_game_epa_per_play,
        r.close_game_play_count,

        -- game script
        r.game_script,
        r.game_script_avg_margin,

        -- offensive rolling features (leakage-free)
        r.last3_off_epa_avg,
        r.last3_win_pct,
        r.last3_points_scored_avg,

        -- defensive rolling features (leakage-free)
        r.last3_def_epa_avg,
        r.last3_points_allowed_avg,

        -- rest
        r.days_since_last_game,

        -- opponent strength — prior year only
        sp.opp_sp_rating                                        as opp_sp_rating_at_game_time

    from rolling r
    left join opp_sp sp
        on sp.team_name = r.opponent
        and sp.season = r.season - 1
)

select * from final
