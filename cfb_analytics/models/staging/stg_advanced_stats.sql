with source as (
    select * from {{ source('raw', 'advanced_stats') }}
),
cleaned as (
    select
        year::int                           as season,
        team::text                          as team_name,
        conference::text                    as conference,
        off_ppa::numeric                    as off_epa_per_play,
        off_passing_ppa::numeric            as off_passing_epa,
        off_rushing_ppa::numeric            as off_rushing_epa,
        def_ppa::numeric                    as def_epa_per_play,
        def_passing_ppa::numeric            as def_passing_epa,
        def_rushing_ppa::numeric            as def_rushing_epa,
        off_success_rate::numeric           as off_success_rate,
        def_success_rate::numeric           as def_success_rate,
        off_passing_success_rate::numeric   as off_pass_success_rate,
        off_rushing_success_rate::numeric   as off_rush_success_rate,
        def_passing_success_rate::numeric   as def_pass_success_rate,
        def_rushing_success_rate::numeric   as def_rush_success_rate,
        off_explosiveness::numeric          as off_explosiveness,
        def_explosiveness::numeric          as def_explosiveness,
        off_power_success::numeric          as off_power_success,
        def_power_success::numeric          as def_power_success,
        off_stuff_rate::numeric             as off_stuff_rate,
        def_stuff_rate::numeric             as def_stuff_rate,
        off_line_yards::numeric             as off_line_yards,
        def_line_yards::numeric             as def_line_yards,
        off_open_field_yards::numeric       as off_open_field_yards,
        def_open_field_yards::numeric       as def_open_field_yards,
        off_points_per_opportunity::numeric as off_pts_per_opp,
        def_points_per_opportunity::numeric as def_pts_per_opp,
        off_havoc_total::numeric            as total_havoc,
        off_havoc_front_seven::numeric      as front_seven_havoc,
        off_havoc_db::numeric               as db_havoc,
        off_std_downs_success_rate::numeric as off_std_downs_success_rate,
        off_pass_downs_success_rate::numeric as off_pass_downs_success_rate,
        def_std_downs_success_rate::numeric as def_std_downs_success_rate,
        def_pass_downs_success_rate::numeric as def_pass_downs_success_rate
    from source
)
select * from cleaned
