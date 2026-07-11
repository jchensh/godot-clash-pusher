# HISTORY_V5_DETAILED — V5 已收官子步 · 详细逐步历史（归档）

> 2026-07-12 文档重整时从 [../HISTORY.md](../HISTORY.md) 归档（V5 仍进行中，本文件只收**已收官**的子步；进行中/欠验收段留在主 HISTORY.md）。收录：本地原型 S0~S6 / 在线化 N1~N7 / S7·S7+ UI 整合 / 工程迁移踩坑 / KAN-49 联机视觉 / 卡池扩充 16→48（设计四部曲 + KAN-85/86）/ 框架地基#2 Events·#3 Log·#4 lint（KAN-100/101/102）。**只查证、不追加**；后续子步收官时把详细段搬到本文件末尾。

---

### V5-S0 — 配置表骨架 + 存档 schema（已完成）
**前置决策**：见决策 47 + PLAN_V5.md。S0 = 骨架步（配置表 schema + 样例 + 存档草案 + ConfigLoader 接表），全 headless 单测覆盖。
- **4 张新配置表**（`config/`，结构性、JSON-first、不进 Excel 镜像）：
  - `stages.json`：闯关关卡（chapter/index/encounter/difficulty_coef/ai_difficulty/recommended_power/stars/first_clear/repeat/shard_drop）；S0 含 2 样例关（stage_1_1/1_2）。
  - `encounters.json`：遭遇模板（deck 8 张 + archetype）；S0 含 3 模板（starter_easy/tank_push_a/swarm_rush_a）。
  - `economy.json`：升级/升阶/解锁成本 + 数值曲线（level_stat_per_level 0.10 / rank_stat_mult 1.25 / level_cap_per_rank {1:4,2:7,3:10}）+ 挂机 + 奖励基数。〔示意·待平衡，V5-S8 probe 定〕。
  - `card_progression.json`：全 16 卡稀有度（普通6/稀有5/史诗4/传说1）+ starter（初始 8 张 = level_01 默认卡组）+ base_power + 各阶解锁 rank_unlocks（type=stat/skill，S5 实现）。
- **`logic/config_loader.gd`**：接 4 新表（load + 校验 + accessor get_stage/get_encounter/get_economy/get_card_progression/has_*）。校验：card_progression 双向覆盖 cards（每卡须有条目、rarity 合法、base_power 数字）；encounters deck 正好 8 张且卡存在；stages 的 encounter/ai_difficulty/coef(≥1.0) 合法 + 奖励/掉落 card 引用存在。`_` 前缀键（如 `_comment`）跳过。
- **`logic/player_data.gd`（草案）**：存档数据结构（wallet{gold,gems}/cards{level,rank,shards,unlocked}/stages{stars,cleared}/highest_cleared/idle）+ `init_new`（默认新档：全卡建条目、starter 8 张解锁）+ `to_dict`/`load_dict`（实例方法、不引用自身 class_name，遵 V3-4d 踩坑）。SaveSystem 接线 + 战力计算 + 解锁解算留 V5-S2。
- **单测**：`tests/test_v5_config.gd`（4：加载 4 表 / 覆盖全卡 / stage 引用合法 / 注入坏引用被校验抓出 + `_` 键跳过）+ `tests/test_player_data.gd`（3：默认档解锁 8 张 / 往返 / 缺字段默认）。**228/228**（221 + 7，零回归）。
- **踩坑**：①ConfigLoader 类成员 `var` 在 class 顶层（**无缩进**），首版 Edit 误带 tab 缩进 → 未匹配，去 tab 修正。②`build_config.py --check` 红——但是 **HEAD 既有 drift**：`levels.json` 的 `ladder_01`（V4-S3 加）未回灌 `GameConfig.xlsx`（经核 Excel 无 JSON 缺失项 → 无 clobber 风险）；但 `--from-json` 会整表重建 Excel（**可能丢 Balance_View/_Enums 等不导出 sheet**），未验证前不擅自跑 → 留作独立 housekeeping（待用户定夺：同步进 Excel / 让 check 跳过 ladder）。S0 新增 4 表本就不进 Excel 镜像，**未引入新 drift**。
- **Jira/PM**：Epic KAN-50 + S0~S8 = KAN-51~59 建好、全 To Do；KAN-51 In Progress；KAN-41（V4-S5）退回 To Do 暂缓。

---

### V5-S1 — 出兵数值乘区管线（已完成）
**前置**：S1 是养成/难度的命门地基（先于一切养成/关卡）。给出兵生成路径加一个 hp/damage 乘区，speed/range/attack_speed/tick 一律不动（保手感+确定性）。
- `logic/unit.gd`：+`apply_stat_mult(mult)`——只缩 max_hp/hp/damage；`mult==1.0` 提前 return（保证乘区未启用时逐位一致、零回归）。
- `logic/skill_system.gd`：`play_card` / `_execute_block` / `_spawn_unit` 多收 `stat_mult` 透传到生成单位；仅 spawn_unit 用（伤害/治疗积木本步不缩放）。
- `logic/player.gd`：+`unit_stat_mult` 字段（默认 1.0），`try_play_card` 出牌时带给 `skill_system.play_card`。
- `logic/match.gd`：+`set_stat_mults(player_mult, opponent_mult)` 一处注入双方乘区（来源后续接：敌方 coef = V5-S3 / 我方 = V5-S4/5）。
- **单测** `tests/test_v5_stat_mult.gd`（6：apply 只缩 hp/dmg·其余不动 / mult=1 逐位一致 / play_card 缩放 / 默认不变 / Match 注入 / Player 透传——敌方 3× knight 600→1800）。**234/234**（228 + 6，**228 旧测逐位零回归**）。
- **边界（故意，标在代码注释）**：①法术伤害（火球/闪电）不走通用乘区，养成对法术走升阶积木（V5-S5）；②亡语召唤的单位暂用基础数值（V5-S5 再议）。
- **顺带**（前置 housekeeping，commit `3699ad6`）：`build_config.py --check` 跳过结构性关卡 `ladder_*`（比照 arena.json 不进 Excel 镜像；check / --from-json / 反生成三向一致），修掉 V4-S3 遗留的 --check 红。

---

### V5-S2 — 玩家存档系统 + 战力计算（已完成）
- `logic/player_data.gd`：+`card_stat_mult`（= 等级乘 `1+(lvl-1)·0.10` × 阶乘 `1.25^(rank-1)`，读 economy 曲线）/ `card_power`（base_power × 乘区）/ `team_power`（卡组求和取整）/ `can_unlock`（碎片 ≥ 稀有度门槛）/ `ensure_cards`（卡池新增时补齐缺失卡、不丢档）。
- `logic/save_system.gd`：+`save_player`/`load_player`/`has_player_save`/`clear_player_save`（`user://player_save.json`）；无档 → `init_new`（初始 8 张解锁），有档 → `load_dict` + `ensure_cards`。
- **单测** `tests/test_v5_progression.gd`（6：落盘往返 / 无档建新档 / ensure_cards 补齐不覆盖 / 乘区曲线（满养成 ×2.969）/ 战力（knight L5=140·初始队伍=960）/ 解锁门控（golem 120 碎片））。**240/240**（234 + 6，零回归）。
- **设计点**：S2 只算"数值/战力/解锁"，**不接战斗**——我方乘区来源 `card_stat_mult` 由 V5-S4 出牌时注入、敌方 coef 由 V5-S3 注入。S2 是数据 + 计算层。

---

### V5-S3 — 闯关骨架 + 星级判定（已完成）
- `logic/stage_progress.gd`（新）：关卡按 (chapter,index) 排线性序列；`is_unlocked`（首关恒解锁 / 前关通关才解锁）、`next_stage`、`is_all_cleared`、`chapter_stars`、`apply_result`（≥1 星=通关，星数取 max 不回退，刷 `highest_cleared`）；进度持久在 `PlayerData.stages`（复用 CampaignState 二元推进范式）。
- **星级判定** `StageProgress.judge_stars(stars_cfg, outcome)`（静态纯函数）：未胜=0 星；胜=命中目标数（`win` 必中 → ≥1 星），支持 `king_hp_pct`（保塔血）/ `time_under`（限时）。`outcome={won,king_hp_pct,duration_sec}` 由 view/battle 结束时算（接 UI 留 S7）。
- `logic/match.gd`：+`setup_stage(stage_id, player_deck_override, player_stat_mult)`——读 stage：`difficulty_coef`→`set_stat_mults(_, coef)` 敌方出兵乘区、`encounter`→敌方卡组、`ai_difficulty`→AI 档；对局参数走 `base_level`（默认 ladder_01）。**S1 的敌方乘区在此真正用上**。
- `config/stages.json` +`base_level` 字段；`logic/config_loader.gd` 校验 base_level 引用存在。
- **单测** `tests/test_v5_stage.gd`（6：排序/解锁、推进+解锁下一关+章节星、星数取 max 不回退、未胜 no-op、三星判定 4 档、`setup_stage` 接 coef/deck/AI + **headless 跑通一关**：敌方 giant 2000×1.05=2100）。**246/246**（240 + 6，零回归）。
- **设计决策**：①**敌塔 HP 暂用 base_level 值、不随 coef**（coef 只放大敌方单位 hp/damage；塔血缩放留 V5-S8 平衡）；②base_level 统一 `ladder_01`（标准对局参数：圣水 1.0/10、180s、塔 2500/1450）。

