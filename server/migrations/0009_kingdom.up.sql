-- K1 (DESIGN_KINGDOM.md, 2026-07-19)：王国领地系统 —— 城建经营 + 城防养成新维度。
-- 服务器权威（用户拍板：永久原则）：资源/建筑等级/施工计时全在服务器结算，客户端只收发+展示。
-- 扩展性预留（用户 2026-07-19 要求：养成/货币经济后续会改）：
--   * resources 用 JSONB {food, wood, ...}——新增货币 = 配置加键，零 migration；
--   * kingdom_buildings 以 (account_id, building) 为键，building 为配置键文本——新建筑 = 配置加表；
--     未来同类多实例（农田×n）再加 instance 列扩主键，当前 P0 单实例。

CREATE TABLE kingdom_state (
    account_id      BIGINT      PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    resources       JSONB       NOT NULL DEFAULT '{}'::jsonb,
    last_collect_ts BIGINT      NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE kingdom_buildings (
    account_id     BIGINT      NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    building       TEXT        NOT NULL,
    level          INT         NOT NULL DEFAULT 0,
    upgrade_end_ts BIGINT      NOT NULL DEFAULT 0,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, building)
);
