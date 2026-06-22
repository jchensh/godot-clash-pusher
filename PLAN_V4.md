# PLAN_V4.md — V4 规划：联网升级 + 实时对战 + 服务端架构

> 本文件是 **V4 阶段的权威规划**。V1（单 lane 白膜 demo）/ V2（3-lane + 程序化换皮 + AI + 内容）/ V3（2D 战斗 reboot + 买断制单机的短战役 + Roguelite + 精灵美术 + UI/音频骨架）已完成或收尾中，详见 [PLAN_V1.md](PLAN_V1.md) / [PLAN_V2.md](PLAN_V2.md) / [PLAN_V3.md](PLAN_V3.md)；全局 roadmap 见 [PLAN_GRAND.md](PLAN_GRAND.md)。
> **开发纪律沿用 V1/V2/V3**：一步一确认、每步 commit、逻辑层步骤必配单元测试、玩家与 AI 对称、不过度设计；服务端步骤额外配 Go 单测 + docker compose 烟测。表现/手感/真人对战类步骤交真人实机验收。

---

## 1. V4 目标一句话

在 V3 买断制单机基础上，**新增联网模块**：账号体系 + 实时 PvP 对战 + 匹配 + 赛季 + 排行榜，长期商业方向定调为 **F2P + 内购解锁/养成**。**当前阶段 = 玩法验证**——只搭骨架（让两台真机能在自己服务器上跑天梯对战、有匹配有榜单）、**不做产品化**（不做正式登录/支付/合规/云上线）。

**头号工程 = 实时对战网络层（V4-S3）**：客户端的 `logic/` 是 10Hz 确定性 tick、无随机、玩家与 AI 对称，**天然适配 lockstep**。S3 把"两个本地 player 都向同一 logic 发指令"换成"两个客户端各自的 logic 跑相同 tick、服务端转发指令 + 哈希校验"，是 V4 的命门。

---

## 2. 已锁定的方向（用户 2026-06-23 确认）

| 维度 | 决定 |
|---|---|
| **战斗权威模型** | **Lockstep + 状态哈希校验**：客户端各自跑现有 `logic/` 的确定性 tick，服务端只转发指令 + 周期对帐 hash。**不重写 Go 战斗逻辑**（避免双份维护） |
| **服务端语言** | **Go**（高并发 WS / tick 循环 / protobuf 一流 / 单 binary 部署） |
| **网络协议** | **WebSocket + protobuf**（移动网络/NAT 友好；UDP 不值得） |
| **数据库** | **PostgreSQL + Redis**（PG 关系型主存储；Redis ZSET 天然适配匹配队列+排行榜+对局短缓存） |
| **认证** | **JWT (HS256) + refresh token**；前期 **device_id 匿名登录**，不做 SMS/邮箱/三方 |
| **商业模式** | **长期 F2P + 内购解锁/养成**（schema 预留 `purchases` / 卡片等级 / 货币字段）；**前期完全不实现支付/IAP/养成系统** |
| **V3 内容定位** | **V3 Roguelite + 短战役保留不动**，作为单人"训练营/挑战"模式；PvP 走全新主轴入口 |
| **客户端平台** | **Android + Windows**（先不碰 iOS；Mac/Linux 编辑器跑通即可） |
| **仓库结构** | **单仓 `/server` 子目录**（Go 服务端） + **`/proto` 共享 .proto 文件** |
| **proto 工具** | 客户端用 gd-protobuf（GDScript 解析）；服务端用官方 `protoc-gen-go` |
| **部署** | **本地 docker compose** 起 PG / Redis / gateway / battle；**不上云**，最多自建内网测试服 |
| **反作弊深度** | 基础：JWT + 状态哈希 + 速率限制；**异常检测/封禁/客服 推后** |

**V4 明确不做**：正式登录系统（SMS/邮箱/Apple/Google/微信）、IAP 校验/退款、合规（实名/防沉迷/版号/ICP）、云部署/HA/监控告警、客户端版本管理/强更、战绩回放产品化、聊天/好友系统（可留 S6+）。