---

### V5-S4 — 卡牌升级（金币·数值曲线）（已完成）
- `logic/player_data.gd`：+`level_cap(rank)`（economy.level_cap_per_rank：rank1→4/2→7/3→10）/ `upgrade_cost`（`base[rarity]·(1+(lvl-1)·growth)`，随等级线性涨）/ `upgrade_card`（花金币·level+1·受阶上限钳制）。
- **养成接进战斗**：`logic/player.gd` +`player_data` 字段 + `_resolve_stat_mult(card_id)`（有 player_data → 按本卡 `card_stat_mult` per-card 乘区；否则 flat）；`logic/match.gd` `setup_stage(..., player_data)` 注入我方养成。**升级一张卡，战斗里它真变肉变疼**（养成首次在战斗生效）。
- `config/economy.json`：`upgrade_total_gold` → `upgrade_cost_base`(80/160/320/600) + `upgrade_cost_growth`(0.5)；`config_loader` 校验 key 同步。
- **单测** `tests/test_v5_card_upgrade.gd`（6：扣金币+升级 / 成本随等级涨 / 阶等级上限拦 / 金币不足拒 / 锁定卡拒 / 战斗内我方 knight L6R2 ×1.875=1125 变肉）。**252/252**。

---

### V5-S5 — 卡牌升阶 + 技能积木解锁（已完成）
- `logic/player_data.gd`：+`rank_up_card`（花碎片+金币·rank+1·抬等级上限）/ `rank_up_cost`（economy.rank_up[rarity][rank-1]）/ `_max_rank`。
- **技能积木解锁机制** `logic/card_progression.gd`（新）：`effective_skills(base, rank_unlocks, rank)` 把 rank 2..当前的 `ops` 顺序叠加到 skills 深拷贝。op：`count_add`（spawn count+）/ `num_add`·`num_mult`（块 field 改，如 radius/damage）/ `unit_field`（spawn 块挂 `_unit_override` 改单位配置如 death_spawn）。
- `logic/skill_system.gd`：`play_card` +`skills_override`（用 effective skills）；`_spawn_unit` 合并 `_unit_override` 进 unit 配置。`logic/player.gd` +`_resolve_skills(card_id)`（rank≥2 → effective skills）。
- `config/card_progression.json`：给 11 张卡授 ops；**新机制类解锁**（on-hit 溅射 / 亡语溅击 / 对塔加伤 / 穿透 / 溅射 / 连锁 / 灼烧 / 护盾）engine 未支持 → **仅 note 占位、留 V5-S8**。
- **golem 示范偏差（有意，记踩坑）**：PLAN 原想"death_spawn 从 0 在 2 阶解锁"，但 `test_arena` 的 V3-3 亡语测试依赖 golem 基础亡语（2 哥布林）——移走会破 2 个测 + 触发 Excel 重建。改为**保留基础亡语、用 `unit_field` op 把 death_spawn_count 升阶放大（2→3→4）**，同样端到端验证 unit_field 机制、零 V3 回归、不动 Excel。
- **单测** `tests/test_v5_card_rank.gd`（9：effective_skills count/rank1/num_add/golem unit_field、升阶扣碎片+金币、升阶抬等级上限、最高阶+碎片不足拒、战斗内 goblins rank2 出 4 只、`_unit_override` 生成 golem 死兵 3）。**261/261**（V3 arena/skill_system 亡语测试零回归）。

---

### V5-S6 — 经济产出（首通/重复/挂机/解锁）（已完成）
- `logic/player_data.gd`：+`grant_reward`（通用：金币/宝石/碎片，任务/成就/章节宝箱占位复用）/ `grant_stage_reward`（首通 first_clear 大额 / 重复 repeat 小额 + 可选 seeded rng 概率 shard_drop）/ `unlock_card`（碎片够 → 扣 + 解锁）/ 挂机离线 `idle_rate_per_hour`（按最高通关章节）·`idle_pending`（累计封顶 cap_hours）·`collect_idle`（领取清零，`now_ts` 由 caller 注入、逻辑层不取系统时间）。
- **单测** `tests/test_v5_economy.gd`（9：首通/重复奖励、通用奖励、seeded shard_drop 可复现、解锁扣碎片/不足拒、挂机累计+封顶(8h)、领取刷基准、无进度 0 产出）。**270/270**。
- **占位说明**：日常任务/成就的"定义 + 每日重置"留后续；S6 提供其发奖机制（`grant_reward`）。

> **转向（决策 48）**：S6 后用户拍板把项目改为**实时在线 F2P、服务器权威**（推翻决策 47）。S7 UI 顺延到在线地基 + 服务器经济（N1~N7）之后。详见决策 48 + PLAN_V5 §11.1。

---

### V5-N1+N2 — 持久会话连接 + 配置服务器化（已完成）
**前置**：决策 48。在线地基头两步，复用 V4 的 gateway/auth/WS。一起做、自验（纯代码/数据逻辑，无表现层，免真机）。
- **proto**：`session.proto`（`ConfigPush{version, up_to_date, bundle}`）+ `common.proto` MsgId `CONFIG_PUSH=60`（60-69 = V5 会话/经济段）。双端重生成（Go protoc + godobuf）。
- **N1 服务端**：`internal/session`（`Manager` 一账号一连接、新登录挤掉旧；`Serve` = 注册 + 配置推送 + 心跳 PING→PONG + 掉线清理；`quit` 通道驱逐/关服）。gateway `/v5/session/ws?token=&cfgver=`（JWT 鉴权 → 升级 → Serve）。
- **N2 服务端**：`internal/gameconfig`（`Load(dir)` 读 `config/*.json` → 版本化 bundle，文件名升序确定性 sha256 版本）。连接时下发 `ConfigPush`：`cfgver` 命中 → `up_to_date`（不带 bundle）；否则全量。compose 把 `../config` 只读挂进 gateway（`CONFIG_DIR=/app/config`，双份同源）。
- **客户端**：`net/session_conn.gd`（token → 连 WS → 收 ConfigPush 入内存 + `user://config_cache.json` 薄缓存 → 5s 心跳 → 断线自动重连/窗口）。复用 `net/ws_client.gd`（顺带把入站缓冲调到 2MB——配置包 82KB 超默认 64KB）。
- **测试**：Go `gameconfig`（5）+ `session`（Manager 驱逐/注册 + buildConfigPush + WS 集成：配置推送/心跳/驱逐 httptest）；客户端 `tests/test_net_session.gd`（4）。**客户端 274/274**；Go 全绿。
- **端到端自验**（临时 harness `tools/_session_smoke.gd`，验后即删）：真 docker——登录 → 持久会话 WS → 收 82KB 配置（ver `2d6c03b…`，15 文件，cards 16 张 knight cost 3）→ 连接稳定 → 重连用缓存 cfgver → 服务器回 **up_to_date 不重发**。全通过。
- **踩坑**：①客户端方法名 `is_connected()` 撞 Object 原生（签名不符警告升错）→ 改 `is_online()`。②配置包 82KB > WebSocketPeer 默认入站缓冲 64KB → 收不到大帧 → 调 2MB。③Bash cwd 跨命令保留（`cd server` 后 godot `--path .` 找不到 test_runner）。

---

### V5-N3+N4 — 服务器权威经济状态 + 结算动作（已完成）
**前置**：决策 48。把本地原型 S0~S6 的养成/经济搬上服务器做权威（Go + PG，复用 V4 库 + auth + httpx）。一起做、自验。
- **proto**：`economy.proto`（`EconomyState`{wallet+卡牌+关卡} / `CardState` / `StageState` / `EconomyActionReq`）+ `common.proto` MsgId `ECONOMY_*=61~65` + ErrorCode `ERR_ECONOMY_INSUFFICIENT/AT_CAP/LOCKED=500~502`。双端重生成。
- **N3 DB + 状态**：`migrations/0006_economy`（`economy_state` 钱包/货币/挂机/highest + `economy_cards` 每卡 level/rank/shards/unlocked + `economy_stages` 每关 stars/cleared，FK accounts CASCADE）。`internal/economy/repo.go`：`Get` 懒播种（首次访问 → 全卡 level1/rank1，starter 解锁，镜像 PlayerData.init_new）+ 读取。`GET /v5/economy/state`（Bearer，account 取自令牌）。
- **N4 结算**：`internal/economy/config.go`（`ParseConfig` 从 bundle 的 economy.json + card_progression.json 解析曲线，镜像 player_data 的 cost/level_cap/rank_up/unlock）。`repo.go` `Upgrade`/`RankUp`/`Unlock`：单 tx `FOR UPDATE` 锁卡+state 行 → **服务器算成本 + 校验（解锁/上限/金币碎片够）+ 扣 + 落库**，拒绝映射 409 + 业务码。`POST /v5/economy/{upgrade,rank-up,unlock}`。
- **客户端**：`net/economy_client.gd`（HTTP + protobuf + Bearer：`get_state`/`upgrade`/`rank_up`/`unlock`，返回服务器状态快照或业务错误码）。
- **api 接线**：`cmd/api` 加载 gameconfig + ParseConfig + 挂经济路由；compose 把 `../config` 也挂进 api（双份同源，服务器用它算成本）。
- **测试**：Go `economy` config（成本/上限/真实 16 卡）+ repo 集成（PG：播种 16 卡 8 解锁 / 升级扣金币 / 升阶扣碎片抬上限 / 解锁 / 上限拒·不足拒·未知卡拒）；客户端 `tests/test_net_economy.gd`（4）。**客户端 278/278**；Go 全绿。
- **端到端自验**（临时 harness，验后即删）：真 docker——登录 → 拉状态（服务器播种 16 卡 / 8 starter 解锁 / gold 0）→ 升级 knight **被服务器拒绝**（gold 0，ERR_ECONOMY_INSUFFICIENT，证明客户端刷不了）→ 服务器侧授金币 → 再升级 **服务器扣 gold 10000→9920、knight level→2**。全通过。
- **踩坑**：①`docker compose build api` 是 no-op（只有 gateway 有 `build:`，api 共享镜像）→ 改 build gateway 重建 `gcp-server:dev`。②login 的 `account_id` 在 V4-S1 服务端恒 0（smoke 授金币改用 device_id join accounts）。

