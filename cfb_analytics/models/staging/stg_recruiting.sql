with source as (
    select * from {{ source('raw', 'recruiting') }}
),
cleaned as (
    select
        year::int               as recruiting_year,
        team::text              as team_name,
        rank::int               as recruiting_rank,
        points::numeric         as recruiting_points,
        commits::int            as recruiting_commits
    from source
)
select * from cleaned