**与 [CLAUDE.md](CLAUDE.md) 硬性 DO-NOT 的关系**：原 5 条全部继续生效；新增一条 **❌ 客户端禁止权威化战斗状态**——所有指令必须走服务端转发，客户端只是 lockstep 跑相同 tick；状态以双方+服务端三方 hash 对帐为准。

---

## 3. 整体架构

```
┌──────────────────────────────────────────┐
│ 客户端 (Godot 4.6.3 / GDScript)            │
│  • logic/         ← 不动                  │
│  • net/           ← 新增 WS 客户端 + protobuf │
│  • player.gd      → LocalPlayer / NetworkPlayer 双实现 │
│  • menu LADDER    ← 新增入口              │
└──────────────────┬───────────────────────┘
                   │ wss://
┌──────────────────▼───────────────────────┐
│ Gateway (Go) — WS 接入 + JWT 校验 + 路由   │
└──┬───────────────────────────┬──────────┘
   │                           │
┌──▼─────────────────┐  ┌─────▼──────────┐
│ Lobby API (HTTP/WS) │  │ Battle Server  │
│ 登录/档案/卡组       │  │ 每局一 goroutine │
│ 匹配排队/排行榜读取  │  │ 指令转发        │
│ 战绩列表（最简）     │  │ 哈希校验        │
│                    │  │ 断线重连/超时   │
└──┬─────────┬───────┘  └────┬───────────┘
   │         │                │
┌──▼──┐  ┌──▼───────────┐  ┌──▼──────────┐
│ PG  │  │ Redis        │  │ 文件存储     │
│账号 │  │ 队列/榜/缓存 │  │（回放，可选）│
│档案 │  │ 限流/session │  │              │
└─────┘  └──────────────┘  └─────────────┘
```

**部署最简形态（docker compose）**：5 容器（gateway / api / battle / postgres / redis），1 网络。
**目标拓扑（玩法验证阶段够用）**：gateway + api + battle 可合并为单进程跑（用 goroutine 分层），等需要扩容时再拆。

---

## 4. 施工图（按序执行，每步停下确认 + commit；逻辑步骤必配单测）

### V4 玩法验证（先做这一批）

| 步 | 内容 | 验收标准 |
|---|---|---|
| **V4-S0** | 写本文件 + `proto/` 定义初版消息（auth/profile/match/battle 共 ~15 条）+ `server/` Go 项目脚手架（`cmd/` `internal/` `pkg/`）+ `docker-compose.yml`（pg+redis+server）+ `Makefile`（gen/test/up） | `docker compose up` 起来；`go test ./...` 通过；`make gen-proto` 客户端 + 服务端都产物 |
| **V4-S1** | **匿名登录**：device_id → JWT（HS256，TTL 30d）+ refresh token；客户端 `net/auth.gd` 存 token 到 `user://`；无密码无验证码 | Go 单测：device_id 首次登录建账号、二次登录命中既有；客户端 headless smoke：拿到 token 写盘读盘 |
| **V4-S2** | **玩家档案云存档**：拉/推 profile（昵称/赛季杯数/卡组/解锁集合）；schema 预留 `unlocks`/`card_levels`/`currency`/`purchases` 表，但只读写基础字段；离线缓存 + 冲突 = 服务端版本胜出 | Go 单测：CRUD/版本号；客户端切换离线↔在线，档不丢 |
| **V4-S3** | **实时对战网络层**（核心）：WS gateway + battle room；客户端 `NetworkPlayer` 把 deploy 指令 → 服务端 → 广播给双方 → 双方 `logic/` tick 推进；每 N tick 上报 state hash，服务端三方对帐；**断线重连**（room TTL 60s）；**超时认输**（30s 无心跳） | 单测：lockstep 序列回放双方 hash 一致；真人验收：两台机器（你 + 同事，或两台你的设备）跑完整一局，胜负结算入档 |
| **V4-S4** | **匹配**：Redis ZSET 按段位分桶 + ELO 起评 1200 + 窗口扩展（±50 → ±200，每 5s 扩一档）+ 取消接口 | Go 单测：两玩家 ELO 接近自动配对；ELO 远离扩窗口后配对；取消立刻出队；真人验收：两端点击天梯都 30s 内配上 |
| **V4-S5** | **赛季 + 排行榜最简版**：season cycle（month-based）+ Redis ZSET 全球 trophies 榜 + 段位软重置（每赛季回归到上 50%）+ 段位奖励占位（仅记录领取意图，不发实物） | Go 单测：赛季切换归档+重置；榜单读写；真人验收：对战胜负影响 trophy → 榜单实时刷新 |

