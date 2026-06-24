-- V4-S2: decks table for cloud-saved card decks (1..3 slots per account).
-- See PLAN_V4 §6.1. profiles already carries every Profile-proto field
-- (added in 0002), so this step only introduces decks.
--
-- F2P tables (unlocks / currency / purchases) are intentionally NOT created
-- here — they land in V4-S10 when IAP / progression is actually implemented
-- (CLAUDE.md "不过度设计").

CREATE TABLE decks (
    id         BIGSERIAL PRIMARY KEY,
    account_id BIGINT    NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    slot       INT       NOT NULL CHECK (slot BETWEEN 1 AND 3),  -- which deck slot
    card_ids   JSONB     NOT NULL,                               -- ["knight","fireball",...] 8 cards
    is_active  BOOLEAN   NOT NULL DEFAULT FALSE,                 -- at most one active per account
    UNIQUE (account_id, slot)
);