---

### V5-N5 — 通关发奖 + sanity 校验（已完成）
**前置**：决策 48。客户端上报 (stage_id, stars)，服务器 sanity 校验 + 发首通/重复奖励（含概率掉落）+ 记进度，全服务器权威（镜像 player_data.grant_stage_reward + stage_progress）。
- **拍板（用户 2026-06-27）**：①shard_drop 概率掉落 N5 就做（服务端 `math/rand`，非 lockstep 无需确定性，概率走配置表可控）；②0 星/超上限/未知关 → 复用 `ERR_INVALID_ARG`；③**stars 超上限 = 拒绝**（不钳制），detail 要告诉客户端原因；④进度连续 = 线性解锁（第一关恒可，否则前一关 cleared）；⑤范围只做通关发奖+sanity+记进度。
- **config.go 扩展**：`ParseConfig` 增量解析 `stages.json`（`Stage`{chapter/index/coef/FirstClear/Repeat/ShardDrop/starCap} + 按 (chapter,index) 升序的有序序列），跳过 `_` 元字段；缺 stars → starCap 默认 3。新增查询：`Stage/OrderedStageIDs/PrevStage/StarCap`（线性解锁/防跳关用）。
- **proto**：`economy.proto` 加 `StageClearReq{stage_id, stars}`（注释 0=拒/≥1=通关，不超 stars 配置条数）；`common.proto` MsgId `ECONOMY_STAGE_CLEAR_REQ=66` + ErrorCode `ERR_ECONOMY_STAGE_LOCKED=503`（跳关专用）。双端重生成（Go protoc + GDScript godobuf）。
- **repo.go StageClear**：sanity 三道——关存在(`ErrUnknownStage`) / stars≥1(`ErrInvalidStars`) / stars≤starCap(`ErrTooManyStars`)；线性解锁——有前驱且前一关未 cleared → `ErrStageLocked`。单 tx `FOR UPDATE` 锁 stage+state 行 → 发奖：首通(未 cleared)=`first_clear`、重复=`repeat`，固定碎片(reward.Shards)+shard_drop 概率(`rng().Float64()<chance`) → 写 `economy_stages`（stars 取 max、cleared=true）→ 刷 `highest_cleared`（有序序列里最后一个 cleared）→ 回新 `EconomyState`。
- **handler.go**：`POST /v5/economy/stage-clear`（单独 handler，带 stars 非 card_id）；`mapErr` 扩 503/跳关 → `ERR_ECONOMY_STAGE_LOCKED` 409，0星/超上限/未知关 → `ERR_INVALID_ARG` 400（detail 带 err.Error() 说明原因）。
- **客户端**：`net/economy_client.gd` `report_stage_clear(http, token, stage_id, stars)`（`StageClearReq` 打 `/v5/economy/stage-clear`）。
- **测试**：Go `economy` config +3（stages 解析：有序序列/前驱/reward/drop/starCap；真实 config 含 stages）；repo 集成 +3（首通发奖+stars max+highest、重复、跳关拒、0星拒、超上限拒、shard_drop 概率 200 次掉落验证）；客户端 `test_net_economy.gd` +1（StageClearReq roundtrip）。**客户端 279/279**；Go economy 全绿（含 N3/N4 旧测零回归）。
- **端到端自验**（临时 `cmd/e2e_n5`，验后即删）：真 docker 6 场景全 ✓——①首通 1_1(2★) +300g/+5gem/highest=1_1；②重复 1_1(3★) +30g→330；③0★ 拒 400 `ERR_INVALID_ARG` "stars must be >= 1"；④4★>cap 拒 400 `ERR_INVALID_ARG` "stars exceed stage star cap"；⑤跳关 1_2(1_1 未通) 拒 **409 `ERR_ECONOMY_STAGE_LOCKED`(503)** "stage not unlocked: previous stage not cleared"；⑥首通 1_2(1_1 已通) +320g/+skeletons:3/highest=1_2。
- **踩坑**：①首版 StageClear 漏发 first_clear/repeat 的**固定碎片**（只处理了 shard_drop）→ 测试 stage_1_2 首通 skeletons=0 抓出，补 `reward.Shards` 发放分支修复。②Go 全量 `-p 1` 偶现 economy flake（跨包共享 DB 残留 + 时序），`-count=1` 重跑稳定通过（非真 bug）。

> **下一步 V5-N6（挂机服务器时钟结算）**：服务器存 last_collect，按**服务器时间**算挂机产出落库（改本地时钟无效）。修复决策 48 头号刷资源漏洞（本地改时间刷挂机金币）。

---

### V5-N6 — 挂机服务器时钟结算（已完成）
**前置**：决策 48。挂机离线金币从「客户端本地时钟」（本地改时间可刷）改为「**服务器时钟**结算 + 落库」，修复头号刷资源漏洞。镜像 player_data.collect_idle，now 全服务器定。
- **拍板（用户 2026-06-27）**：①新号 `ensureSeeded` 时把 `idle_last_collect_ts` 设为当前服务器时间（注册即计时，更符合「挂机」直觉，非严格镜像 player_data 的 0 初值）；②章节驱动产率（rate=gold_per_hour_per_chapter×chapter），数值走 economy.json 配置（`idle: {gold_per_hour_per_chapter:50, cap_hours:8}`），代码不写死；③CollectIdle 纯触发无参（now 全服务器定）。
- **config.go 扩展**：`ParseConfig` 解析 economy.json `idle` 段（`Idle`{GoldPerHourPerChapter, CapHours}）；新增 `IdleRatePerHour(chapter)`（=GoldPerHourPerChapter×chapter）、`IdleCapHours()`、`HighestChapter(highestCleared)`（从 stage_id 查章节，未知/空→0）。
- **proto**：`economy.proto` 加 `CollectIdleReq{}`（空消息，纯触发）；`common.proto` MsgId `ECONOMY_COLLECT_IDLE_REQ=67`。双端重生成。
- **repo.go CollectIdle**：`now = time.Now().Unix()`（**服务器时钟**）→ 单 tx `FOR UPDATE` 锁 state 行 → 读 gold/last_collect/highest_cleared → `idlePending(now, lastCollect, highest, cfg)` 算累计（rate=IdleRatePerHour(HighestChapter)，elapsed=(now−last_collect) 钳≥0，hours=min(elapsed/3600, CapHours)，pending=floor(rate×hours)）→ 发金币 + last_collect=now → 回新 `EconomyState`。`ensureSeeded` 播种时 `idle_last_collect_ts=time.Now().Unix()`。
- **handler.go**：`POST /v5/economy/collect-idle`（无业务入参，读 body 验 proto 合法性即可）。
- **客户端**：`net/economy_client.gd` `collect_idle(http, token)`（`CollectIdleReq` 打 `/v5/economy/collect-idle`）。
- **测试**：Go `economy` idle 纯函数 `idle_test.go` 3（累计/封顶/边界 lastCollect≤0·未通关·时钟倒退·未知 stage）；config idle 解析 2（cfg + 真实 economy.json 50/8）；repo 集成 `TestRepo_CollectIdle`（新号播种 last_collect>0 / 未通关产0 / 倒拨 2h 累计 / 封顶 8h / 立即再领0 / 基准刷新）+ `TestRepo_CollectIdle_ServerAuthoritative`（服务器时间权威）；客户端 `test_net_economy.gd` +1（CollectIdleReq roundtrip）。**客户端 280/280**；Go economy 全绿（15 测，N3/N4/N5 旧测零回归）。
- **端到端自验**（临时 `cmd/e2e_n6`，验后即删）：真 docker 5 场景全 ✓——①新号 collect（注册即计时 last_collect>0，未通关产 0）；②通关到 chapter1 后立即领（elapsed≈0，金币=通关奖励）；③倒拨 last_collect 2h（chapter1 rate 50/h，gained ~99~100，时间戳毫秒精度致 floor 偶差 1）；④倒拨 100h（封顶 cap 8h → 50×8=400）；⑤立即再领（基准已刷新 → +0，无重复领）。**服务器时钟权威验证成立——客户端改本地时钟无效**。
- **踩坑**：①首版纯函数测试用 `lastCollect = 10000 - 3600*100` 算出负数（-350000）→ 命中 `lastCollect<=0→0` 误判封顶失败，改用大基准时间戳 `base=1e9` 修复（非逻辑 bug，测试数据问题）。②e2e 倒拨 2h 期望精确 +100 实得 +99（floor + 时间戳毫秒精度），改用容差 [95,100] 判断——这是 floor 的真实行为（挂机不满整点按比例给），非 bug。③e2e 集成测代码编辑时误删了相邻的 `TestRepo_StageClear_ShardDrop` 函数签名（Edit 范围误伤），已补回。

