with source as (
    select * from {{ source('raw', 'teams') }}
),
fbs_only as (
    select
        id::int                as team_id,
        school::text           as team_name,
        mascot::text           as mascot,
        abbreviation::text     as abbreviation,
        conference::text       as conference,
        classification::text   as classification,
        city::text             as city,
        state::text            as state,
        zip::text              as zip,
        country::text          as country,
        latitude::numeric      as latitude,
        longitude::numeric     as longitude,
        timezone::text         as timezone,
        color::text            as primary_color,
        alt_color::text        as alt_color
    from source
    where lower(classification) = 'fbs'
)
select * from fbs_only
