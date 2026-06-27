-- V4-S4 rollback for 0005_rating.up.sql.
ALTER TABLE matches DROP COLUMN IF EXISTS p2_rating_delta;
ALTER TABLE matches DROP COLUMN IF EXISTS p1_rating_delta;
ALTER TABLE profiles DROP COLUMN IF EXISTS rating;