> **下一步 V5-N7（瘦客户端化）**：`PlayerData` 降为服务器状态缓存；养成/领奖改调 API；开战从服务器拉权威 level/rank → 客户端确定性算战斗数值。真机验收：改存档/改时钟均无效（N6 已堵时钟，N7 堵存档）。

---

### V5-N7 — 瘦客户端化（已完成）
**前置**：决策 48。客户端养成数据从「本地存档权威」改为「**服务器权威 + 本地非权威缓存**」，堵住「改本地存档文件影响开战数值」。N6 已堵时钟、N7 堵存档，在线化整线收官。
- **现状发现（关键）**：开工前读到——客户端养成（PlayerData）此前是「纯逻辑层 + 单测」状态：`match.setup_stage(stage_id, deck, player_data)` + `player.gd` 的 `player_data` 注入口子（出兵按卡 level/rank 算乘区）**早已写好**，但 `battle_scene` 实际开战用的是老的 `match.setup(...)`、view 层零养成 UI（grep upgrade/economy_client 全空）。即养成还没接进实际游戏（那是 S7 的活）。故 N7 聚焦「为 S7 备好权威数据来源机制」，不碰 UI、不给 battle_scene 加无入口的死代码。
- **拍板（用户 2026-06-27）**：路径 A（纯逻辑+代码，不动 UI）/ 本地档 A1（保留但降为非权威缓存镜像）/ 真机验收留 S7（N7 单测覆盖）。
- **`PlayerData.apply_server_state(server_state, all_card_ids)`**：从服务器权威快照重建自身（shape = `economy_client._state_to_dict` 输出：顶层 gold/gems/idle_last_collect_ts/highest_cleared；cards/stages 嵌套）。与 `load_dict` 区别：后者读本地存档 schema（wallet/idle 嵌套），本方法读服务器 schema；ensure 缺失卡补默认条目。
- **`net/economy_state_cache.gd`（EconomyStateCache）**：持有最近一次服务器状态快照（PlayerData 形状）。`refresh(http, token, all_card_ids)` 调 `economy_client.get_state` → `apply_server_state` 重建 + `is_loaded=true`；**`for_battle(all_card_ids)` 返回适合注入 `Match.setup_stage` 的 PlayerData**（已加载→缓存即服务器养成；未加载→默认新档保战斗能跑）；`seed_from_local(pd)` 离线兜底（秒启动展示，不改 is_loaded）；`get_cache()` UI 只读。
- **`SaveSystem` 降级**：`save_player/load_player` 注释改为「**非权威本地缓存镜像**」——存读的 `player_save.json` 是 EconomyStateCache 的落盘镜像（秒启动/离线只读），不是权威档；开战/校验用 `EconomyStateCache.for_battle()`（服务器拉来），改本文件不影响开战；登录后被服务器覆盖。
- **不动的部分（明确边界）**：没改 `battle_scene`（S7 做闯关入口时调 `cache.for_battle()` 注入 `setup_stage`）；没碰 view/ UI；没改服务端 Go（N7 纯客户端）。
- **测试**：`test_player_data.gd` +1（apply_server_state 重建 + ensure 缺卡）；`test_economy_state_cache.gd` 新建 4（for_battle 未加载返默认 / for_battle 用服务器养成≈3.0 / **改本地档不影响开战（决策48核心）** / 缓存反映最新服务器态）。**客户端 285/285**；Go 全绿（N7 未动服务端，零回归）。
- **端到端自验**（临时 `cmd/e2e_n7`，验后即删）：真 docker get_state 返回完整养成快照（16 卡 8 解锁 + idle_last_collect_ts>0 + knight baseline），客户端 apply_server_state 后即可开战——服务器侧链路验通（客户端 apply/for_battle 已被 GDScript 单测覆盖）。
- **踩坑**：①首版用 `//` C 风格注释（GDScript 用 `#`）→ 改。②测试用 `before_each` 钩子，实际 runner 调的是 `setup()` → 改方法名。③`for_battle` 依赖 `is_loaded`，测试模拟 refresh 成功要直接设 `cache.cache`+`is_loaded=true`（seed_from_local 不改 is_loaded，语义上离线兜底不算权威确认）。

> **在线化整线收官（N1~N7 全完成）**。后续转入 S7 UI 整合 → S8 内容铺量 + 平衡（详见下文 + 顶部总览表；完整口径见 [PLAN_V5.md](../PLAN_V5.md) §11）。

---

### V5-S7 — UI 整合（已完成，KAN-58 Done）
**前置**：N1~N7 在线地基就绪（服务器权威经济 + `EconomyStateCache`）。把养成/经济/闯关从 headless 逻辑接上界面：**读 = 服务器权威快照缓存，执行 = API，展示算 = 本地 ConfigLoader**。设计稿 [docs/DESIGN_V5_S7_UI.md](DESIGN_V5_S7_UI.md)。
- **S7a 共享 HUD 组件**：`view/ui/hud_widgets.gd`（工厂 + 纯助手）+ `hud_widget.gd`（纯 `_draw`：钱包条/星级/cost 药丸/阶 pip/数值条/锁罩，**0 贴图资源**）。
- **S7b 基地 Base Camp**：替换主菜单 START 入口；app shell 登录→`EconomyStateCache.refresh` 拉服务器状态→展示钱包/队伍战力（本地算·按推荐着色）/挂机产出+领取。
- **S7c~e 闯关+养成+组卡**：闯关地图 `stage_map` + 领奖开箱 `reward_chest` + `battle_scene` 接闯关模式（`setup_stage`→战后判星→`report_stage_clear`）；养成 `card_collection`/`card_detail`（升级/升阶/解锁走 `EconomyStateCache` 门面）；`deck_builder` 已解锁池 + 战力达标着色 + mode-aware 路由。
- **★修复必现 bug**：stale `GameState.run/campaign`（玩过肉鸽残留静态态）致闯关战误判肉鸽模式 → `deck_builder` 开战前清 run/campaign + `level_select` 清 stage_id。
- **日志**：客户端全流程 `[V5]` 打点；服务端 api 请求中间件 + economy handler 业务日志。
- **验收**：客户端单测 **290/290**；**真人全流程验收通过**（闯关 1-1 胜 3 星→首通 +300 金 +5 宝石→进度推进 + 1-2 解锁→挂机产出→升级 giant）。Jira KAN-58 **Done**。提交 `123866c`/`6e9c53d`（验收用例 [docs/ACCEPTANCE_V5_S7.md](ACCEPTANCE_V5_S7.md)，7 例全过）。

---

### V5-S7+ — 养成卡多维排序（已完成，KAN-67 Done）
- 逻辑层纯函数 `logic/card_sort.gd`（键 rarity/cost/level/actionable + 稳定排序，5 单测）+ `card_collection` 顶部分段控件（4 键 + 升降序）+ 即时重排（缓存重建网格、不重拉服务器）+ 记忆上次选择（`user://settings.cfg`）。客户端 **295/295**；真机即时重排观感正确。提交 `f38f5eb`。

---

