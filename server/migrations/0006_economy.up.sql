-- V5-N3 (决策 48)：服务器权威经济状态 —— 钱包/货币/挂机 + 卡牌养成 + 关卡进度。
-- 本地原型 S0~S6 的 PlayerData 搬上服务器做权威；客户端只缓存展示（改本地无效）。

CREATE TABLE economy_state (
    account_id           BIGINT      PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    gold                 BIGINT      NOT NULL DEFAULT 0,
    gems                 BIGINT      NOT NULL DEFAULT 0,
    idle_last_collect_ts BIGINT      NOT NULL DEFAULT 0,
    highest_cleared      TEXT        NOT NULL DEFAULT '',
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE economy_cards (
    account_id BIGINT  NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    card_id    TEXT    NOT NULL,
    level      INT     NOT NULL DEFAULT 1,
    rank       INT     NOT NULL DEFAULT 1,
    shards     INT     NOT NULL DEFAULT 0,
    unlocked   BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (account_id, card_id)
);

CREATE TABLE economy_stages (
    account_id BIGINT  NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    stage_id   TEXT    NOT NULL,
    stars      INT     NOT NULL DEFAULT 0,
    cleared    BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (account_id, stage_id)
);
