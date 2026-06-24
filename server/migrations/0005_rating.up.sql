-- V4-S4: 隐藏匹配分 rating (ELO, 起评 1200) + matches 记录 rating delta。
-- trophies(可见杯数)仍走 0002 的列、S3 的 ±30；rating 是独立的匹配评分。

ALTER TABLE profiles ADD COLUMN rating INT NOT NULL DEFAULT 1200;

ALTER TABLE matches ADD COLUMN p1_rating_delta INT NOT NULL DEFAULT 0;
ALTER TABLE matches ADD COLUMN p2_rating_delta INT NOT NULL DEFAULT 0;
