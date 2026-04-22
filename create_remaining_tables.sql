CREATE TABLE raw.sp_ratings (
    year                 INT,
    team                 TEXT,
    conference           TEXT,
    rating               NUMERIC(6,3),
    ranking              INT,
    offense_ranking      INT,
    offense_rating       NUMERIC(6,3),
    defense_ranking      INT,
    defense_rating       NUMERIC(6,3),
    special_teams_rating NUMERIC(6,3),
    _ingested_at         TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (year, team)
);

CREATE TABLE raw.recruiting (
    year         INT,
    team         TEXT,
    points       NUMERIC(8,2),
    rank         INT,
    commits      INT,
    _ingested_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (year, team)
);

CREATE TABLE raw.odds (
    game_id            TEXT,
    sport_key          TEXT,
    commence_time      TEXT,
    home_team          TEXT,
    away_team          TEXT,
    bookmaker          TEXT,
    h2h_home           INT,
    h2h_away           INT,
    spread_home_point  NUMERIC(4,1),
    spread_home_price  INT,
    spread_away_point  NUMERIC(4,1),
    spread_away_price  INT,
    total_point        NUMERIC(5,1),
    total_over_price   INT,
    total_under_price  INT,
    raw_payload        JSONB,
    _ingested_at       TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (game_id, bookmaker)
);