### 工程迁移 + 多 agent 共享工作树踩坑（2026-06-28）
**迁移**：`Move-Item F:\godotProject F:\godotTowerPush\master`（同盘瞬时重命名、零拷贝）→ git 仓库/对象/远端全部无损、`.git/config` 无旧路径泄漏；工程 `res://` 相对路径天然不受影响、`.godot/` 缓存 gitignore 重建即可。仅**文档线滞后**于代码（CLAUDE 进度停在 N5、README 290 单测、多处旧绝对路径 + 旧 `develop` 分支约定）→ 本轮统一对齐到现实（主干流 / S8 进行中 / 313 单测 / 旧路径清理），提交 `cfa15d7`。
**踩坑（两个 agent 抢同一个工作树）**：文档作业期间，另一个 agent（ZCode）在**同一个工作树**里 `git checkout` 把分支从 `master` 切到新建临时分支 `zaiDev`，我那批**未提交**的文档改动被一起带了过去（切分支时未提交改动会跟随 HEAD）。
- **诊断**：`git reflog` 还原序列（`commit 247c15f` → `checkout: moving from master to zaiDev`）；`git stash` 空、无提交吞掉改动；关键发现——`zaiDev` 从 `master` 尖端刚拉出、**两者指向同一 commit `247c15f`**。
- **无损还原**：因两分支零差异，`git checkout master` 时 Git 不改任何工作区文件、未提交改动原样留下、HEAD 重指 master → 改动安全归位（不可能冲突或丢失）。随后用**显式文件名** `git add`（避免在共享树里卷入异己改动）+ 提交 `cfa15d7`，工作树转干净、解开两 agent 纠缠。
- **教训**：① **多个 agent 绝不共享一个工作树**——每任务用 `git worktree add ../master-<feat> <branch>` 开独立树作业（正是 CLAUDE.md / AGENTS.md「分支约定」要求的纪律，这次正是没遵守才撞）；② 提交前先 `git rev-parse --abbrev-ref HEAD` 验分支、`git add` 用显式文件名不用 `-A`；③ 已关停乱切的 ZCode；`zaiDev` 待其任务合回 master 或废弃后 `git branch -d zaiDev` 清理。

---

### V5-KAN49 — 联机视觉对齐（🚧 代码完成、真人两机验收待跑）
**前置**：V4-S3 联机对战场景 `net_battle_scene` 当初为聚焦网络正确性做成**矢量白膜**（圆=单位/方块=塔/文字卡面），记 KAN-49 待办。本次把单机 `battle_scene` 的完整视觉搬进去。**逻辑层零改动**——lockstep 跑同一 `logic/match.gd`，单机/联机的 Match/Battle/Arena/Unit/Tower/Player/Deck/Elixir 实例就是同一个类的实例，juice/FX/插值/投射物（基于 `get_instance_id()`+hp/cooldown diff）**owner/side 无关、零适配直接搬**。纯 view 层搬运 + 联机特有的 3 处适配 + 3 个技术坑。

**联机特有 3 处适配（必改）**：
1. **`match_obj.player → _client.local_player()`**：单机 ~8 处 `match_obj.player.{deck,elixir,can_play,card_cost}` 直读（单机本方恒 player）；联机 side2 玩家本方是 opponent（owner 不随 side 翻转：恒 player=0/opponent=1）→ 圣水条/卡面/下一张/拖拽判 mine 全部走 `local_player()`。
2. **owner/side 翻转**：①队伍色 `_is_mine(owner)`=`(o==0 and not _flip) or (o==1 and _flip)`；②王冠计数 `_my_towers()/_foe_towers()` 按 `_flip` 选 player/opponent_towers；③落点 `can_deploy(owner)` 的 owner=`your_side-1`（side1→0/side2→1）；④己方半场高亮 `_deploy_y_min`=`deploy_player_y_min if not _flip else grid_h-deploy_player_y_min`（本方半场恒在屏幕下方）；⑤胜负语义 result 是 **side 语义**（winner 1=side1/2=side2），`mine = _flip?2:1`。
3. **结算演出触发源**：单机靠 `match_obj.is_over()` 本地判 → 联机改 `_on_result` 服务端信号驱动 `_start_ending`。

**联机特有 3 个技术坑**：
1. **sim 驱动差异（命门）**：联机 sim 由 `battle_client.poll`→tick bundle→`advance_tick` 驱动，**view 不能调 `match_obj.update()`**（单机那样做会双驱 sim、破坏 lockstep）。`_detect_events`/`_detect_attacks`/`_update_disp`（只读 diff）照搬。**顿帧改写**：单机冻结 sim 无意义（sim 非本地驱动）→ 改「纯视觉顿帧」——冻结 FX 时钟 `_elapsed` 增量让画面定格，**不影响 lockstep 推进**（`_process` 里 `if _hitstop_t>0: _hitstop_t-=delta else: _elapsed+=delta`）。
2. **精灵朝向翻转**：side2 坐标 `_t2s` 翻转是平移不旋转像素 → owner 1（本方）兵贴图朝向会反。解法：`SpriteDB.frame` 的 owner 参数在 `_flip` 时镜像传值（`spr_owner = u.owner_id; if _flip: spr_owner = 0 if u.owner_id==1 else 1`），让贴图朝向跟随屏幕视角而非逻辑 owner。
3. **资源/音频齐备**：`battle_scene`+`sprite_db` 所有 preload 路径 + `.import` 全部存在直接复用；AudioManager 是全局 autoload、缺失资源静默 no-op（当前音频文件未入库，调用都是空操作，与单机一致）。

**一次性搬运的 7 大模块**（`view/net_battle_scene.gd` 366→~960 行整体重写）：①资源 preload（塔/FX/投射物/地形 + SpriteDB）；②地形 `_draw_terrain`（地面/水动画/桥 + 己方半场高亮按 flip）；③单位 `_draw_units`（SpriteDB+状态派生 walk/attack+闪白+入场缩放+空军影子/上浮+side2 朝向翻转）；④塔 `_draw_towers`（贴图保持长宽比贴地+队伍色+血条+王冠+废墟）；⑤战斗 juice（`_detect_events`/`_on_hit`/`_on_tower_destroyed`/`_update_disp`/`_update_shake`/`_pop_scale`+顿帧改纯视觉）；⑥FX+投射物（`_detect_attacks`/`_tower_target`/`_draw_projectiles`/`_draw_fx`+落地涟漪+出牌音效）；⑦HUD+演出+音频（分段圣水+满槽脉动+自绘卡面+下一张+王冠倒计时；胜负演出调暗/标题 sting/王冠落入/比分滚动+按钮淡入，触发源改 `_on_result`；`_on_joined` 接 `AudioManager.play_music/play_ambience`）。

**验证**：客户端单测 **313/313 零回归**（`test_net_battle_client` 7 测不动）；headless `--editor --quit` 导入无脚本错误。net_battle_scene 是纯 view（`_draw` 驱动），无新逻辑层单测；**画面/手感交真人两机验收**。

