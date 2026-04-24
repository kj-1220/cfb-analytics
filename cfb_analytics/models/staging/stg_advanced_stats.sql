with source as (
    select * from {{ source('raw', 'advanced_stats') }}
),
cleaned as (
    select
        -- keys
        year::int                                   as season,
        team::text                                  as team_name,
        conference::text                            as conference,

        -- volume
        off_plays::integer                          as off_plays,
        off_drives::integer                         as off_drives,
        def_plays::integer                          as def_plays,
        def_drives::integer                         as def_drives,

        -- offensive epa
        off_ppa::numeric                            as off_epa_per_play,
        off_total_ppa::numeric                      as off_epa_total,
        off_passing_ppa::numeric                    as off_passing_epa,
        off_rushing_ppa::numeric                    as off_rushing_epa,

        -- defensive epa
        def_ppa::numeric                            as def_epa_per_play,
        def_total_ppa::numeric                      as def_epa_total,
        def_passing_ppa::numeric                    as def_passing_epa,
        def_rushing_ppa::numeric                    as def_rushing_epa,

        -- offensive success rates
        off_success_rate::numeric                   as off_success_rate,
        off_passing_success_rate::numeric           as off_pass_success_rate,
        off_rushing_success_rate::numeric           as off_rush_success_rate,
        off_std_downs_success_rate::numeric         as off_std_downs_success_rate,
        off_pass_downs_success_rate::numeric        as off_pass_downs_success_rate,

        -- defensive success rates
        def_success_rate::numeric                   as def_success_rate,
        def_passing_success_rate::numeric           as def_pass_success_rate,
        def_rushing_success_rate::numeric           as def_rush_success_rate,
        def_std_downs_success_rate::numeric         as def_std_downs_success_rate,
        def_pass_downs_success_rate::numeric        as def_pass_downs_success_rate,

        -- offensive situational epa
        off_std_downs_ppa::numeric                  as off_std_downs_epa,
        off_pass_downs_ppa::numeric                 as off_pass_downs_epa,

        -- defensive situational epa
        def_std_downs_ppa::numeric                  as def_std_downs_epa,
        def_pass_downs_ppa::numeric                 as def_pass_downs_epa,

        -- explosiveness
        off_explosiveness::numeric                  as off_explosiveness,
        def_explosiveness::numeric                  as def_explosiveness,

        -- rushing efficiency (offensive)
        off_power_success::numeric                  as off_power_success,
        off_stuff_rate::numeric                     as off_stuff_rate,
        off_line_yards::numeric                     as off_line_yards,
        off_second_level_yards::numeric             as off_second_level_yards,
        off_open_field_yards::numeric               as off_open_field_yards,

        -- rushing efficiency (defensive)
        def_power_success::numeric                  as def_power_success,
        def_stuff_rate::numeric                     as def_stuff_rate,
        def_line_yards::numeric                     as def_line_yards,
        def_second_level_yards::numeric             as def_second_level_yards,
        def_open_field_yards::numeric               as def_open_field_yards,

        -- scoring opportunity efficiency
        off_points_per_opportunity::numeric         as off_pts_per_opp,
        def_points_per_opportunity::numeric         as def_pts_per_opp,

        -- field position (was missing from staging — added)
        off_field_position_avg_start::numeric       as off_field_position_avg_start,
        def_field_position_avg_start::numeric       as def_field_position_avg_start,
        off_field_position_predicted_pts::numeric   as off_field_position_predicted_pts,
        def_field_position_predicted_pts::numeric   as def_field_position_predicted_pts,

        -- havoc (fixed: was incorrectly mapped from off_havoc_*)
        def_havoc_total::numeric                    as def_havoc_total,
        def_havoc_front_seven::numeric              as def_havoc_front_seven,
        def_havoc_db::numeric                       as def_havoc_db

    from source
)
select * from cleaned
