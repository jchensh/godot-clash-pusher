-- V4-S0c bootstrap migration (placeholder).
--
-- schema_migrations is created by the migrate runner itself
-- (server/internal/store/migrate.go: CREATE TABLE IF NOT EXISTS),
-- so this file intentionally makes no schema changes — it only
-- exists to reserve version 0001 in the timeline.
--
-- Real schema starts at 0002 (V4-S1: accounts + profiles).

SELECT 1;
