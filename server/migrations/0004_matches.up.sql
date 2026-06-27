-- V4-S3: matches table for PvP battle results (lockstep outcome persistence).
-- season_id stays 0 until V4-S5 (seasons). trophies deltas are placeholder
-- fixed values in S3 (winner +/- a flat amount); real ELO lands in V4-S4/S5.
-- gen_random_uuid() is built into PostgreSQL 13+ (no pgcrypto needed).

CREATE TABLE matches (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id         INT         NOT NULL DEFAULT 0,
    p1_account_id     BIGINT      NOT NULL REFERENCES accounts(id),
    p2_account_id     BIGINT      NOT NULL REFERENCES accounts(id),
    winner_account_id BIGINT,                              -- NULL = draw
    reason            TEXT,
    started_at        TIMESTAMPTZ NOT NULL,
    ended_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    p1_trophies_delta INT         NOT NULL DEFAULT 0,
    p2_trophies_delta INT         NOT NULL DEFAULT 0
);

CREATE INDEX matches_p1_idx ON matches (p1_account_id, ended_at DESC);
CREATE INDEX matches_p2_idx ON matches (p2_account_id, ended_at DESC);