### V4 产品化（玩法验证通过后再启动）

| 步 | 内容 |
|---|---|
| **V4-S6** | 战绩 + 回放（lockstep 的指令流天然就是回放，存到对象存储） |
| **V4-S7** | 反作弊深化（异常检测规则、封禁工具、admin dashboard） |
| **V4-S8** | 部署/运维（云上线、监控、日志、CI/CD、灰度） |
| **V4-S9** | 客户端版本管理（强更、差分、热修） |
| **V4-S10** | 内购 + 养成系统（IAP 校验/退款、卡片升级、货币、经济曲线） |
| **V4-S11** | 正式登录系统 + 合规（SMS/邮箱/Apple/Google；国内：实名/防沉迷/版号/ICP） |
| **V4-S12** | 好友/聊天/俱乐部（可选） |

---

## 5. 协议设计要点（S0 落地依据）

### 5.1 顶层包结构

```
proto/
├── common.proto       # 错误码、时间戳、枚举
├── auth.proto         # LoginReq/Resp, RefreshReq/Resp
├── profile.proto      # ProfileGet/Push, DeckUpdate
├── match.proto        # FindMatch/Cancel/MatchFound
├── battle.proto       # JoinRoom/Deploy/StateHash/Tick/Result
└── leaderboard.proto  # TopReq/Resp
```

### 5.2 WebSocket frame 约定

```
[2 bytes msg_id][N bytes protobuf payload]
```

`msg_id` 是枚举（见 `common.proto`），客户端/服务端共享。心跳走最小 frame（`msg_id=PING/PONG`，无 payload）。

### 5.3 战斗 lockstep 消息（最重要）

- `JoinRoom(token, room_id)` — 进对局
- `Deploy(tick, card_id, x, y)` — 出兵指令（**只描述意图**，不带战斗后果）
- `Broadcast(tick, deploy_list)` — 服务端把双方在本 tick 的指令打包广播（双方收到后 logic 推进同一 tick）
- `StateHash(tick, hash)` — 每 10 tick 客户端上报
- `Result(winner, reason)` — 服务端判定胜负（hash 一致 → 用客户端结果；hash 不一致 → 服务端走仲裁规则）

**确定性保证**：
1. 现有 `logic/` 已无随机（仇恨/分离/塔选目标的 tie-break 用 spawn 序/id），不需要改
2. 浮点保持现状（GDScript 用 float64，跨设备一致；如未来发现极端 case 再上定点数）
3. tick rate 锁 10Hz，与客户端 `SimClock` 对齐

### 5.4 仲裁规则（hash 不一致时）

1. 优先信任**多数派**（玩家 A + 服务端复算 vs 玩家 B → 信 A+server）
2. 服务端不重跑完整战斗，只在 hash 分歧 tick 调用 Go 端口的"最小校验器"（重算该 tick 的 elixir/合法性，不算完整推进）
3. 长期分歧 → 该 client 标记 suspect、本局判负、入风控队列

> **关键工程取舍**：完全的服务端复算需要 Go 端口整套 `logic/`（翻倍工作量）；最小校验器只覆盖"指令合法性 + 圣水"，能拦 95% 作弊（出兵不花圣水、出兵在敌方半场、出空气卡），剩下 5%（战斗中数值篡改）靠 hash 三方对帐捕获，捕获后判负但不一定能精确仲裁。**V4 玩法验证阶段接受这个缺口**，等 V4-S7 反作弊深化时再升级。

---

## 6. 数据库设计草案

