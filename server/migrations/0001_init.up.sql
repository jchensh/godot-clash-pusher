-- V4-S0c placeholder migration.
-- Real schema lands in V4-S1 (accounts) and V4-S2 (profiles, decks, unlocks).
-- See PLAN_V4 §6.1 for the target schema (accounts/profiles/decks/matches/seasons + F2P
-- reserved tables unlocks/currency/purchases).

-- Sanity: marker table so we can verify migrations ran at all.
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO schema_migrations (version) VALUES (1)
ON CONFLICT (version) DO NOTHING;