**真人验收**：用例 [docs/ACCEPTANCE_V5_KAN49.md](ACCEPTANCE_V5_KAN49.md)（8 例：地形/精灵/塔/HUD/涟漪投射物FX/juice/胜负语义/**side2 视角全面**——side2 是联机特有最大风险点，须单独验精灵朝向不反、落点合法、本方数据正确）。**验收过 + 用户拍板 → KAN-49 Done**。

**分支/worktree**：本次在 `master-zaiDev` worktree（feat/zaiDev 分支原址）新建 `feat/kan49-net-visual` 开发（基于 master 尖端 ce699df；zaiDev 分支保留不动、待用户清理）。Jira KAN-49 To Do → **正在进行**。

---

### V5 卡池扩充设计（16→48）+ 三件套引擎 — 设计四部曲完成、T1 splash 开工（🚧 进行中，2026-07-03）

**背景**：战斗系统已可用但卡池仅 16 张、深度不足。用户发起卡牌系统深度扩充：扩池 + 稀有度/流派/觉醒三维体系。plan-first、逐阶段用户确认，四阶段设计文档产出于 `docs/design/`：
- `01_research.md`：CR 品类调研（稀有度/进化/流派/费用平衡/卡池规模，WebSearch）+ 本项目 16 卡 per-elixir 价值锚。
- `02_design_constitution.md`：稀有度(4 档·数值放大系数硬性 1.0)/流派(6 做 2 缓)/觉醒(rank 永久制·机制优先)/CV 平衡尺(CV=√(队伍HP×DPS)·近战地面基准 80·远程对空吃半预算) + 三件套 schema。
- `03_card_library.md`：+32 张达 48，金字塔 18/14/10/6，全表 + tech_debt + retrofit。
- `04_awakenings_meta.md`：16 张 epic+legendary signature 觉醒 + meta 分析(Lavaloon/Hog/Bait + 2 结构隐患) + 平衡原则(最小杠杆优先)。

**关键决策（用户逐阶段拍板 2026-07-03）**：①**稀有度≠强度**（`base_power` 只作战力折算/展示、禁喂战斗数值；同级同费不看稀有度）；②Champion 第 5 档暂不做（主动激活技能=重引擎）；③觉醒走 **rank 永久制**（非 CR 循环/进化槽，复用 `rank_unlocks`）；④signature 觉醒仅 epic+；⑤规模 ~48、金字塔 18/14/10/6；⑥6 流派做（swarm/beatdown/cycle/splash-control/air/bait-lite）、真 Siege+桥头 spam 缓；⑦**三件套(splash/building-target/status)** 获批为前置引擎工作；⑧retrofit **R-A(baby_dragon 加 splash) + R-B(giant/golem 只拆塔) 都做**。

**实现顺序**：三件套 T1/T2/T3 → retrofit R-A/R-B → 32 卡数值铺入 config + 校验 → 觉醒填 rank_unlocks → probe 平衡 → T6/T7 延后件(balloon death_aoe / inferno ramp / electro chain)。

**T1 · 单位攻击溅射 splash（本步 · 🚧 代码+单测完成，待用户确认后进 T2）**：
- `logic/unit.gd`：+`splash_radius`（默认 0=单体，零回归）；`setup` 解析；`apply_stat_mult` 不缩放它（radius 非战斗数值）。
- `logic/arena.gd`：攻击结算阶段 +`_collect_splash(attacks, attacker, primary, damage)`——命中后对 primary 周围 `splash_radius` 内**其他存活敌方单位**同施伤；只打单位不含塔、尊重 `can_hit_type`（地面溅射不误伤空军）、排除主目标防双击；收集式与主攻击同批 apply，确定性。
- `logic/config_loader.gd`：unit 校验加 `splash_radius` 可选（数字、≥0）。
- 单测 `tests/test_splash.gd`（4：多敌溅射 / 半径外不中 / 地面溅射不误伤空军 / splash=0 单体零回归）。**客户端 331/331**（+4，零回归）。注：顶部总览表的 313 为 KAN-49 时点旧值、之后 S9/KAN-76/78-79 累加至 327 未回写总览；本步 327+4→**331**。
- **边界**：T1 只做「单位攻击溅射」；法术 `aoe_damage` 不受影响；建筑索敌(T2)/状态(T3)/retrofit(R-A/R-B) 为后续步。
- **未提交**（用户暂不提交）。

**Jira 建单（用户 2026-07-03 明确要求用 Atlas MCP 建，覆盖"手工维护"默认）**：**KAN-80~88 共 9 张挂 Epic KAN-50 下**——KAN-80 设计四部曲(已完成) / KAN-81 T1(正在进行) / KAN-82 T2 + KAN-83 T3 + KAN-84 retrofit R-A/R-B + KAN-85 铺 32 卡 + KAN-86 16 觉醒 + KAN-87 probe 平衡(均待办 To Do) / KAN-88 延后件 T6/T7/chain(Idea)。

**T2 · 建筑索敌 target_priority=buildings（🚧 代码+单测完成，待用户确认后进 T3）**：
- `logic/unit.gd`：+`target_priority`（"nearest" 缺省=现状零回归 / "buildings"）；`setup` 解析。
- `logic/arena.gd`：`_acquire_target` 加分支——buildings 时无视敌方单位、直锁 `nearest_enemy_tower`、不被 aggro 分心。反制靠 body-block + 塔火 + 高单体 DPS（无防御建筑"拉扯"，见 docs/design/04 隐患A）。**本步先上纯版**；"优先建筑但仍受 aggro 拉扯"软版留 retrofit(KAN-84)/probe 定。
- `logic/config_loader.gd`：unit 校验加 `target_priority` 可选（nearest/buildings）。
- 单测 `tests/test_building_target.gd`（4：无视敌兵直锁塔 / 攻塔不打身边兵 / 朝塔推进不被侧兵勾走 / 缺省 nearest 仍分心零回归）。**客户端 335/335**（+4，零回归）。
- 服务哪些卡：bone_ram/royal_giant/hog_rider/battle_ram/balloon/lava_hound + retrofit giant/golem。**未提交**。

**T3 · 状态系统 status(slow/stun/freeze)（🚧 代码+单测完成，待用户确认）——三件套收官**：
- `logic/unit.gd`：+`on_hit_status`(命中施加) + 单状态计时层(`_status_kind/_timer/_mag`)；`apply_status`(硬控不被 slow 顶掉) / `tick_status`(衰减过期清空) / `action_speed_mult`(stun·freeze→0、slow→1-mag、无→1) / `is_stunned` / `has_status`；`can_attack` 加 stun 门；`tick_cooldown` 按 action_speed_mult 缩放（slow 减慢攻击恢复、stun 冻结冷却）。
- `logic/arena.gd`：tick 加 `tick_status`；移动 `_move_toward(u, target, dt × action_speed_mult)`（slow 减速/stun 停步）；攻击结算带 on_hit_status → apply 阶段对命中【单位】施加状态（塔不受状态，`is Unit` 守卫）；`_collect_splash` 透传 status（splash+slow 同施）。
- `logic/skill_system.gd`：`_aoe_damage`/`_direct_damage` 支持 `status` 块 → 命中敌兵施加（freeze 术 = damage 0 + status）；helper `_apply_block_status`。
- `logic/config_loader.gd`：unit `on_hit_status`(对象 + kind 合法) + card skill `status`(对象 + kind 合法) 校验。
- 单测 `tests/test_status.gd`（10：施加/衰减过期 · slow 行动乘区 · stun·freeze 停动停攻 · 硬控不被 slow 覆盖 · slow 减慢冷却 · on-hit 施加 · 眩晕不造成伤害 · 法术 freeze · slow 减少推进 · 无状态零回归）。**客户端 345/345**（+10，零回归；踩坑：移动测试原用地面兵，绕桥致 y 进度非单调误判 → 改飞兵直线越河）。
- 服务：ice/electro_spirit、giant_snowball、freeze、ice_wizard、electro_wizard + heal/lightning/musketeer/baby_dragon 等觉醒。**未提交**。

> **三件套 T1/T2/T3 全部代码+单测完成**（KAN-81/82/83，未提交），客户端 **345/345**。下一步 = retrofit R-A/R-B（KAN-84）→ 32 卡铺入（KAN-85）→ 觉醒填表（KAN-86）→ probe 平衡（KAN-87）。

**retrofit R-A/R-B（KAN-84，🚧 代码+配置完成，待真人验收）**：三件套就绪后给现有卡挂机制、让 RPS 三角闭合。
- **R-A** `config/units.json` baby_dragon_body +`splash_radius: 1.5`：单体飞行肉 → 空中反 swarm（补"空中清群"边）。
- **R-B** `config/units.json` giant_body + golem_body +`target_priority: "buildings"`：现会打兵 → 真·只拆塔 beatdown（无视敌兵直取塔；golem 亡语裂 2 哥布林保留）。
- **xlsx 同步（用户提醒）**：`splash_radius`/`target_priority` 是 units 新字段、原 `build_config.py` 固定 `UNIT_HEADERS` 不含 → 直接改 JSON 会破 xlsx 往返（--check 报缺字段、--from-json 丢字段）。**故给 `build_config.py` 加两列往返**：`UNIT_HEADERS` +2 列 + `TARGET_PRIORITIES` 枚举 + Excel→JSON 可选读（splash>0 / target_priority≠nearest 才写，仿 death_spawn）+ JSON→Excel 写 + target_priority 下拉校验。流程：基线 `--check` ok（原本同步、无未回灌手改）→ 改 JSON → `--from-json` 重建 xlsx → `--check` ok（往返一致）。
- **验证**：客户端 **345/345**（零回归：配置带新字段过校验、giant/golem 只拆塔 + baby_dragon splash 无单测回归）；`config check ok`。**决策**：这俩是 unit 字段 → 进 Excel 镜像（同 units.json 全镜像惯例，非 arena.json 式排除），designer 可在 Units sheet 调 splash 半径。**on_hit_status（嵌套 dict）的 xlsx 表示留 KAN-85**（届时有 status 单位才需）。
- **play-feel 交真人验收**（改现有 PvE 手感，用例见 docs/design 派生 + 对话）；**probe 数值复衡并入 KAN-87**（AI-vs-AI 非可靠绝对裁判、数值仍 placeholder）。**未提交**。

**🐞 修复：闯关进战斗空指针卡死（KAN-78 await 隐患，本轮验收暴露、非本轮改动引起）**
- **现象**：选卡组进闯关战斗，`view/battle_scene.gd:937 _sync_cards` 每帧 `Invalid access to property or key 'deck' on a base object of type 'Nil'`（`match_obj.player` 为 Nil）卡死。
- **根因**：闯关模式 `_ready` 有 `await economy.pve_start`（KAN-78 开战报到）；`match_obj` 在 await 前已建（第160行）、`player/battle` 要等 await 返回后 `setup_stage`（第199行）才建。节点处理默认开启 → await 挂起期间 `_process` 照跑，而 `_sync_cards` 只挡了 `match_obj==null`、没挡 `player==null` → 空指针（`_draw`/`_detect_*`/`_update_disp` 都挡了 `battle==null` 故安全，独 `_sync_cards` 漏挡）。
- **修复**：①`_ready` 开头 `set_process(false)`，末尾 setup 完的 `set_process(true)` 才逐帧（根治 await 窗口，其余早退场景也不再空转）；②`_sync_cards` 补 `match_obj.player == null` 守卫。headless 编辑器导入无脚本错误。**与本轮卡/引擎/config 改动无关**（未碰 view/；units.json 新字段是客户端战斗用、服务端不读）。**真人重测确认**。
- **相关提醒**：本轮改了 `config/units.json`（配置版本 sha256 会 bump）→ 建议**重启 Go 服务端**让它加载新配置，保 KAN-79 重放验证时客户端 sim 与服务端校验用同一份配置（否则 baby_dragon splash / giant 只拆塔的行为差异可能致重放 hash 不一致）。

**🔎 KAN-78/79 反作弊 × 卡池扩充/养成 冲突排查（dockers 实跑验证，2026-07-03）**
- **背景**：用户问三件套/新卡/养成会不会和 KAN-78/79 重放验证打架。
- **结论：架构上安全，冲突是"版本同步"运维问题、非架构问题。** 验证器 `tools/pve_verify.gd` 自己 `ConfigLoader.load_all()` 读 `res://config` + 复用 `res://logic`（MatchScript/BattleScript…）+ 服务器权威养成快照 → 与客户端 sim **同配置同逻辑同养成**、无逐卡硬编码，新卡/新机制/养成天然一致。
- **实跑验证**（临时 smoke `tools/_pve_retrofit_smoke.gd`，验后删）：录一局含 retrofit 机制（baby_dragon splash + giant/golem 只拆塔）→ 进程内 `PveReplay.replay` + 真 CLI `pve_verify.gd` **均 pass**（逐 hash 全等、win、ticks=428/king_permille=1000 一致）。三件套/retrofit 确定性穿过 KAN-79 完整链路。
- **真冲突（运维·3 处须同版本：客户端 res:// / Go 内存 cfg / verifier 容器拷贝）**：
  1. **verifier 容器 = 启动那刻从只读挂载 `/repo` 拷 logic/config 到 `/work/project`**（`verifier-entrypoint.sh`）→ **改 logic/config 后必须 `docker restart server-verifier-1` 重新拷**，否则用旧逻辑重放 → 每局 ticks/king_hp 对不上 → mismatch → `accounts.ban_status=1` shadow 标记。**本轮已重启同步**（容器 2h 前起、我改动更晚；重启后日志确认 re-staged + polling）。
  2. **加新卡(KAN-85) → 必须重启 api**：`ensureSeeded` 从服务端内存 cfg 播种 `economy_cards`；`PveStart` 要求卡组 8 张全有行 + unlocked，否则 "card unknown" 拒开战。
  3. **min_stage_duration_s=15（墙钟）vs 强卡快通**：giant 只拆塔可能 <15s 通关 → `validatePveClaim` 判 "too fast" 误杀。铺卡/平衡时留意。
- **附带澄清**：verifier 日志里 `bad hash entry`/`mismatch` 是在啃**集成测试合成数据**（`h="aa"`/单条指令，battle 653-655/463-477），非真实对局、非 bug（用户被崩溃挡住没打成真局）。验证器本身正常。
- **运维铁律（卡池后续每步）**：改 logic/config → 重启 verifier 容器；加卡 → 另重启 api（+gateway 保配置版本）。

**✅ 验收收尾（2026-07-03，本批一起提交）**：三件套 **T1/T2/T3** + **retrofit R-A/R-B** 真人验收通过——①闯关进战斗不再崩/卡死；②giant/golem 只拆塔；③baby_dragon(游戏内名「余烬火颅」)溅射清群。客户端 **345/345**。Jira **KAN-81/82/83/84 → Done**，闯关崩溃修复建 **KAN-89(Bug) → Done**。verifier 容器已重启同步。**下一步 = KAN-85 铺 32 张新卡**（届时 restart api + verifier；含新卡 id↔中文名对照表 + on_hit_status 的 xlsx 表示）。**另交付美术清单** `docs/design/card_art_spec_48cards.xlsx`（48 卡×17 列，种族/职业/体型/移动/攻击/动画/特效，供美术画原画+帧动画+FX）。

---

### V5 卡池扩充 · KAN-85 铺 32 张新卡（✅ 完成，2026-07-03，独占 master 自主开发）
- **32 卡入库** → **48 张**（普通18/稀有14/史诗10/传奇6）：`cards.json`/`units.json`(+27 单位实体，含复用 minion/goblin/skeleton/spear_goblin body)/`card_progression.json`。数值=docs/design/03 §D 角色模板锚定示意值·待 KAN-87 probe。用足三件套：splash(fire_spirit/valkyrie/bomber/wizard/executioner/ice_wizard/princess)、building-target(bone_ram/royal_giant/hog_rider/battle_ram/balloon/lava_hound)、on_hit_status(ice/electro_spirit/ice_wizard/electro_wizard) + 法术 status(giant_snowball/freeze)；多积木(goblin_gang/electro_wizard 落地 zap)、亡语链(bone_ram→骷髅/battle_ram→蛮兵/phoenix→重生/lava_hound→6火犬)。
- **build_config.py 扩**：Units +`on_hit_status_kind/dur/mag`、CardSkills +`status_kind/dur/mag`（flatten 嵌套 dict）+ `STATUS_KINDS` 枚举 + 下拉校验。`--from-json`+`--check` 往返一致（32 新卡 + status 列都镜像进 GameConfig.xlsx）。
- **card_progression**：32 卡 rarity/base_power/`starter:false`(未解锁) + 轻量 rank_unlocks（swarm→count_add/法术→num_add/其余 stat；**epic+ signature 觉醒留 KAN-86**）。
- **服务端 ensureSeeded 改增量补种**(`repo.go`)：`INSERT … ON CONFLICT (account_id,card_id) DO NOTHING` —— 新卡上线后**已有账号下次访问自动补进缺失卡**（不动已有养成；新卡 starter=false 播为未解锁）。修 `config_test`/`repo_integration_test` 的 16→48 断言。Go 的 `cfg.Cards` 只从 card_progression 读 rarity/starter/base_power（忽略 rank_unlocks、不碰 cards.json skills），故 status 字段不影响服务端。
- **验证**：客户端 **345/345** + 临时 smoke（32 卡出兵数/三件套字段/lava_hound 裂6火犬/法术 status/电法师多积木，验后删）全过；Go economy 集成测（真 PG）全过（48 卡解析 + 播种 48）；`docker compose build gateway` 编译通过 → 重建 api+gateway + 重启 verifier，**api 日志 `economy config loaded (48 cards, cfg ver=96e05036)`**、DB 账号卡数=48。
- **⚠️ 用户须知**：新卡播为**未解锁** → 用 GM unlock-all（或攒碎片）才进卡组/PvE；api+verifier 已重启加载新配置。**下一步 KAN-86：为 epic+legendary(16 张)填 signature 觉醒到 rank_unlocks**。

---

### V5 卡池扩充 · KAN-86 觉醒填 rank_unlocks（✅ 完成，2026-07-03，独占 master 自主开发）
- **16 张 epic+legendary 填 signature 觉醒**（rank3 marquee + rank2 轻量）：**12 张真觉醒**用现有 ops+三件套表达——
  unit_field 挂 on_hit_status/splash：musketeer 破法弹 · baby_dragon 烈焰吐息(splash 1.5→2.5+减速) · wizard 烈焰风暴 · executioner 行刑领域(splash→3.5) · ice_wizard 凛冬将至(强减速) · princess 烈焰箭雨；
  unit_field death_spawn：golem 崩解(死裂→石心魔像) · lava_hound 熔火降临(火犬→喷火小龙) · phoenix 烈焰重生(重生满配)；
  法术：lightning 雷暴(**set_field 加 stun**) · freeze 绝对零度(num_add damage+200) · skeleton_army 亡骨潮(count_add 14→18)。
  **4 张留 KAN-88**（rank3 stat 占位+note）：heal 战意(需 haste 正向状态) · balloon 临空爆弹(T6 death_aoe) · electro_wizard 连锁闪电(chain) · inferno_dragon 熔核过载(T7 ramp)。
- **`logic/card_progression.gd` +`set_field` op**：直接设某块 field=value（任意类型含嵌套 dict，如给法术块加 status:{kind,dur,mag}）——法术觉醒用。unit_field 已能挂 on_hit_status/splash_radius/death_spawn_unit(dict/值任意)。
- **2 觉醒专用单位**(units.json)：`golemite_body`(石心魔像·只拆塔小坦)、`fire_pup_body`(喷火火犬·空中溅射)。`--from-json`+`--check` 往返一致。
- **验证**：客户端 **353/353**（+8 `test_v5_awakening`：effective_skills 的 unit_field/set_field/num_add 正确 + 运行时余烬火颅溅射变大+减速、雷暴命中眩晕、golem 崩解裂石心魔像、留 KAN-88 占位不改积木）；临时觉醒重放 smoke（rank3 觉醒局 record→PveReplay **逐 hash 全等 pass**，验后删）。
- **服务端无改**：Go `cfg.Cards` 只读 rarity/starter/base_power、忽略 rank_unlocks → 经济/播种不变，**api/gateway 无需重启**；仅 **verifier 已重启**（觉醒经 card_progression.gd 应用，重放需新配置/逻辑）。
- **下一步 KAN-87 probe 平衡**（48 卡+觉醒数值定稿）/ KAN-88 延后件（T6 death_aoe / T7 ramp / chain / haste）。

---

### V5 · 框架地基#2 Events 事件总线（KAN-100，✅ 代码+单测完成待真人验收，2026-07-06）

**做了什么（GDQuest Events 单例模式）**：
- **`view/events.gd`（autoload `Events`）**：首个信号 `economy_changed(cache)`——经济/养成服务器快照更新广播。加新信号原则 = 有真实消费方才加（YAGNI）。
- **发射端收口**：`EconomyStateCache` 快照落地归一到 `_apply`（顺带消掉 refresh 里的重复代码）+ `seed_from_local`，两处尾调 `_emit_changed()`——refresh/领挂机/升级/升阶/解锁/通关发奖/GM 全部自动广播。本类是 RefCounted，经 main_loop root 动态查找总线并判空（offline 单测树/极早期启动安静跳过，对齐 DragScroll 找 UI 方案）。
- **订阅端改造（只接真有页内经济动作的三页）**：base_camp（领挂机）/ card_detail（升级/升阶/解锁）/ settings（GM 8 按钮）——`_ready` 订阅一次，动作 handler 里的手动重刷全删（「加新动作忘刷新」类 bug 机制上绝迹）。**刻意不接** stage_map/card_collection：无页内经济动作，且「缓存已加载不重拉」的入场路径必须保留显式 populate，强行订阅只会双重刷新（YAGNI 实证）。
- **边界铁律**：logic/ 战斗逻辑层禁用总线（lockstep 确定性要求调用顺序严格固定）——`test_events` 源码扫描（`\bEvents\.`）把关；入 CLAUDE.md 架构铁律第 6 条。
- **验证**：`tests/test_events.gd` +5（信号契约 / seed 广播 / _apply 广播（服务器快照 shape fixture）/ 无总线安全 / logic 封禁扫描），全量 **389/389**；headless 冒烟干净。纯客户端，docker 零操作。
- **踩坑（记档纠偏）**：--script 单测模式下 **autoload 其实已挂 root**（F1 时期笔记「autoload 晚于测试加载」不准确——晚的是 _ready 级处理，不是节点挂载）。测试再 add_child 同名节点会被引擎自动改名 → 发射端查到真 autoload、订阅连在孤儿节点上收不到（探针二分实锤）。正解 = get-or-create 复用真 autoload（对齐 test_ui_layers._ui 先例）+ 测完 disconnect；「无总线」用例用临时改名藏 autoload 模拟缺席。
- **真人验收用例（KAN-100）**：E-1 基地领挂机 → 钱包/挂机额即时刷新；E-2 卡详情升级/升阶/解锁 → 数值/按钮态即时刷新（金币扣减可见）；E-3 设置页 GM 任按一个 → 状态行即时更新；E-4 回归：闯关开箱/图鉴排序切换行为不变（未接总线页面）。
- Jira：**KAN-100** 建单挂 Epic KAN-50 → 正在进行 → 代码+单测完成转 **In Review**。缺口 #3 日志 / #4 lint 待做。
（后记：真人验收 E-1~E-4 全过 → **KAN-100 Done**，提交 `283e2cf`；顺带行为级验证 KAN-99 两修复。误入库的 default_bus_layout.tres 已删（`db1f7c5`）。）

---

### V5 · 框架地基#3 Log 日志系统（KAN-101，✅ 代码+单测完成待真人验收，2026-07-06）

**做了什么（抄 Loggie 思路的零依赖薄版，对齐自写 runner 传统）**：
- **`view/log.gd`（`class_name Log` 静态类，刻意非 autoload）**：`Log.d/i/w/e` 四级 + 相对时间戳（`[分:秒.毫秒][级] 内容`）+ 级别门槛（debug 构建全量 / release 构建剥离 d 级）+ w/e 转发 push_warning/push_error（编辑器调试器可见性保留）+ `_sink` 可注入（单测捕获输出；sink 接管后不向引擎转发，免得测试输出冒吓人 ERROR）。**选静态类不选 autoload**：logic/net 的 RefCounted 直调零依赖，绕开 Events 总线踩过的 main_loop 查找舞。
- **收编 60 处裸 print（15 文件）**：view 10 文件 35 处 + net 5 文件 25 处（含 auth/profile 文档注释示例 2 处同步改）。**逐条定级**：失败/掉线/解析异常 →`w`（登录失败/服务器拒绝/WS 断线/pb 解析失败等 14 处）；高频噪声 →`d`（modal 收到点击、PVE 批次上报 ok）；业务里程碑 →`i`（场景流/经济动作/联机事件）。**豁免**：net/proto/（godobuf 生成物，改了会被重新生成覆盖）、tests/tools/addons（harness 输出）；logic 层摸底本就零 print。
- **规约固化**：CLAUDE.md 架构铁律第 7 条「日志走 Log，禁裸 print」+ `test_log` 源码扫描（view/net/logic/ai 全量，豁免 log.gd 本体与 net/proto/）。
- **验证**：`tests/test_log.gd` +4（级别过滤含 release 剥离语义 / w·e 恒过门槛 / 时间戳+级别格式 / 禁裸 print 扫描），全量 **393/393**；headless 冒烟实见新格式 `[00:00.527][I] [V5][menu] …`。纯客户端，docker 零操作。
- **不做**（YAGNI，需要时再开）：文件落盘 sink（桌面版引擎默认已写 user://logs/godot.log；安卓真机要现场日志时再开 `debug/file_logging` 或接 sink）、远程日志上报。
- **真人验收用例（KAN-101）**：L-1 F5 跑一圈常规流程（菜单→基地→闯关一局→养成升级→设置 GM）——输出台日志全部带 `[时:分.毫秒][级]` 前缀、信息与改造前等量不丢；L-2 编辑器 Debugger 的 Errors 面板——登录失败/服务器拒绝类此后以黄色 warning 呈现（w 级转发）；L-3 抽查无「裸」print 残留（无前缀行）。
- Jira：**KAN-101** 建单挂 Epic KAN-50 → 正在进行 → 代码+单测完成转 **In Review**。缺口 #4 lint 工具链待做（最后一块）。
（后记：真人 F5 验收过（时间戳分级/信息不丢/D 级分流正确）→ **KAN-101 Done**，提交 `5f13f79`。编辑器音频面板残留再次生成 default_bus_layout.tres，已删并提醒用户在编辑器里移除 Master 总线上两个禁用效果器。）

---

### V5 · 框架地基#4 lint 工具链（KAN-102，✅ 代码+lint 清零完成待验收，2026-07-06）——四缺口收官

**做了什么（gdtoolkit = 社区事实标准；gdlint 4.5.0 经 uv 走代理，零本地安装负担）**：
- **`gdlintrc` 按房规调校（根目录，取舍全部留痕在文件头注释）**：放行两条既有房规（构造参尾下划线 `config_/deck_` 防遮蔽——V1 起 logic 全用、不动 lockstep 关键构造器；私有 preload `_AuthPb` 前下划线）；`max-line-length` 100→**140**（中文注释信息密度高，100 是英文习惯）；`max-file-lines` 1500（battle_scene 1320/net_battle 1253 巨石已知、防继续膨胀）；`max-returns` 10（logic 校验门禁链/查表函数合法形态）；**禁用 4 条纯 churn 风格规则**（class-definitions-order 405 处存量重排无行为价值 / no-elif-return / no-else-return / max-public-methods 对测试类数据类无意义）；豁免目录 addons(第三方)/net-proto(godobuf 生成物)/.godot。
- **全库 lint 清零**：首跑 2233 处（1807 在 proto 生成物）→ 我方 426 → 配置取舍消化风格类后，**修 36 处真问题**：battle_scene 4 处混用 tab/空格缩进（H1 变换收敛的续行对齐）、card_detail 2 个未用参数加 `_` 前缀、config_loader 4 个局部变量去 `_` 前缀更名（`valid_rarities` 等）、`sprite_db.DB` static var→**const**（只读清单本该是常量）、25 处 >140 字符长行手工换行（签名/格式串参数列拆行，零语义变化）。终态 `gdlint .` = **Success: no problems found**。
- **好消息**：真 bug 类规则（自比较/重复加载/表达式悬空）全库 **0 命中**——vibe coding 的地基没烂。
- **CI 把关**：`.github/workflows/lint.yml`——master 推送/PR 涉及 .gd/gdlintrc 时 ubuntu 跑 `gdlint .`（本地漏跑也兜得住，防规约退化）。
- **gdradon 复杂度基线（巨石拆分立项的量化底数）**：我方代码 787 A / 69 B / 9 C / **1 F = `logic/config_loader._validate` CC=109**（配置交叉校验的线性检查清单，风险低但拆分时优先级参考）；E 级 16 处全在 proto 生成物（不管）。
- **验证**：`gdlint .` 全库绿 + 全量单测 **393/393** 零回归（改动含 logic 签名换行/更名与 sprite_db const 化，编译扫描+全逻辑单测背书）+ headless editor 导入干净。CLAUDE.md 工具链段收录本地命令（gdformat 备而不用：全库重排污染 blame，新文件可单用）。
- **真人验收用例（KAN-102）**：X-1 提交推送后 GitHub → Actions 页看到 `lint` workflow 绿；X-2（可选）本地跑 `uv run --with "gdtoolkit==4.*" gdlint .` 自见 Success。
- Jira：**KAN-102** 建单挂 Epic KAN-50 → 正在进行 → In Review → 提交 `a87383d` 推送后 **CI 首跑 19s 绿（gh 查证）→ Done**。**框架地基四缺口（KAN-99 路由/KAN-100 总线/KAN-101 日志/KAN-102 lint）全线收官**；KAN-99 尚欠联机/探险两条流真人验收（验过转 Done + 顺带可关 KAN-98）。
