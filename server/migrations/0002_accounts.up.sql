-- V4-S1: accounts + profiles base tables for anonymous device_id login.
-- See PLAN_V4 §6.1 for the full V4 schema target.

CREATE TABLE accounts (
    id            BIGSERIAL    PRIMARY KEY,
    provider      TEXT         NOT NULL DEFAULT 'device',
    external_id   TEXT         NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    ban_status    SMALLINT     NOT NULL DEFAULT 0,  -- 0=ok, 1=shadow, 2=full ban
    UNIQUE (provider, external_id)
);

CREATE TABLE profiles (
    account_id        BIGINT      PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    nickname          TEXT        NOT NULL,
    avatar_id         INT         NOT NULL DEFAULT 0,
    level             INT         NOT NULL DEFAULT 1,
    exp               INT         NOT NULL DEFAULT 0,
    trophies          INT         NOT NULL DEFAULT 0,
    current_season_id INT,
    version           INT         NOT NULL DEFAULT 0,  -- optimistic lock
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
