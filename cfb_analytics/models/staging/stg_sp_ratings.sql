with source as (
    select * from {{ source('raw', 'sp_ratings') }}
),
cleaned as (
    select
        year::int                       as season,
        team::text                      as team_name,
        conference::text                as conference,
        rating::numeric                 as sp_rating,
        ranking::int                    as sp_ranking,
        offense_rating::numeric         as sp_offense,
        defense_rating::numeric         as sp_defense,
        special_teams_rating::numeric   as sp_special_teams,
        offense_ranking::int            as sp_offense_ranking,
        defense_ranking::int            as sp_defense_ranking
    from source
)
select * from cleaned
