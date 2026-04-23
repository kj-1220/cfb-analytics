with source as (
    select * from {{ source('raw', 'team_stats') }}
),
cleaned as (
    select
        year::int                                   as season,
        team::text                                  as team_name,
        conference::text                            as conference,
        games::int                                  as games_played,
        pass_attempts::int                          as pass_attempts,
        pass_completions::int                       as pass_completions,
        net_passing_yards::numeric                  as passing_yards,
        passing_tds::int                            as pass_tds,
        passes_intercepted::int                     as interceptions_thrown,
        rushing_attempts::int                       as rush_attempts,
        rushing_yards::numeric                      as rushing_yards,
        rushing_tds::int                            as rush_tds,
        third_downs::int                            as third_down_attempts,
        third_down_conversions::int                 as third_down_conversions,
        fourth_downs::int                           as fourth_down_attempts,
        fourth_down_conversions::int                as fourth_down_conversions,
        penalties::int                              as penalties,
        penalty_yards::numeric                      as penalty_yards,
        fumbles_lost::int                           as fumbles_lost,
        fumbles_recovered::int                      as fumbles_recovered,
        interceptions::int                          as interceptions_gained,
        turnovers::int                              as turnovers,
        sacks::int                                  as sacks,
        tackles_for_loss::int                       as tackles_for_loss,
        total_yards::numeric                        as total_yards,
        -- derived
        case
            when nullif(pass_attempts::int, 0) is not null
            then round((pass_completions::numeric / nullif(pass_attempts::numeric, 0)) * 100, 1)
        end                                         as completion_pct,
        case
            when nullif(pass_attempts::int, 0) is not null
            then round(net_passing_yards::numeric / nullif(pass_attempts::numeric, 0), 2)
        end                                         as yards_per_attempt,
        case
            when nullif(third_downs::int, 0) is not null
            then round((third_down_conversions::numeric / nullif(third_downs::numeric, 0)) * 100, 1)
        end                                         as third_down_pct,
        case
            when nullif(fourth_downs::int, 0) is not null
            then round((fourth_down_conversions::numeric / nullif(fourth_downs::numeric, 0)) * 100, 1)
        end                                         as fourth_down_pct
    from source
)
select * from cleaned
