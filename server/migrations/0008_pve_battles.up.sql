-- KAN-78/79 PVE 防作弊：战斗会话表。
-- 开战报到（服务器时钟 started_at + deck/养成权威快照）→ 战斗中指令流/哈希批量追加
-- （到达时间由服务器记 → 时序真实性）→ StageClear 消费（防重放）→ verifier 事后重放验证。
CREATE TABLE pve_battles (
    id              BIGSERIAL PRIMARY KEY,
    account_id      BIGINT      NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    stage_id        TEXT        NOT NULL,
    deck            JSONB       NOT NULL,                -- ["knight", ...] 8 张
    progress        JSONB       NOT NULL DEFAULT '{}',   -- {card_id:{level,rank}} 开战时服务器权威快照（重放用）
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- 服务器时钟（限速基准）
    cmds            JSONB       NOT NULL DEFAULT '[]',   -- [{t,ph,s,c,x,y}] 双方出牌指令流
    hashes          JSONB       NOT NULL DEFAULT '[]',   -- [{t,h}] 每 10 tick 状态哈希(hex)
    report_count    INT         NOT NULL DEFAULT 0,
    last_report_at  TIMESTAMPTZ,
    consumed_at     TIMESTAMPTZ,                          -- stage-clear 消费时间（一局只能结算一次）
    claimed_stars   INT,
    claimed_summary JSONB,                                -- {duration_ticks, deploy_count, king_hp_permille}
    verify_status   SMALLINT    NOT NULL DEFAULT 0,       -- 0=待验 1=通过 2=不吻合 3=验证出错 4=抽样跳过
    verify_note     TEXT        NOT NULL DEFAULT '',
    verified_at     TIMESTAMPTZ
);

CREATE INDEX idx_pve_battles_account ON pve_battles (account_id, started_at DESC);
-- verifier 轮询队列：已消费且待验证的局。
CREATE INDEX idx_pve_battles_pending ON pve_battles (id) WHERE consumed_at IS NOT NULL AND verify_status = 0;