### 6.1 PostgreSQL schema（V4-S0 落地，**预留 F2P 字段**）

```sql
-- 玩法验证阶段实际使用的表
accounts (
  id BIGSERIAL PRIMARY KEY,
  provider TEXT NOT NULL DEFAULT 'device',  -- 'device'/'email'/'apple'/'google'，前期只用 'device'
  external_id TEXT NOT NULL,                -- device_id 或第三方 sub
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ,
  ban_status SMALLINT DEFAULT 0,            -- 0=ok, 1=shadow, 2=full ban
  UNIQUE (provider, external_id)
);

profiles (
  account_id BIGINT PRIMARY KEY REFERENCES accounts(id),
  nickname TEXT NOT NULL,
  avatar_id INT DEFAULT 0,                  -- 头像 id（前期固定一组占位）
  level INT DEFAULT 1,
  exp INT DEFAULT 0,
  trophies INT DEFAULT 0,                   -- 当前赛季杯数
  current_season_id INT,
  version INT DEFAULT 0,                    -- 乐观锁
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

decks (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL REFERENCES accounts(id),
  slot INT NOT NULL,                        -- 1..3 几号卡组
  card_ids JSONB NOT NULL,                  -- ["knight","fireball",...] 8 张
  is_active BOOLEAN DEFAULT FALSE,
  UNIQUE (account_id, slot)
);

matches (
  id UUID PRIMARY KEY,
  season_id INT NOT NULL,
  p1_account_id BIGINT NOT NULL,
  p2_account_id BIGINT NOT NULL,
  winner_account_id BIGINT,                 -- NULL = draw
  reason TEXT,                              -- 'king_destroyed' / 'timeout' / 'surrender'
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL,
  p1_trophies_delta INT,
  p2_trophies_delta INT,
  replay_ref TEXT                           -- 文件路径或 null
);

seasons (
  id INT PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ
);

-- 预留（schema 建表，逻辑不实现）
unlocks (
  account_id BIGINT NOT NULL,
  card_id TEXT NOT NULL,
  level INT DEFAULT 1,
  PRIMARY KEY (account_id, card_id)
);

currency (
  account_id BIGINT PRIMARY KEY,
  gold INT DEFAULT 0,
  gems INT DEFAULT 0
);

purchases (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL,
  sku TEXT NOT NULL,
  price_cents INT NOT NULL,
  currency_code TEXT NOT NULL,
  platform TEXT NOT NULL,                   -- 'apple'/'google'
  receipt JSONB NOT NULL,
  verified BOOLEAN DEFAULT FALSE,
  paid_at TIMESTAMPTZ DEFAULT NOW()
);
```

**索引**：`matches(season_id, ended_at)`、`matches(p1_account_id, ended_at desc)`、`matches(p2_account_id, ended_at desc)`、`profiles(trophies desc)`（榜单 cache miss 时回源）。

### 6.2 Redis 键设计

```
session:<jti>                       → account_id           TTL refresh 周期
matchmaking:arena:<a>               → ZSET (elo → account_id)
matchmaking:meta:<account_id>       → HSET (joined_at, deck_id, elo)
leaderboard:global:s<sid>           → ZSET (trophies → account_id)
leaderboard:arena:<a>:s<sid>        → ZSET
ratelimit:deploy:<account_id>       → counter              TTL 1s
room:<room_id>                      → HSET (元数据)        TTL 1h
room:<room_id>:cmds                 → STREAM 指令流（重连/回放用）
online:<account_id>                 → 1                    TTL 60s 心跳
```

---

## 7. 客户端集成方式

### 7.1 文件级波及

