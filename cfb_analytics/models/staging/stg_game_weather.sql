with source as (
    select * from {{ source('raw', 'game_weather') }}
)
select
    game_id,
    venue_id,
    game_date,
    kickoff_hour,
    temperature_f,
    wind_speed_mph,
    wind_gusts_mph,
    precipitation_in                  as precipitation_inches,
    humidity_pct,
    weather_code,
    fetched_at
from source
