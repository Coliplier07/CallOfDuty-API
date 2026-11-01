-- 003_normalize_database.sql
-- Evolve the original player-centric match table into a normalized
-- match + match_players model while preserving all existing rows.
-- The migration runner wraps each migration in a transaction.

-- 1. Normalize the platform values currently stored on players.
CREATE TABLE platforms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(30) NOT NULL UNIQUE,
    display_name VARCHAR(60) NOT NULL
);

INSERT INTO platforms (code, display_name)
SELECT DISTINCT
    platform,
    CASE platform
        WHEN 'activision' THEN 'Activision'
        WHEN 'steam' THEN 'Steam'
        WHEN 'battle_net' THEN 'Battle.net'
        WHEN 'xbox' THEN 'Xbox'
        WHEN 'playstation' THEN 'PlayStation'
        WHEN 'unknown' THEN 'Unknown'
        ELSE INITCAP(REPLACE(platform, '_', ' '))
    END
FROM players
WHERE platform IS NOT NULL
ON CONFLICT (code) DO NOTHING;

ALTER TABLE players
    ADD COLUMN platform_id UUID;

UPDATE players p
SET platform_id = pl.id
FROM platforms pl
WHERE pl.code = p.platform;

ALTER TABLE players
    DROP CONSTRAINT players_unique_identity,
    DROP CONSTRAINT players_platform_check;

ALTER TABLE players
    ADD CONSTRAINT players_platform_id_fkey
        FOREIGN KEY (platform_id) REFERENCES platforms(id) ON DELETE RESTRICT,
    ADD CONSTRAINT players_unique_identity
        UNIQUE (normalized_username, platform_id);

ALTER TABLE players DROP COLUMN platform;

-- 2. Normalize map and game-mode names. Their names are unique per game.
CREATE TABLE maps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT maps_unique_game_name UNIQUE (game_id, name),
    CONSTRAINT maps_id_game_unique UNIQUE (id, game_id)
);

CREATE TABLE game_modes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT game_modes_unique_game_name UNIQUE (game_id, name),
    CONSTRAINT game_modes_id_game_unique UNIQUE (id, game_id)
);

INSERT INTO maps (game_id, name)
SELECT DISTINCT game_id, map
FROM matches
WHERE map IS NOT NULL
ON CONFLICT (game_id, name) DO NOTHING;

INSERT INTO game_modes (game_id, name)
SELECT DISTINCT game_id, mode
FROM matches
WHERE mode IS NOT NULL
ON CONFLICT (game_id, name) DO NOTHING;

-- 3. A match is a game-level event. Player-specific results and performance
-- belong in match_players, not in matches.
--
-- If several legacy player rows share an external match ID, they become
-- participants in one new match. Rows with no external ID remain distinct.
CREATE TEMP TABLE match_id_map ON COMMIT DROP AS
SELECT
    id AS old_match_id,
    CASE
        WHEN match_external_id IS NULL THEN id
        ELSE FIRST_VALUE(id) OVER (
            PARTITION BY game_id, match_external_id
            ORDER BY id
        )
    END AS new_match_id
FROM matches;

-- Do not silently merge legacy rows that disagree about match-level facts.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM matches
        WHERE match_external_id IS NOT NULL
        GROUP BY game_id, match_external_id
        HAVING COUNT(DISTINCT map) > 1
            OR COUNT(DISTINCT mode) > 1
            OR COUNT(DISTINCT played_at) > 1
    ) THEN
        RAISE EXCEPTION
            'Cannot normalize matches: rows sharing an external match ID have conflicting map, mode, or played_at values.';
    END IF;
END;
$$;

CREATE TABLE matches_normalized (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    match_external_id VARCHAR(150),
    map_id UUID,
    mode_id UUID,
    played_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT matches_map_game_fkey
        FOREIGN KEY (map_id, game_id) REFERENCES maps(id, game_id),
    CONSTRAINT matches_mode_game_fkey
        FOREIGN KEY (mode_id, game_id) REFERENCES game_modes(id, game_id)
);

INSERT INTO matches_normalized (
    id,
    game_id,
    match_external_id,
    map_id,
    mode_id,
    played_at,
    created_at
)
SELECT
    id_map.new_match_id,
    MIN(old_match.game_id::text)::uuid,
    MIN(old_match.match_external_id),
    MIN(map_row.id::text)::uuid,
    MIN(mode_row.id::text)::uuid,
    MIN(old_match.played_at),
    MIN(old_match.created_at)
FROM matches old_match
JOIN match_id_map id_map ON id_map.old_match_id = old_match.id
LEFT JOIN maps map_row
    ON map_row.game_id = old_match.game_id
   AND map_row.name = old_match.map
LEFT JOIN game_modes mode_row
    ON mode_row.game_id = old_match.game_id
   AND mode_row.name = old_match.mode
GROUP BY id_map.new_match_id;

CREATE TABLE match_players (
    match_id UUID NOT NULL REFERENCES matches_normalized(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    result VARCHAR(20),
    kills INTEGER NOT NULL DEFAULT 0,
    deaths INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    score INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT match_players_pkey PRIMARY KEY (match_id, player_id),
    CONSTRAINT match_players_result_check
        CHECK (result IS NULL OR result IN ('win', 'loss', 'draw', 'unknown')),
    CONSTRAINT match_players_stats_nonnegative
        CHECK (kills >= 0 AND deaths >= 0 AND assists >= 0 AND score >= 0)
);

INSERT INTO match_players (
    match_id, player_id, result, kills, deaths, assists, score
)
SELECT
    id_map.new_match_id,
    old_match.player_id,
    old_match.result,
    old_match.kills,
    old_match.deaths,
    old_match.assists,
    old_match.score
FROM matches old_match
JOIN match_id_map id_map ON id_map.old_match_id = old_match.id;

-- Replace the old player-centric matches table only after every old row has
-- been copied into the new match and participant tables.
DROP TABLE matches;
ALTER TABLE matches_normalized RENAME TO matches;
ALTER TABLE match_players
    DROP CONSTRAINT match_players_match_id_fkey,
    ADD CONSTRAINT match_players_match_id_fkey
        FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX matches_unique_game_external_id
    ON matches (game_id, match_external_id)
    WHERE match_external_id IS NOT NULL;

CREATE INDEX idx_matches_game_id ON matches (game_id);
CREATE INDEX idx_matches_played_at ON matches (played_at DESC);
CREATE INDEX idx_matches_map_id ON matches (map_id);
CREATE INDEX idx_matches_mode_id ON matches (mode_id);
CREATE INDEX idx_match_players_player_id ON match_players (player_id);
CREATE INDEX idx_match_players_match_id ON match_players (match_id);
CREATE INDEX idx_players_platform_id ON players (platform_id);
