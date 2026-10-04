BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    release_year SMALLINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) NOT NULL,
    normalized_username VARCHAR(100) NOT NULL,
    platform VARCHAR(30),
    external_player_id VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT players_username_length
        CHECK (char_length(username) BETWEEN 1 AND 100),

    CONSTRAINT players_platform_check
        CHECK (
            platform IS NULL OR
            platform IN (
                'activision',
                'steam',
                'battle_net',
                'xbox',
                'playstation',
                'unknown'
            )
        ),

    CONSTRAINT players_unique_identity
        UNIQUE (normalized_username, platform)
);

CREATE INDEX idx_players_normalized_username
    ON players (normalized_username);

CREATE TABLE player_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,

    kills INTEGER NOT NULL DEFAULT 0,
    deaths INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    games_played INTEGER NOT NULL DEFAULT 0,
    score BIGINT NOT NULL DEFAULT 0,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT player_stats_unique_player_game
        UNIQUE (player_id, game_id),

    CONSTRAINT player_stats_nonnegative
        CHECK (
            kills >= 0 AND
            deaths >= 0 AND
            assists >= 0 AND
            wins >= 0 AND
            losses >= 0 AND
            games_played >= 0 AND
            score >= 0
        )
);

CREATE INDEX idx_player_stats_player_id
    ON player_stats (player_id);

CREATE INDEX idx_player_stats_game_id
    ON player_stats (game_id);

CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,

    match_external_id VARCHAR(150),
    mode VARCHAR(100),
    map VARCHAR(100),
    result VARCHAR(20),

    kills INTEGER NOT NULL DEFAULT 0,
    deaths INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    score INTEGER NOT NULL DEFAULT 0,

    played_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT matches_result_check
        CHECK (
            result IS NULL OR
            result IN ('win', 'loss', 'draw', 'unknown')
        ),

    CONSTRAINT matches_stats_nonnegative
        CHECK (
            kills >= 0 AND
            deaths >= 0 AND
            assists >= 0 AND
            score >= 0
        ),

    CONSTRAINT matches_unique_external_id
        UNIQUE (player_id, game_id, match_external_id)
);

CREATE INDEX idx_matches_player_id
    ON matches (player_id);

CREATE INDEX idx_matches_game_id
    ON matches (game_id);

CREATE INDEX idx_matches_played_at
    ON matches (played_at DESC);

CREATE INDEX idx_matches_player_played_at
    ON matches (player_id, played_at DESC);

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER players_updated_at
BEFORE UPDATE ON players
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER player_stats_updated_at
BEFORE UPDATE ON player_stats
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

COMMIT;