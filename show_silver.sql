-- ── STAGING VIEWS ────────────────────────────────────────────────
\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_GAMES'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_games LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_games'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_TEAMS'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_teams LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_teams'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_VENUES'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_venues LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_venues'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_SP_RATINGS'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_sp_ratings LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_sp_ratings'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_RECRUITING'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_recruiting LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_recruiting'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_ADVANCED_STATS'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_advanced_stats LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_advanced_stats'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_TEAM_STATS'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_team_stats LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_team_stats'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'STG.STG_GAME_WEATHER'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM stg.stg_game_weather LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='stg' AND table_name='stg_game_weather'
ORDER BY ordinal_position;

-- ── INTERMEDIATE TABLES ──────────────────────────────────────────
\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'INT.INT_TEAM_SEASON_FEATURES'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM int.int_team_season_features LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='int' AND table_name='int_team_season_features'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'INT.INT_TEAM_SEASON_CONTEXT'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM int.int_team_season_context LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='int' AND table_name='int_team_season_context'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'INT.INT_GAME_TEAM_FEATURES'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM int.int_game_team_features LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='int' AND table_name='int_game_team_features'
ORDER BY ordinal_position;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'INT.INT_GAME_ENVIRONMENT'
\echo '══════════════════════════════════════════════════════'
SELECT * FROM int.int_game_environment LIMIT 3;
\echo '--- columns ---'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='int' AND table_name='int_game_environment'
ORDER BY ordinal_position;

-- ── QUICK ROW COUNTS ─────────────────────────────────────────────
\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'ROW COUNTS — ALL SILVER TABLES'
\echo '══════════════════════════════════════════════════════'
SELECT 'stg_games'               AS table_name, COUNT(*) AS rows FROM stg.stg_games
UNION ALL SELECT 'stg_teams',               COUNT(*) FROM stg.stg_teams
UNION ALL SELECT 'stg_venues',              COUNT(*) FROM stg.stg_venues
UNION ALL SELECT 'stg_sp_ratings',          COUNT(*) FROM stg.stg_sp_ratings
UNION ALL SELECT 'stg_recruiting',          COUNT(*) FROM stg.stg_recruiting
UNION ALL SELECT 'stg_advanced_stats',      COUNT(*) FROM stg.stg_advanced_stats
UNION ALL SELECT 'stg_team_stats',          COUNT(*) FROM stg.stg_team_stats
UNION ALL SELECT 'stg_game_weather',        COUNT(*) FROM stg.stg_game_weather
UNION ALL SELECT 'int_team_season_features',COUNT(*) FROM int.int_team_season_features
UNION ALL SELECT 'int_team_season_context', COUNT(*) FROM int.int_team_season_context
UNION ALL SELECT 'int_game_team_features',  COUNT(*) FROM int.int_game_team_features
UNION ALL SELECT 'int_game_environment',    COUNT(*) FROM int.int_game_environment
ORDER BY table_name;
