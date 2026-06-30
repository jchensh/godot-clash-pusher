-- V5-S9：账号身份——昵称已存在，补头像（怪物卡 id）+ 新手引导完成标志（服务器权威）。
ALTER TABLE profiles ADD COLUMN avatar_card_id TEXT NOT NULL DEFAULT '';
ALTER TABLE profiles ADD COLUMN tutorial_done  BOOLEAN NOT NULL DEFAULT FALSE;
