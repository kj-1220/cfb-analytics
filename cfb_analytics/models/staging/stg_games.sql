with source as (
    select * from {{ source('raw', 'games') }}
),
cleaned as (
    select
        id::bigint                                          as game_id,
        season::int                                        as season,
        week::int                                          as week,
        season_type::text                                  as season_type,
        start_date::text                                   as start_date,
        start_time_et::text                                as start_time_et,
        neutral_site::boolean                              as neutral_site,
        conference_game::boolean                           as conference_game,
        attendance::int                                    as attendance,
        venue_id::bigint                                   as venue_id,
        venue::text                                        as venue_name,
        home_team::text                                    as home_team,
        home_conference::text                              as home_conference,
        home_points::int                                   as home_points,
        away_team::text                                    as away_team,
        away_conference::text                              as away_conference,
        away_points::int                                   as away_points,
        extract(year from cast(start_date as timestamp))::int as game_year
    from source
    where home_points is not null
      and away_points is not null
)
select * from cleaned
