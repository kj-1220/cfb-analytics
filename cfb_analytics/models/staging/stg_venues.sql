with source as (
    select * from {{ source('raw', 'venues') }}
),
cleaned as (
    select
        id::int                                            as venue_id,
        name::text                                         as venue_name,
        city::text                                         as city,
        state::text                                        as state,
        zip::text                                          as zip,
        country_code::text                                 as country_code,
        elevation::numeric                                 as elevation_meters,
        round((elevation::numeric * 3.28084)::numeric, 1) as elevation_feet,
        latitude::numeric                                  as latitude,
        longitude::numeric                                 as longitude,
        capacity::int                                      as capacity,
        grass::boolean                                     as grass,
        dome::boolean                                      as dome,
        timezone::text                                     as timezone
    from source
)
select * from cleaned