| 文件 | 处置 |
|---|---|
| `logic/` | **不动**——逻辑层保持纯粹 |
| `net/` (新建) | `ws_client.gd`（连接/重连/心跳）、`auth.gd`（token 存盘）、`proto/`（gd-protobuf 生成产物） |
| `view/menu.gd` | + LADDER 入口（未登录跳登录页） |
| `view/login_scene.gd` (新建) | 匿名 dev 登录页（一键拿 token） |
| `view/ladder_scene.gd` (新建) | 匹配等待 / 进入对战 / 段位榜单 |
| `logic/player.gd` | 抽出接口 `IPlayer`；现有变 `LocalPlayer`；新增 `NetworkPlayer`（向 net 发指令、收广播 → 喂回 logic） |
| `logic/battle.gd` | + state hash 计算函数（仅在 net 模式下定期调用） |
| `ai/ai_controller.gd` | net 模式不用；本地训练营/Roguelite 继续用 |
| `config/` | 新增 `network.json`（服务端 URL、心跳间隔、tick rate 等） |

### 7.2 单机模式不受影响

- 主菜单选"训练营/Roguelite/短战役" → 走老路径（`LocalPlayer` + 本地 AI）
- 主菜单选"LADDER 天梯" → 走新路径（`NetworkPlayer` + 服务端）
- 服务端宕机 → LADDER 灰掉，单机模式无任何影响

---

## 8. 反作弊（V4 玩法验证阶段）

1. **指令合法性**：服务端校验圣水够、卡在手、落点在己方半场（Go 端口最小校验器，复用 `_deploy_allowed` 逻辑）
2. **状态哈希**：客户端每 10 tick 上报 `hash(units_state, towers_state, elixir)`，双方+服务端三方对帐
3. **速率限制**：Redis token bucket，每秒最多 N 次 deploy（防 flood）
4. **JWT 校验**：每条 WS 消息验签
5. **断线/异常**：超时认输、room TTL 清理

**推后到 S7**：胜率/掉线率离线扫描、模式识别、客服后台、封禁工具。

---

## 9. 服务端 Go 项目结构

```
server/
├── cmd/
│   ├── gateway/main.go        # WS 接入主进程
│   ├── api/main.go            # HTTP API（账号/档案/匹配/榜）
│   ├── battle/main.go         # 战斗 room 主进程（前期可合并到 gateway）
│   └── migrate/main.go        # DB migrations runner
├── internal/
│   ├── auth/                  # JWT/refresh
│   ├── profile/               # 玩家档案 CRUD
│   ├── matchmaking/           # Redis ZSET 队列
│   ├── battle/                # room/lockstep/hash 仲裁
│   ├── leaderboard/           # ZSET 读写
│   ├── season/                # cycle/重置
│   ├── store/                 # PG/Redis 客户端封装
│   └── pb/                    # protoc 生成产物
├── pkg/                       # 可复用工具
├── migrations/                # SQL up/down
├── docker-compose.yml
├── Dockerfile
├── Makefile
└── go.mod
```

**Makefile 关键 target**：
- `make gen-proto`：跑 protoc，同时生成 Go 和 GDScript 产物
- `make test`：`go test ./...`
- `make up` / `make down`：docker compose
- `make migrate`：跑 pg migrations

---

## 10. 待细化（到对应步骤前再展开）

- **ELO 公式细节**：K factor、初始分、新手保护期、胜率系数（V4-S4 前定）
- **赛季周期**：1 个月？2 周？软重置公式（cap 在哪一档？）（V4-S5 前定）
- **hash 算法**：sha256 全量？还是字段拼接 fnv？性能 vs 抗碰撞（V4-S3 前定）
- **断线重连窗口**：60s？120s？是否允许双方都断后恢复？（V4-S3 前定）
- **deploy 命令的 tick 偏移**：客户端送 tick=current+1 还是 current+2（消化 RTT）（V4-S3 前定）
- **客户端预测**：S3 先不做（lockstep 体感卡顿就上 client-side prediction）
- **匹配段位分桶细节**：几段？跨段允许吗？（V4-S4 前定）
- **deck schema 与 V3 现有 `cards.json` 的衔接**：用 id 数组直接存 / 还是引入 deck_template（V4-S2 前定）
- **F2P 经济曲线设计**：完全推后到 V4-S10
- **图片/回放对象存储选型**：MinIO（本地）/ S3 兼容协议（推后到 V4-S6）

> V4 锁定范围如上。超出范围（产品化全套）推后到 V4-S6+，**不在玩法验证阶段做**。
