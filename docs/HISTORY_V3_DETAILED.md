# HISTORY_V3_DETAILED.md — V3 阶段详细历史归档

> 本文件是 **V3 各步详细开发历史**（新增/修改文件、决策、踩坑与修复、验收记录），从 [HISTORY.md](../HISTORY.md) 拆出归档，避免主 HISTORY 过长拖慢每次会话读取。
> 主 HISTORY.md 保留：快速上手 + 当前进度总览表 + 决策日志 + 当前阶段（V4）逐步。需要回看 V3 具体某步的实现细节、踩坑、单测列表时来这里查。
> V1/V2 详细历史见 [HISTORY_ARCHIVE.md](HISTORY_ARCHIVE.md)。

---

## V3 — 战斗核心 2D 重构 + 买断制单机（已完成）

> 方向见决策日志 36（[HISTORY.md](../HISTORY.md#关键决策记录-decision-log)），权威规划见 [PLAN_V3.md](PLAN_V3.md)。头号工程 **V3-1 = 2D 战斗 reboot**（取代 lane），拆 8 小步（a 场地地形 / b 移动寻路 / c 仇恨 / d 软分离+攻击 / e 塔反击 / f 技能 2D[已并入 b] / g AI 2D / h 显示层 2D）。**策略=推倒重来（决策 37，弃绞杀）**：V3-1b 即删 lane（量纲 1D→2D），AI/view 暂搁置到 V3-1g/h；其余子步仍逐步推进、单测护栏。坐标改抽象 2D tile 空间（CLAUDE.md 硬性 DO-NOT 已相应修订）。

### V3-1a — 场地与地形（新 Arena + Battle.build_arena + 落点合法性，逻辑+单测）  （本次提交）
**前置决策**：见决策日志 36（2D 场地、河+双桥、每方 2 公主 1 王、固定己方半场落点）。本步只做**地形 + 塔占位 + 落点合法性（纯查询）**；单位移动/寻路/tick 见 V3-1b+。

**新增 / 修改**
- `config/arena.json`（新）：场地几何 `default`——网格 `18×32`、河 `y[15,17)`、左右双桥 `x{3,4}&{13,14}`、落点边界（玩家 `y>=17` / 对手 `y<=15`）、双方 6 塔位与占位（王 4×4、公主 3×3；公主 x=4.5/13.5 关于中线 x=9 对称、与桥对齐）。**结构性配置，不进 Excel 镜像**。
- `logic/arena.gd`（新）：2D 场地。tile 类型 `GROUND/WATER/TOWER/OOB`、`tile_type(_at)`、`is_ground_walkable(_at)`、`add_tower_footprint`、`can_deploy(owner,pos)`（地面 + 己方半场）。纯查询、确定性、不用物理引擎。
- `logic/battle.gd`：+`ArenaScript` preload、+`arena` 字段、+`build_arena(level, arena_cfg)`（建 2D 地形 + 6 塔、注册占位，胜负规则沿用）、+`_build_side_towers`。**保留 `build_v2_three_lanes`（与 arena 并存，游戏当前仍跑 lane）**。
- `logic/tower.gd`：+`pos:Vector2`/`fw`/`fh`（加性，lane 阶段不用）。
- `logic/config_loader.gd`：load_all 纳入 `arena.json`、轻校验（default 含 grid/river/deploy/towers）、+`get_arena(id)`。
- `tests/test_arena.gd`（新，10 测）：网格尺寸、河水阻挡、双桥可走、空地可走、越界、塔占位阻挡、6 塔构建、玩家/对手落点半场校验、塔占位拒绝部署。
- `tests/test_config_loader.gd`：+1 测 `test_v3_arena_config_loaded`（arena.json 已加载、default 含必需字段）。

**范围边界**：纯逻辑层 + 配置 + 单测；`view/*`、`ai/*`、`skill_system`、`lane.gd`、`unit.gd` 零改动。游戏运行仍走旧 lane 路径（Match 调 `build_v2_three_lanes`），arena 为新增并存模块、暂未接入对局主流程。

**决策**：见决策日志 36。补充：arena 几何走独立 `arena.json`（结构性、非平衡数值，不进 `build_config.py`/Excel 镜像）；塔占位用 floor 取整 + 半整数公主中心保证左右对称且与桥对齐；`can_deploy` 只管「地面 + 己方半场」，纯法术不受限属上层 `Player` 职责（V3-1f/g 接）。

**踩坑与修复**
- 无。`attack_range` 在 config_loader 仍校验 `0~1`（lane 量纲）——V3-1a 不动 units，故不受影响；2D 量纲转换留 V3-1b/d。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **132/132 全过**（+10 arena +1 config_loader，旧 121 零回归）✅
- `godot --headless --editor --path . --quit` → exit 0、`Arena` 类注册、新 `.uid` 生成、零解析/编译错误 ✅
- 纯逻辑层步骤，正确性由单测覆盖（按纪律无需肉眼验收）✅
- **GUI 视觉验收**：组卡界面外观/交互（点选/移除/满 8 开战）属表现层，留用户实机过目（逻辑+接线已验证，不阻塞）。

### V3-1b — 2D 单位移动 + 流场绕桥寻路（推倒重来：删 lane，逻辑+单测）  （本次提交）
**前置决策**：见决策日志 37（推倒重来、删 lane、`skill_system` 2D 提前、AI 搁置）。

**新增 / 修改（逻辑）**
- `logic/unit.gd`：1D → 2D。移除 `progress/lane_index/get_direction/move_to`，改 `pos:Vector2`；`move_speed`=tile/秒、`attack_range`=tile 距离（量纲改）；+`is_enemy/distance_to`。
- `logic/arena.gd`：+`units`/`towers`/`_flow`；`add_tower`(存引用+占位)、`add_unit`/`get_units`；**流场寻路** `build_flow_fields`/`_bfs_to_tower`（对每塔 BFS 距离场，4 邻、地面可走）；`tick(dt)`=逐单位选最近敌塔(流场距离)→沿梯度走、自动绕到最近桥过河→到 `attack_range+塔半径` 停（攻击留 V3-1d）；安全网不踏水/出界。
- `logic/battle.gd`：删 `lane.gd` preload / `lanes` / `add_lane`/`get_lane` / `build_v1_single_lane` / `build_v2_three_lanes`；`build_arena` 改 `arena.add_tower` + `arena.build_flow_fields`；`step`→`arena.tick`。
- `logic/skill_system.gd`：2D 化（原 V3-1f 提前）。`play_card(card_id, owner, pos:Vector2)`；spawn 在 pos（count>1 确定性散布避免完全重叠）；`direct_damage`=最逼近 pos 的敌方单位；`aoe_damage`=pos 圆心、tile 欧氏半径。
- `logic/player.gd`：`try_play_card(hand_index, pos)`；`_deploy_allowed` 委托 `arena.can_deploy`（地面 + 己方半场）。
- `logic/match.gd`：`setup` 改 `build_arena(level, config.get_arena("default"))`。
- `logic/config_loader.gd`：`attack_range` 校验 `0~1` → `≥0`（tile 量纲、无上限）。

**配置**
- `config/units.json`：`move_speed`(tile/秒)/`attack_range`(tile) 全改 tile 量纲（近战 ~1.0–1.2、archer 4.5、musketeer 5.5；giant 1.1 / goblin 2.6 tile/秒等）。
- `config/cards.json`：3 个 AOE `radius` 改 tile（fireball 1.5→3.0、arrows 0.5→2.5、log 0.4→2.0）。
- `tools/build_config.py`：Excel 列 `move_speed_lane_per_s`→`move_speed_tiles_per_s`、`attack_range_lane_ratio`→`attack_range_tiles`，去 0~1 校验（改 ≥0、attack_range 用 float）。`GameConfig.xlsx` 经 `--from-json` 重建、`--check` 通过。

**删除**
- `logic/lane.gd`（+uid）；`tests/test_lane.gd`、`tests/test_battle_v2.gd`（lane 拓扑）、`tests/test_ai_controller.gd`（AI 搁置，V3-1g 加回）（+uids）。

**测试（重写 + 新增）**
- 重写 `test_unit`（2D 位置/血量/冷却）、`test_battle`（arena 胜负——直接削塔验规则，单位攻击塔留 V3-1d）、`test_skill_system`（2D spawn/aoe/direct）、`test_match`（出牌→arena 单位 y 减小推进）、`test_player`（2D 落点半场/地面校验）。
- `test_arena` +3 移动测试：地面兵绕桥过河**全程不踏水**、到敌塔停下、对手兵对称反向过河。

**范围边界 / 现状**：游戏**暂无可玩画面**——`view/*` 与 `ai/ai_controller.gd` 仍引用旧 API（运行时坏、解析通过），分别留 V3-1h（显示层 2D）/ V3-1g（AI 2D）重写。本步正确性由 headless 单测覆盖。

**踩坑与修复**
- GDScript 类型推断：遍历无类型 const `_NEIGHBORS`（Vector2i）与无类型 `unit` 参数 → `:=` 推断失败；给循环变量标 `for off: Vector2i`、距离/坐标用显式 `var d: float`/`var min_y: float` 等。
- `build_config.py` 自带 `attack_range 0~1` 校验阻断 `--check` → 同步去除 + 列改 tile 语义。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **101/101 全过**（删 3 测试文件共 33 测；重写若干 + 新增 arena 移动测；预检 res://logic 编译通过）✅
- `godot --headless --editor --path . --quit` → exit 0：`view/*`、`ai_controller` 解析通过（仅运行时坏，符合预期）、`.uid` 重生 ✅
- `build_config.py --from-json` + `--check` → `config check ok`（量纲列改名后往返一致）✅
- 流场寻路（单测断言）：地面兵从 (4,20) 自动绕左桥过河、全程不踏水、停在敌方左公主塔攻击距离内；对手兵对称反向过河 ✅
- 逻辑层步骤，正确性由单测覆盖（按纪律无需肉眼验收；2D 画面验收在 V3-1h）。

### V3-1c — 目标获取 + 完整 CR 仇恨/分心（逻辑+单测）  （本次提交）
**前置决策**：见决策日志 36（仇恨=完整 CR 式：默认锁最近敌塔、敌方单位进 `aggro_radius` 转火、可拉扯/风筝、目标死/离开回锁）。

**新增 / 修改**
- `logic/unit.gd`：+`aggro_radius`（tile，配置读）+ `current_target`（运行时索敌目标，Unit 或 Tower；攻击/显示用）。
- `logic/arena.gd`：`tick` 加索敌层——`_nearest_enemy_unit_in_aggro`（aggro_radius 内最近存活敌兵）；有则 `current_target`=该兵 + 直线趋向（`_step_toward_point`，到 attack_range 停）；否则默认锁最近敌塔（流场绕桥，沿用 V3-1b）。**每 tick 重选** → 目标死/离开自动回锁。确定性 tie-break = units 顺序。
- `config/units.json`：每单位 +`aggro_radius`（近战 5.0 / 远程·空军 5.5）。
- `tools/build_config.py`：`UNIT_HEADERS` + 读/写 +`aggro_radius_tiles` 列；`GameConfig.xlsx` 经 `--from-json` 重建、`--check` 通过。
- `tests/test_arena.gd`：+6 仇恨测试（默认锁塔 / 进半径分心 / 半径外忽略 / 目标死回锁 / 侧边拉扯追击 / 选最近敌兵）。

**范围边界**：仅 logic + config + 单测。**索敌只决定「打谁/走向谁」，单位还不会真正掉血**（接敌攻击 = V3-1d）。分心目标的「只攻建筑」型单位（巨人式 `targets_only_buildings`）按 PLAN_V3 §5 待细化**暂不引入**（当前所有兵都会被分心；该行为在 d/e 接入攻击/塔火前不可观测，故推迟到 V3-1d/e 或 V3-3 再定）。AI/view 仍搁置（V3-1g/h）。

**踩坑与修复**
- 无新坑。沿用 V3-1b 类型标注经验（无类型 `unit` 参数 → `var r/d: float`、`unit.pos as Vector2`）。新增 unit 字段 `aggro_radius` 必须同步进 Excel 管线（否则 `--check` 失败）。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **107/107 全过**（+6 aggro，旧 101 零回归）✅
- `build_config.py --from-json` + `--check` → `config check ok`（+aggro 列往返一致）✅
- 仇恨行为由单测覆盖：默认锁塔 / 进 aggro 转火 / 半径外忽略 / 目标死回锁 / 侧边拉扯追击(距离缩小) / 选最近敌兵 ✅

### V3-1d — 软推挤碰撞 + 接敌攻击（逻辑+单测）  （commit `816968a`）
**前置决策**：见决策日志 36（碰撞=软推挤：体积半径 + 确定性分离，不用物理引擎）。

**新增 / 修改**
- `logic/unit.gd`：+`body_radius`（tile，配置读）。
- `logic/arena.gd`：`tick` 重构为 5 段——①冷却 ②索敌+移动(到射程停) ③**软推挤分离** `_separate`（固定 i<j 序、2 趟、沿连心线各推半个重叠、完全重叠确定性兜底、推后不进水/塔/出界）④**攻击结算** `_in_attack_range` + 收集后统一 `take_damage`（首击免费沿用 `can_attack`；目标可为 Unit 或 Tower——**单位现在能削塔**，王塔归零经 `Battle._check_victory` 判胜负）⑤清死。统一 `_acquire_target`/`_move_toward`/`_in_attack_range`（`target is Tower` 区分流场 vs 直线、塔目标加塔半径）。删旧 `_reached_tower`。
- `config/units.json`：每单位 +`body_radius`（群兵 0.35 / 普通 0.45–0.55 / 巨人 0.8 / 小龙 0.7）。
- `tools/build_config.py`：+`body_radius_tiles` 列（读/写）；Excel `--from-json` + `--check` 通过。
- `tests/test_arena.gd`：+4 测（重叠被推开≈体积和、攻击敌兵首击 -50、攻击敌塔总塔血下降、双方同 tick 互伤）。

**范围边界**：仅 logic + config + 单测。**塔本身还不会主动反击**（=V3-1e）；塔被单位摧毁后**流场暂不重算**（`rebuild_flow_fields` 已备、V3-1e 接通；当前死塔退出索敌、单位改打活塔、路径绕过死塔占位，正确但非最优）。巨人「只攻建筑」仍按 §5 暂缓。AI/view 仍搁置（V3-1g/h）。

**踩坑与修复**
- 无新坑。`target is Tower`（全局 class_name）区分塔/兵目标、免类型耦合；分离与攻击均确定性（固定序、收集后统一应用）。新增 `body_radius` 同步进 Excel 管线（否则 `--check` 失败）。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **111/111 全过**（+4，旧 107 零回归）✅
- `build_config.py --from-json` + `--check` → `config check ok` ✅
- 战斗链路由单测覆盖：重叠被推开 / 接敌首击掉血 / 单位削塔 / 双方同 tick 互伤 ✅

### V3-1e — 塔会反击 + 塔毁流场重算（逻辑+单测）  （commit `816968a`）
**前置决策**：见决策日志 36（塔反击是 CR 防御核心）。
**新增 / 修改**
- `logic/tower.gd`：+`damage`/`attack_range`/`attack_speed` + 冷却（`tick_cooldown`/`can_attack`/`mark_attacked`，与 Unit 同口径）。
- `logic/arena.gd`：`tick` +塔冷却推进 + **塔攻击**（射程内最近敌方单位、收集后统一结算）；塔被摧毁 → `_rebuild_tower_rects`（死塔占位释放为地面）+ `build_flow_fields`（跳死塔，一次性触发）。+`_nearest_enemy_unit_to_tower`。
- `config/arena.json`：+`tower_combat`（king/princess 各 damage/attack_range/attack_speed；结构性、不进 Excel）。
- `logic/battle.gd`：`build_arena` 读 `tower_combat` 设塔战斗数值（`_build_side_towers` 加 combat 参）。
- `tests/test_arena.gd`：+3（塔打射程内敌兵 / 不打己方·射程外 / 塔毁占位释放重算）；移动测试改高血量（扛塔火走完全程）、两单位互攻测试移到中场无塔火区（y17）。
**验收**：单测 **114/114**；`config check ok`。塔反击/塔毁重算由单测覆盖。

### V3-1f — SkillSystem 2D 化  （已于 V3-1b 完成）
推倒重来删 lane 时 `skill_system` 被迫一并 2D 化（决策 37），本槽空出，无独立改动。

### V3-1g — AIController 2D 重写（逻辑+单测）  （commit `816968a`）
**前置决策**：见决策日志 33（攻防结合 + 按向选 + 难度分级）2D 化。
**新增 / 修改**
- `ai/ai_controller.gd`：从死代码重写为 2D。难度表 `DIFF`(threshold/cooldown/defends/smart) 沿用；`_decide` 防守优先（`_most_threatening_player_unit`：玩家单位 `y<=THREAT_LINE` 越河威胁 → 在其 x 处 `clampf(y,10,14)` 空投最贵兵）→ 否则 `_attack`（最贵可用兵 → `_attack_pos`：智能档集火 `_weakest_player_tower` 的 x 侧、easy 固定中路 x=9；法术落 `_lead_player_unit_pos`）。经 `opponent.try_play_card(idx, pos)`，确定性无随机。
- `tests/test_ai_controller.gd`（重新加回，7 测）：难度解析(关卡/覆盖)、阈值门控、出最贵兵入场、冷却、easy 阈值高于 hard、受威胁防守空投(投在威胁 x 附近)、集火最弱塔侧(x≈最弱塔)。
**验收**：单测 **121/121**（+7）。

### V3-1h — 显示层 2D 接通（仅 view，真人实机验收）  （commit `816968a`）
**前置决策**：见决策日志 36/37（2D 场地、tap 落点）。
**新增 / 修改**
- `view/battle_scene.gd`：**整体重写为 2D**。tile↔屏幕映射（`_t2s`/`_s2t`/`_field_rect`）；`_draw` 画地形（地面/河/双桥 + 己方半场部署区提示）+ 6 塔（按 owner 色/血条变色/王塔标记/摧毁灰块）+ 自由移动单位（队伍色圆 + 空军白环 + 血条）+ 顶栏（王冠/倒计时）+ 圣水条；手牌 `Button`×4（费用/置灰/选中高亮）；结算面板（WIN/LOSE/DRAW + 比分 + REMATCH/MENU）。两段式出牌：点卡选中 → 点己方半场落点 `player.try_play_card(_s2t(click))`；对手由 `AIController` 自驱（`set_opponent_controller`）。读 `GameState.level_id`/`player_deck`。
**范围边界**：仅 view（+本批其它子步的逻辑）。lane 时代 FX（投射物/受击闪白/爆点/塔碎块等）**未移植**，留 V3-4/V3-7 随美术重做。
**验收**
- `godot --headless --editor --path . --quit` → exit 0，`battle_scene.gd` 无解析错误、`.uid` 重生 ✅
- `timeout 6 godot --headless --path . res://view/battle_scene.tscn` → 6s 实跑（`_ready`→`_process`(match.update→AI→arena.tick)→`_draw`）**零运行期错误** ✅
- 单测仍 **121/121**（逻辑零回归）✅
- **画面/手感留真人实机验收**：这是 2D 重构后**首次可玩**——菜单→选关→组卡→对局，应能在己方半场任意点出兵、看兵绕桥推进/转火/挤压/塔互射、拆塔分胜负。验收清单见下。

> **V3-1（2D 战斗核心 reboot）收官**：a 场地 → b 移动寻路 → c 仇恨/分心 → d 软分离+攻击 → e 塔反击 → f(并入 b) → g AI 2D → h 显示层 2D。lane 模型已彻底移除。单测 **121/121**。下一步 **V3-2 空军（飞兵越河 + 对空克制）**。

**V3-1h 真人实机验收清单（交用户）**：在编辑器运行（主场景 main_menu）→ 选关 → 组卡(默认即可) → 对局，确认：① 场地能看出河 + 左右双桥 + 双方各 3 塔；② 己方半场任意点能出兵、越界/水/塔上不能出；③ 地面兵自动**绕到桥**过河、不走水；④ 兵接敌会**转火打架**、能互相**挤开/堵路**；⑤ 兵靠近敌塔时**塔会开火**反击；⑥ 拆掉王塔/超时比塔血能正常**分胜负**并弹结算（REMATCH/MENU 可用）。回报「通过/哪条不对」。

---

## V3-2 — 空军：飞兵越河 + 对空克制（逻辑+config+view+单测）  （commit `7ad503d`）
**前置决策**：见决策日志 36（首版先全地面、空军作为 V3-2 紧随）。

**新增 / 修改**
- `logic/unit.gd`：+`attack_targets`(ground/air/both) + `is_flying()`(派生自 `target_type=="air"`，不加冗余字段) + `can_hit_type(t)`。
- `logic/arena.gd`：①索敌按 `can_hit_type` 过滤——纯地面兵**不锁/不打**空军（也不被其分心）；②飞行单位 `_step_fly` **直线越河、忽略地形**（只挡出界）；③软分离**仅同层**（空/地不同层互不挤）、`_apply_push` 飞行可越水/塔。**塔不按类型过滤**（towers 命中空地皆可 = 对空安全网，CR 口径）。
- `config/units.json`：每单位 +`attack_targets`（近战/giant=ground；archer/musketeer/minion/baby_dragon=both）。
- `tools/build_config.py`：+`attack_targets` 列（`ATTACK_TARGETS` 枚举 + 校验 + Units 表下拉）；`GameConfig.xlsx` 同步。
- `view/battle_scene.gd`：飞兵画在上层（单位上浮 + 地面投影），辨识空/地。
- `tests/test_arena.gd`：+5（飞兵直线越水过河 / 纯地面打不到空军 / 对空兵(both)命中空军 / 塔对空 / 空地不互挤）。

**范围边界**：仅 logic + config + view + 单测。巨人「只攻建筑」(`targets_only_buildings`) 仍按 §5 暂缓。`is_flying` 由 `target_type` 派生（不引入冗余配置）。飞兵「按 ground 流场距离选目标」是小近似（飞行移动已直线，目标选择沿用流场最近，足够；如需精确改欧氏留后续）。

**踩坑与修复**
- 无逻辑坑。两处 GDScript 类型推断（`var flying: bool`、测试里塔火干扰）按既有经验处理；对空测试单位需放「双方塔火射程外」的中场(y17 一带)纯测单位互攻。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **126/126 全过**（+5）✅
- `godot --headless --editor --path . --quit` → exit 0、无解析错误 ✅
- `timeout 6 godot --headless --path . res://view/battle_scene.tscn` → 6s 实跑零运行期错误 ✅
- `build_config.py --from-json` + `--check` → `config check ok`（+attack_targets 列往返一致）✅
- 对空克制由单测覆盖：飞兵越水 / 地面无法对空 / 对空兵与塔可打空 / 空地不互挤。表现层（飞兵上浮显示）留真人验收。

---

## V3-3 — 新技能积木：亡语召唤 + 治疗术（逻辑+config+单测）  （commit `73f99c1`）
**前置决策**：PLAN_V3 §3/§5（2–3 个新积木择优）。选**接入最干净、价值最高**的两个；slow/stun（需状态系统）、knockback（需新列）、建筑（需生成计时）留后续。

**新增 / 修改**
- **亡语召唤 `on_death_spawn`**（单位行为）：`unit` +`death_spawn_id`/`death_spawn_count`/`death_spawn_config`（config 模板由 `SkillSystem` 生成时注入 → `Arena` 死亡处理无需依赖 ConfigLoader）；`arena._remove_dead` 死亡时在原地裂出 N 个（确定性散布、append 后下 tick 生效）。新单位 `golem_body`（坦克 hp3000，死后裂 2× `goblin_body`）+ 卡 `golem`(费7)。
- **治疗术 `aoe_heal`**（法术块）：`unit` +`heal()`（仅活体、不超 max）；`skill_system` +`_aoe_heal`（治范围内**友军**，复用 `damage` 字段为治疗量）；卡 `heal`(费3, r3/150)。
- `logic/config_loader.gd`：+`death_spawn_unit` 交叉引用校验。
- `tools/build_config.py`：`SKILL_TYPES` +`aoe_heal`（复用 radius/damage 列，写侧通用无需改）；`UNIT_HEADERS` +`death_spawn_unit`/`death_spawn_count`（可选列，仅填了才写入 JSON）；Excel 同步。
- `config/units.json` +`golem_body`；`config/cards.json` +`golem`/+`heal` → **16 卡 / 10 单位**。
- `tests`：`test_skill_system` +2（治友不治敌 / 治疗封顶）；`test_arena` +1（石头人亡语死裂 2 哥布林，经真 `golem` 卡 + skill_system 端到端）。

**范围边界**：仍走数据驱动积木、与现有积木可叠。巨人「只攻建筑」仍按 §5 暂缓。view 未为 `golem`/`heal` 专门换形（golem 用默认圆，heal 无专属 FX）——美术/FX 留 V3-4/V3-7。`is_flying`/`death_spawn` 量纲与列均经 Excel 往返校验。

**踩坑与修复**
- 无逻辑坑。`aoe_heal` 复用 `damage` 列（=治疗量），写侧 CardSkills 是通用列映射故零改；`death_spawn` 用「仅非空才写 JSON」保 Excel↔JSON 往返一致（多数单位无此键）。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **129/129 全过**（+3）✅
- `build_config.py --from-json` + `--check` → `config check ok`（+aoe_heal / +death_spawn 两列往返一致）✅
- 新积木由单测覆盖：亡语裂兵 / 治友不治敌 / 治疗封顶。

---

## V3-4 — Roguelite 主轴（已完成）

> 方向见决策日志 36，权威规划见 [PLAN_V3.md](PLAN_V3.md) §3。拆 4 小步：a run 状态+节点地图+连战链 / b draft 三选一 / c relic / d boss+meta+存档。逻辑+单测为主、配最简 view。

### V3-4a — Roguelite 骨架：RunState + 节点地图 + 连战流转（逻辑+config+单测）  （commit `9a6fc55`）
**前置决策**：见决策日志 38（线性连战链 / 二元永久死亡 / 3 act × 3 战；遭遇引用现有 level；起始卡组用 deck_builder 选的卡组）。

**新增**
- `config/run.json`（新，结构性、**不进 Excel 镜像**——比照 `arena.json`）：`default` run = `starter_deck`(8) + `acts`(3)×`nodes`(3)；每节点 `{type: battle/elite/boss, level_id}`，引用现有 `levels.json` 关卡（act 末为 boss；当前仅 4 关复用，富遭遇池留内容步）。
- `logic/run_map.gd`（`RunMap`）：把 `run.json` 的 acts 结构**展开成扁平节点链** `nodes`（每项 `{type, level_id, act, index_in_act}`）；`size()`/`node_at(i)`（越界返空）。纯数据、确定性。
- `logic/run_state.gd`（`RunState`）：run 可变状态——`deck`(run 工作卡组，draft V3-4b 改写) / `map`(RunMap) / `cursor` / `status`(ONGOING/WON/LOST) / `wins` / `seed`(预留) / `relics`(预留 V3-4c)。`advance(battle_result)` 流转：仅 `RESULT_PLAYER_WIN` 推进（走完末节点 → WON），`OPPONENT_WIN`/`DRAW` → LOST（永久死亡），`ONGOING` → no-op。`current_node()`/`is_over()`。`_init` 对传入卡组 `duplicate()`（不回写配置）。

**修改**
- `logic/config_loader.gd`：`load_all` 纳入 `run.json` → `run` 字段；`_validate` 加 run 校验（default 含非空 acts；节点 `type` 合法、`level_id` 必须在 levels 中；`starter_deck` 卡必须在 cards 中）；+`get_run(id="default")`。
- `tests/test_config_loader.gd`：+1（`test_v3_run_config_loaded`：run 已加载、default 含 starter_deck(8)+acts(3)、交叉引用无错）。

**测试（新增）**
- `tests/test_run_map.gd`（4）：acts 展开成 9 节点链 / 节点带 type+act 标签(act 末为 boss) / 越界返空 / 所有节点 level 存在。
- `tests/test_run_state.gd`（10）：初态 / 卡组是独立副本 / 胜推进 / 9 连胜→通关(且通关后 advance 无副作用) / 对手胜→永久死亡 / **平局→永久死亡** / ONGOING→no-op / 中途败北止步保留胜场 / **headless 全胜跑通一条 run（真 `Match` 逐节点建场跑 tick + 强制结果喂回 advance → RUN_WON）** / headless 首战败北→RUN_LOST 不推进。

**范围边界 / 现状**：仅 logic + config + 单测。**菜单→run→对局→下一节点的 view 接入不在 4a**（4a 验收 = 单测 + headless 跑通；最简 view 留后续小步）。draft（改写 run 卡组）= V3-4b；relic = V3-4c；boss/精英差异化 + meta + 存档 = V3-4d（4a 仅给节点打 `type` 标签备用）。

**踩坑与修复**
- 无逻辑坑。`config_loader.gd` 内 `_validate` 缩进为 Tab，编辑时按既有 Tab 缩进对齐。run.json 结构性、不入 Excel，故 `build_config.py` 零改、`--check` 不涉及。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **144/144 全过**（+15：RunMap 4 + RunState 10 + ConfigLoader 1；旧 129 零回归），exit 0 ✅
- `godot --headless --editor --path . --quit` → `RunMap`/`RunState` 类注册、`.uid` 生成、零解析错误 ✅
- `build_config.py --check` → `config check ok`（未动 units/cards/levels，Excel 无漂移）✅
- run 推进 / 胜负流转 / 连战链 / headless 跑通一条 run（全胜→通关、首败→失败）均由单测覆盖。纯逻辑步骤，按纪律无需肉眼验收。

### V3-4b — 战间 draft 三选一（逻辑+单测）  （commit `239012b`）
**前置决策**：见决策日志 39（确定性候选、追加进 run 卡组、卡组可增长、可 SKIP）。
**新增 / 修改**
- `logic/run_rewards.gd`（`RunRewards`，新）：`offer_cards`/`offer_relics`——从池中剔除已持有、seeded Fisher-Yates 确定性取 N（同 seed 同结果，零随机副作用）。
- `logic/run_state.gd`：+`add_card`（追加进 run 卡组、去重）/`add_relic`（去重）。
- `logic/deck.gd`：放宽 `setup` 为 ≥`HAND_SIZE`+1（不再硬限 8），支持 draft 后卡组增长；标准对局仍 8。
- `tests`：`test_run_rewards`(6)、`test_deck`+1（10 张增长卡组循环不变量）、`test_run_state`+3（加卡增长去重 / 加 relic 去重 / **draft 卡带入下一场 Match**）。

### V3-4c — relic 系统：JSON 数值修正器（逻辑+config+单测）  （commit `239012b`）
**前置决策**：见决策日志 39（effective level 深拷贝、不污染 base、起手圣水、单位级 relic 留后续）。
**新增 / 修改**
- `logic/run_modifiers.gd`（`RunModifiers`，新）：`effective_level(base, mod_sources)`——深拷贝后顺序叠加 `val=val*mult+add`（圣水回速/上限/起手、时长、王/公主塔血），**base 不变**；`relic_mods`（relic id→mods 数组）；`node_mod`（节点难度修正查表）。
- `config/relics.json`（新，结构性、不进 Excel）：7 个 relic（含 2 个 `unlock` 门控）。
- `logic/match.gd`：`setup` +`modifiers` 形参（经 `effective_level` 作用，空=行为同前）；起手圣水 `elixir_start` 经 `Elixir` 第三参注入（`_make_player` +`estart`）。
- `logic/config_loader.gd`：载入 `relics.json` + 校验（每 relic 含 mods 对象）+ `get_relic`。
- `tests`：`test_run_modifiers`(7)、`test_match`+1（修正器抬塔血/起手圣水且不污染 base）、`test_config_loader`+1（relics 加载）。

### V3-4d — boss/精英 + 局间 meta 解锁 + 存档 + 最简 run view（逻辑+config+view+单测）  （commit `239012b`）
**前置决策**：见决策日志 39（节点难度走同一修正器引擎、meta 门控解锁 relic、user:// 往返、view 最简）。
**新增 / 修改（逻辑+config）**
- `logic/meta_progress.gd`（`MetaProgress`，新）：局间统计（runs_started/won、bosses_defeated）+ `available_relics`/`unlocked_ids`（按 relic 的 `unlock:{stat:阈值}` 解算）+ `load_dict`/`to_dict`。
- `logic/save_system.gd`（`SaveSystem`，新）：`user://` 存读 meta（持久）+ run（可续跑，地图由 config 重建后 `load_dict` 恢复进度）；路径可注入（单测用临时档）。
- `logic/run_state.gd`：+`to_dict`/`load_dict`（序列化，不引用自身 class_name）。
- `config/run.json`：+`node_modifiers`（elite/boss 抬塔血）。
- `tests`：`test_meta_progress`(5)、`test_save_system`(4)、`test_run_modifiers`+1（node_mod）、`test_run_state`+1（to/load_dict 往返）。
**新增 / 修改（view，最简可玩）**
- `view/run_scene.gd`+`.tscn`（新）：run 节点链中枢——画连战链(完成/当前/boss 标记)+run 卡组/relic 摘要；处理回传战斗结果(推进/记 boss/给奖励/结算+存盘)；FIGHT→battle、奖励三选一覆盖层(卡/relic)、结算覆盖层(通关/败北+解锁展示)、NEW RUN/MENU。
- `view/battle_scene.gd`：run 模式——读 `GameState.run` 当前节点 level_id+run 卡组+relic/节点修正建场；结算改 CONTINUE 回 run 中枢（写 `run_last_result`）。
- `view/game_state.gd`：+`run`/`run_last_result`/`meta` 静态变量（run 模式握手）。
- `view/main_menu.gd`：+ROGUELITE 入口（→ run_scene，续档/新开）。

**范围边界 / 现状**：4b/c/d 一批完成。单位级 relic、分叉地图、富遭遇池、deck-builder 选 run 起始卡组、UI 美术/FX 均留后续。view 为白膜最简，**run 引擎内流程/手感交真人验收**。

**踩坑与修复**
- 新类 `static from_dict` 引用自身 `class_name`：.uid/全局注册前被 test runner 预检判失败 → 改实例方法 `load_dict`（不引用自身 class_name）。
- headless smoke：`--script` 的 `_initialize` 期 `add_child` 不触发 `_ready` → 须显式调 `_ready()`（非代码 bug）；杀进程残留 `user://` 半档会污染下次 smoke → smoke 前清档。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **172/172 全过**（+28：rewards 6 + modifiers 8 + meta 5 + save 4 + deck 1 + run_state 4 + config 1 + match 1；旧 144 零回归），exit 0 ✅
- `godot --headless --editor --path . --quit` → exit 0、新类注册、`.uid` 生成、零解析错误 ✅
- `build_config.py --check` → `config check ok`（relics.json/run.json 结构性、未动 Excel 镜像）✅
- headless smoke（显式 `_ready()`）：run 中枢建 9 节点/8 卡 run；battle run 模式用节点 level+run 卡组建场（boss 节点王塔 2600×1.5=3900 ✓）；胜后回中枢推进+给奖励（普通→卡 draft 3 选 1；boss→记 boss+relic 奖励，含解锁的 giants_blood）✓。
- **run 引擎内完整流程/手感留真人实机验收**（清单见下）。

**V3-4 真人实机验收清单（交用户）**：编辑器运行主场景 → 主菜单点 **ROGUELITE**，确认：
1. 进入 run 中枢，看到 **9 个节点的连战链**（Act 1/2/3，每 act 末 BOSS 红标）、当前节点高亮、底部显示 **run 卡组(8)** 与 **RELICS (none)**；
2. 点 **FIGHT** 进战斗，确认用的是 run 卡组、能正常打（绕桥/转火/塔互射/拆塔）；
3. 战斗结束点 **CONTINUE** 回中枢：**胜** → 普通节点弹 **DRAFT A CARD 三选一**，选 1 张后回中枢、卡组 +1、当前节点推进；**败/平** → 弹 **RUN OVER** 结算 → BACK TO MENU；
4. 打到 **BOSS/ELITE 节点**：该战更硬（塔血更高），**胜后弹 CHOOSE A RELIC 三选一**，选 1 个后中枢 RELICS 出现该 relic，且后续战斗能感到 relic 生效（如起手圣水/塔更肉/回速更快）；
5. 连胜通关最后 BOSS → 弹 **RUN CLEARED** + 统计（Runs won / Bosses beaten）+ 若达成则显示 **Unlocked: …**；
6. 中途点 **MENU** 离开再进 ROGUELITE → 能**续上同一条 run**（存档）；点 **NEW RUN** → 重开一条新 run；通关/败北后回菜单再进 → 开新 run（旧档已清）。
回报「通过/哪条不对」。

---

## V3-6 — 交互与游戏手感（已完成代码，部分留真人验收）

> 方向见 PLAN_V3 §3，范围/拆步见决策日志 41。纯显示层（零逻辑改，决策 30 路线 A），拆 4 个真人验收 gate：6a 部署交互 → 6b 战斗 juice → 6c 圣水/HUD → 6d 胜负/run 总结。全部在白膜上装「手感系统」，V3-7 再贴精灵皮。

### V3-6a — 拖拽部署 + 落点反馈（仅 view）  （commit `1999797`）
**前置决策**：见决策日志 41（拖拽部署 CR 式、纯显示层）。

**修改（仅 `view/battle_scene.gd`，零逻辑改）**
- **拖拽部署**取代两段式 tap：手牌 `Button` 由 `pressed` 改 `button_down`(开始拖)/`button_up`(松手落子)；拖拽中每帧读 `get_viewport().get_mouse_position()`。落点经 `_drop_tile_from` **抬到手指上方** `DROP_LIFT_TILES=1.6` tile（拇指不遮挡）。松手在 HUD/顶栏 → 取消；在场上 → `player.try_play_card(sc, drop_tile)`（出牌路径不变、玩家/AI 仍对称）。出不起的牌 `disabled` → `button_down` 不触发，**拖不动**。
- **落点 ghost**（`_draw_drag_ghost`，仅拖拽中）：`_card_info` 解析卡 `skills` 判类型——spawn→画 `count` 个兵剪影（半径取 `UNIT_VIS`、确定性环形散布）；`aoe_damage/aoe_heal`→画 AOE 半径圈；`direct_damage`→画准星。**合法绿/非法红**：spawn 用 `arena.can_deploy(0, drop_tile)`（与逻辑同一校验，所见即所得）、法术恒绿（不受半场限，沿用决策 26）。
- **己方半场高亮**（`_draw_deploy_hint`）：仅拖兵牌时，部署区叠加绿色脉动（`sin(_elapsed*6)`）。
- **落地涟漪**（`_fx` 列表 + `_draw_fx`/`_cull_fx`）：成功落子在落点压一条扩散淡出环（`POOF_DUR=0.40s`）。
- **入场缩放**（`_seen: instance_id→首见时刻` + `_pop_scale`）：新单位半径从 0.35 ease-out 弹到 1.0（`POP_DUR=0.22s`），AI 兵同享；每帧剔除已死 id。
- **卡牌抬起**：拖拽中源卡上移 14px + 金色高亮（`_card_base_pos` 存基位）。
- 顺带补 `UNIT_VIS["golem_body"]`（V3-3 遗漏，原为默认 0.5 圈）。

**范围边界**：仅 view，逻辑/config/单测零改。受击数字/插值/顿帧/震屏在 6b；分段圣水/冷却扫光在 6c；胜负演出在 6d。FX 全程序化白膜（无外部素材），V3-7 贴皮。

**踩坑与修复**
- `var id := u.get_instance_id()`：无类型 `u`（遍历无类型数组）→ 类型推断失败（沿用既有 GDScript 坑）。改 `var id: int = ...`。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn --quit-after 300` → 改后零脚本/运行期错误（退出期 ObjectDB/resource leak 警告为 `--quit-after` 强退的善性 teardown，非本步代码）✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **真人实机验收：7/7 全过（2026-06-16）** ——拖拽落子 + ghost 数量/抬起 + 红绿合法性 + 半场脉动 + 法术 AOE 圈/准星(敌方半场也可) + 置灰拖不动/卡抬起 + HUD/非法取消 + 涟漪/入场缩放 + 胜负结算，均通过。✅

**V3-6a 真人实机验收清单（已通过，留作回归基线）**：F5 运行（编辑器已开，Play 读盘最新脚本）→ ROGUELITE/任意关进战斗，确认：① 按兵牌拖到场上有**兵剪影 ghost**（数量正确、抬在手指上方），松手落子；② ghost/落点环 **己方半场地面=绿、敌方半场/水/塔=红**，拖兵牌时己方半场**脉动高亮**；③ 法术：火球/箭/滚木拖出 **AOE 圈**、电击/闪电出**准星**，且**敌方半场也绿**（可放）；④ 出不起的牌**置灰拖不动**，拖动的卡**抬起高亮**；⑤ 松手在 HUD/非法处=**取消**（不扣圣水不出兵）；⑥ 成功落子有**涟漪**、新兵（含 AI 兵）**弹入**；⑦ 胜负结算/CONTINUE 仍正常。回报「通过/哪条不对」。

### V3-6b — 战斗 juice：插值 + 受击反馈 + 顿帧 + 震屏（仅 view）  （commit `8a09953`）
**前置决策**：见决策日志 41（纯显示层、逐帧 diff 逻辑状态派生反馈 = 决策 30 路线 A）。

**修改（仅 `view/battle_scene.gd`，零逻辑改）**
- **移动插值（10Hz→60fps）**：`_disp: id→显示位`，每帧 `lerp(u.pos, 1-exp(-SMOOTH_K·dt))` 指数平滑（`SMOOTH_K=18`），单位按 `_disp_pos` 作画 → 10Hz 逻辑步进显示层丝滑（合架构铁律「显示层做插值」）。新兵首见以逻辑位初始化（仍配 6a 入场缩放）。
- **逐帧 diff 事件**（`_detect_events`）：比对单位/塔 `hp` 与上帧（`_uhp`/`_thp`）——降→受击（数字+闪白+火花，按阈值触发顿帧/震屏）、升→治疗（绿 `+N`，复用治疗术效果）、塔从存活→摧毁→塔毁演出。不读逻辑内部事件、纯状态差分。
- **受击闪白**（`_flash: id→结束时刻`）：命中后 `FLASH_DUR=0.12s` 内单位/塔填充色向白 lerp（≤0.85）。
- **浮动伤害数字**（`_dmgnums`）：命中处上浮淡出（`DMGNUM_DUR=0.75s`、升 34px）；普通白、≥`HITSTOP_DMG` 金色大号、治疗绿 `+`。坐标用 tile（经 `_t2s` 随场抖动）。
- **命中顿帧**（`_hitstop_t`）：单次伤害 ≥`HITSTOP_DMG=200`（法术/重击/塔毁）→ 冻结 sim `HITSTOP_DUR=0.06s`（`_process` 跳过 `match.update`、画面继续；累加器自然追帧、不丢 tick）。
- **震屏**（`_shake`/`_shake_mag`）：经 `_t2s` 加 `_shake` 偏移 → **只抖场内（地形/塔/兵/FX），HUD 不抖**（顶栏/圣水绝对坐标、卡牌/结算为 Control 子节点）；`_s2t` 不含抖动 → 落点输入不受影响。幅度分级（命中 3 / 大伤 6 / 塔毁 12，上限 14），`SHAKE_DECAY=42/s` 衰减。
- **命中火花**（`_sparks`）：命中处径向短线爆裂淡出（`SPARK_DUR=0.18s`，白膜占位）。
- 瞬时表（`_fx`/`_dmgnums`/`_sparks`）统一 `_cull_transients`/`_cull_list` 按时长回收；单位级 `_disp`/`_uhp`/`_seen` 随死亡剔除；`_flash` 按时回收。

**范围边界**：仅 view，逻辑/config/单测零改。攻击命中 FX 为白膜径向线（V3-7 贴粒子）。圣水/HUD 反馈（分段/扫光）在 6c；胜负/run 总结演出在 6d。**伤害数字是逐帧状态差分的近似**：同帧多次掉血合并为一个数（10Hz 下每数帧才一跳，足够；精确逐次留 6d/后续若需）。

**踩坑与修复**
- 无新坑。沿用 6a：无类型 `u` 的 `get_instance_id()` 用 `var id: int =`；Dictionary 一律 `d["k"]` 取值（GDScript 无点取字典）。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn --quit-after 360` → 零脚本/运行期错误（退出期 leak 警告为强退善性 teardown）✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **战斗手感留真人实机验收**（清单见下）。

**V3-6b 真人实机验收清单（交用户）**：F5 运行 → 任意战斗，确认：① 兵移动**丝滑**不再 10Hz 跳格（尤其过桥/转向）；② 被打的兵/塔**闪白**、冒**伤害数字**（数值合理、上浮淡出）；③ 治疗术给友军冒**绿 +数字**；④ 法术（火球/闪电）等大伤害命中有**顿帧**（极短卡顿）+ **震屏**，且**只有战场抖、顶栏/圣水/手牌不抖**；⑤ **塔被摧毁**时明显**震屏 + 大涟漪**；⑥ 震屏时**落点仍准**（拖拽出兵不偏）；⑦ 帧率正常、无报错。回报「通过/哪条不对」。

### V3-6c — 圣水/HUD 反馈（仅 view）  （commit `819a713`）
**前置决策**：见决策日志 41（纯显示层 HUD：分段圣水/满槽脉动/卡牌可用态扫光/下一张预览/王冠倒计时强调）。

**修改（仅 `view/battle_scene.gd`，零逻辑改）**
- **分段圣水条**（`_draw_elixir` 重写）：按 `elixir.maximum`（relic 可改，四舍五入取整）画 N 段 pip，满格逐段填、当前段按小数部分部分填；`is_full()` → 满槽紫色**脉动**（`sin(_elapsed*8)`）。左侧留位给「下一张」chip。
- **下一张预览**（`_draw_next_chip`）：读 `deck.peek_next()`，圣水条右侧画 NEXT chip（卡名截断 + 费用珠）。
- **卡面自绘**（`_draw_cards` + 透明 Button）：手牌 Button 改为**纯输入热区**（`StyleBoxEmpty` 覆盖 normal/hover/pressed/disabled/focus、`focus_mode=NONE`、清空 text），卡面由父 `_draw` 自绘（底板 + 卡名 + 费用珠 + 选中金框/拖拽抬起）→ 便于 V3-7 贴皮。**不可用「扫光」**：出不起的牌压暗罩，暗罩高度随 `圣水/费用` 进度从底部回落（CR 式蓄费提示）。`_sync_cards` 简化为只设 `disabled`（出不起/空格不可拖，沿用 6a）。
- **王冠 + 倒计时强调**（`_draw_topbar` 重写）：左右各画 **3 个王冠**（`_draw_crown` 多边形剪影，按拆塔数填实/描边）取代纯数字；倒计时 ≤30s **红色脉动 + 放大**。
- 底部新增 HUD 底板矩形。

**范围边界**：仅 view，逻辑/config/单测零改。卡面/王冠/圣水珠均程序化白膜（V3-7 贴精灵/UI kit）。胜负与 run 总结演出在 6d。

**踩坑与修复**
- `var cost := match_obj.player.card_cost(nx)`：`match_obj` 无类型 → 方法返回值为 Variant、`:=` 推断失败。改 `var cost: int =`（沿用既有坑）。
- 卡面在父 `_draw` 画、Button 为透明子节点覆于其上：故 Button 必须 `StyleBoxEmpty` 全覆盖（含 hover/pressed/focus）+ 清 text，否则默认样式遮住自绘卡面。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn --quit-after 360` → 零脚本/运行期错误 ✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **HUD 外观/反馈留真人实机验收**（清单见下）。

**V3-6c 真人实机验收清单（交用户）**：F5 运行 → 任意战斗，确认：① 圣水条是**分段 pip**、随回涨逐格填、**满 10 格时脉动**；② 圣水条旁有 **NEXT** 预览（下一张卡名 + 费用珠）且随出牌更新；③ 手牌为**自绘卡面**（卡名 + 费用珠 + 选中金框 + 拖拽抬起）；④ 出不起的牌有**暗罩扫光**、随圣水接近费用**从底部回落**到点亮，且**仍拖不动**直到够费；⑤ 顶栏左右各 **3 王冠**、按拆塔**点亮**；⑥ 倒计时 **≤30s 变红脉动放大**；⑦ 帧率正常、无报错、出牌/拖拽仍正常。回报「通过/哪条不对」。

### V3-6d — 胜负演出 + run 奖励/结算揭示（仅 view）  （commit `c22d601`）
**前置决策**：见决策日志 41（纯显示层；本 gate 跨 `battle_scene`(结算) 与 `run_scene`(奖励/结算) 两场景）。

**修改（`view/battle_scene.gd`，零逻辑改）**
- **结算改演出**：去掉旧「一结束即建 Label/Button 静态面板」，改单一 `_end_t` 计时的 `_draw_end_screen`（全 `_draw` 绘制）——调暗淡入 → **标题 sting**（透明淡入 + 字号 `_ease_back` 回弹）→ **王冠逐个落入**（你拆塔数，错峰 + 回弹下落，复用 `_draw_crown`）→ **比分滚动**（count-up）；`END_BTN_DELAY=0.85s` 后按钮（CONTINUE / REMATCH+MENU）淡入。`_result_layer` 一结束即 `visible`（透明全屏 STOP）**拦截点击 → 演出期不能再出牌**。新增 `_ease_back`（back-out 缓动）。
- `_start_ending`（捕获 result + 双方塔血快照）/`_add_result_buttons`（延迟建按钮 + tween 淡入）取代 `_show_result`。

**修改（`view/run_scene.gd`，零逻辑改）**
- **奖励揭示**：`_build_reward` 的标题/候选卡/SKIP 经 `_anim_pop`（从下方淡入 + `TRANS_BACK` 回弹归位）**逐张错峰**揭示。
- **选中 flourish**：`_on_pick` 选中的卡**放大 + 金色**(`create_tween`)再回中枢；`_picking` 守卫挡二次点击/SKIP；`_offer_nodes` 记 id→卡节点。
- **结算揭示**：`_build_summary` 的 RUN CLEARED/OVER 标题、战绩、解锁、按钮逐条 `_anim_pop` 错峰入场。
- 新增 `_anim_pop` 通用入场动画助手。

**范围边界**：仅 view，逻辑/config/单测零改。塔被摧毁的「爆破序列」沿用 6b（震屏 + 大涟漪），本步不再加碎块粒子（留 V3-7 美术）。所有演出为白膜程序化（字号/多边形/tween），V3-7 贴精灵不改时序。

**踩坑与修复**
- 无新坑。`battle_scene` 演出走 `_draw`（与 6b/6c 同源、单 `_end_t` 计时）；`run_scene` 走 Control `create_tween`（节点 UI 友好）。Tween 绑定的节点被 `_clear` free 时 Godot 自动杀 tween，无悬挂。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn|run_scene.tscn --quit-after 200` → 两场景零脚本/运行期错误（演出/奖励覆盖层 200 帧 smoke 内未触发，靠解析校验 + 真人验收）✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **演出留真人实机验收**（清单见下）。

**V3-6d 真人实机验收清单（交用户）**：① 普通对局结束：屏幕**渐暗** → **YOU WIN/LOSE/DRAW** 标题**弹入放大**(sting) → 你的**王冠逐个落下**(回弹) → **比分滚动**计数 → 稍后 **REMATCH/MENU**(或 run 模式 **CONTINUE**) 按钮**淡入**；演出期间**点不动手牌**；② ROGUELITE 胜后：奖励覆盖层 **DRAFT A CARD / CHOOSE A RELIC** 标题 + 候选**逐张错峰弹入**，**选中**的卡**放大金光**再回中枢（卡组/relic 已加）；③ run 通关/败北：**RUN CLEARED / RUN OVER** + 战绩 + 解锁**逐条错峰入场**，BACK TO MENU 可用；④ 全程无报错、帧率正常、REMATCH/CONTINUE/MENU/NEW RUN 流转仍对。回报「通过/哪条不对」。

---

## V3-7 — 精灵美术（已完成）

> 方向见 PLAN_V3 §3 + 决策 42/43。执行顺序：素材准备 → ① 卡牌改名 → ② 多语言 → ③ 美术垂直切片 → 7b 量产（单位/塔/FX·投射物/地形/卡面）→ 7b-6 圣经定稿。

### V3-7 准备 — 美术素材入库 + ART_ASSETS（已提交 `6579207`）
题材敲定黑暗中世纪幻想、主风格 Pixel Grit（决策 42）。`testAssets/` 原始库 + `assets/` 选用 94 文件 + `docs/ART_ASSETS.md` 美术圣经雏形。

### V3-7 ① — 卡牌黑暗中世纪化改名（仅 config）  （commit `0cb32f2`）
`config/cards.json` 13 张 `name` 改中文定稿（id 不变、英文名入 i18n）；knight/archers/goblins 原名保留。Excel `--from-json` 同步、`--check` ok。**验收**：单测 172/172；config check ok ✅。映射见 [docs/ART_ASSETS.md §6](ART_ASSETS.md)。

### V3-7 ② — 多语言 i18n + 像素中文字体 + 设置切换（仅 view/config）  （commit `0cb32f2`）
**前置决策**：43。
**新增/修改**
- `config/i18n.json`（中英 ~80 key：UI/卡名/relic 名+描述/难度/数值模板）。
- `view/i18n.gd`（autoload `I18n`）：运行时读 i18n.json 建 en/zh `Translation` 注入 `TranslationServer`；locale 存 `user://settings.cfg`、默认中文；`set_language`/`current_locale`。`project.godot` 注册 autoload。
- `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf`（OFL，自动禁 subpixel）+ `OFL.txt`；`project.godot` [gui]theme/custom_font 设为它；`battle_scene._font` 改 load 该 ttf（draw_string 中文）。
- 6 场景接入 `tr()`：main_menu/level_select/deck_builder/battle_scene/run_scene（卡名/relic/难度/数值/HUD/结算/奖励全中英）。
- `view/settings.gd`+`.tscn`（新）：中/英切换（即时 reload 本页 + 存盘）；main_menu 加「设置」入口。
**范围边界**：仅 view + config，逻辑/单测零改（i18n 表现层、无单测）。
**踩坑**：`gh` 不走代理 → 用 `curl --proxy` 取 GitHub release；Windows python 不认 git-bash `/tmp` → 下载放工程相对路径；CSV 编辑器导入 headless 不友好 → 改 JSON + autoload 运行时构建。
**验收**
- 6 场景 headless smoke 零脚本错误（tr key / `%` 格式化全对）；单测 **172/172**。✅
- **中文像素字体显示真人认可**（主菜单/组卡截图，2026-06-16）✅；中英切换 + 其余场景全中文细节留真人继续验收。
- 既有良性 warning（`size` 遮蔽基类 / int-as-enum / 整除）非本步引入、不影响运行，暂忽略（将来统一清一轮）。
**下一步**：③ 美术垂直切片（已完成，见下）。

### V3-7 ③ — 美术垂直切片（仅 view + 1 渲染设置）  （commit `41c09d5`）
**前置决策**：用户 2026-06-20 选定 **架构 A = immediate `_draw` + `draw_texture`**（契合 6a–6d 的 `_draw` 体系，单位动态增减天然支持，逻辑零改）+ 切片范围 = 骑士 + building 塔 + 火爆炸 FX。
**修改（仅 `view/battle_scene.gd` + `project.godot`）**
- 顶部 `preload` 三纹理（Heavy_Knight Non-Combat / building1 / Fire_Explosion）+ 帧常量；新增 `_draw_sheet`（从 sheet 取 (col,row) 帧 `draw_texture_rect_region`，`modulate` 染色）。
- `_draw_units`：`knight_body` 用精灵帧（32×32、walk 行循环 6fps），`modulate=fill`（染队伍色区分敌我 + 复用受击闪白）；其余兵仍白膜圆。
- `_draw_towers`：塔主体改 `draw_texture_rect(building1, modulate=fill)`，保留血条/王冠标记/摧毁。
- `_draw_fx`（落地涟漪）：改 `Fire_Explosion` 28×28×12 序列帧。
- `project.godot`：`rendering/textures/canvas_textures/default_texture_filter=0`（最近邻，像素锐利，像素美术前提）。
**范围边界**：仅 view + 1 渲染设置，逻辑/config/单测零改。切片验证**管线**（精灵导入→帧动画→替白膜→逻辑零改）；精确动画状态/朝向（现取 sheet 一行循环、不分上下）/全单位·塔·卡面·地形换皮留 **V3-7b 量产**。
**验收**
- battle_scene headless smoke 零脚本错误（preload 纹理 + 塔贴图绘制 OK）；单测 **172/172**。✅
- **真人 6/6 验收通过（2026-06-20）**：骑士精灵(染色/闪白) + building 塔贴图 + 火爆炸序列 + 像素锐利 + 其余白膜 + 流程不变，全通过。✅
**下一步**：**V3-7b 量产** —— 按此管线给全部单位（含朝向/idle/walk/attack/death 状态）、塔（王/公主区分）、卡面、地形 tile、FX 批量换精灵 + 美术圣经定稿（决策 42 升级）。

### V3-7b — 量产（按 ③ 管线全量换精灵；仅 view，逻辑/单测零改）  （本次提交：7b-1/2/3）
**开工规格**（用户 2026-06-20 确认）：保真度=**务实**（走+攻两态；死亡复用现有 FX；idle 并入 walk）；朝向=**混合**（方向族按 owner 取朝上/朝下行，对称族不处理）；单位**一次上全 10**。执行序 = 7b-1 单位 → 7b-2 塔 → 7b-3 FX/投射物 → 7b-4 地形 → 7b-5 卡面 → 7b-6 圣经定稿。
**帧网格坐定方法**：临时脚本 `tools/_frame_probe.py`（透明间隔自动探测）+ 带行号网格放大图肉眼核对（**临时物，验后即删、不入 git**）。坐实结论：64×224 怪物族=16×16/4列×14行（goblin/skelly/orc/zombie/…，但 goblin↔skelly 行语义略不同需逐个核）；Archer_Combat=32×32/4×8；axe_warrior_combat=32×32/4×20；fire_skull=16×16/4×10；Mage/Archer Non-Combat=16×16/4×31；**Heavy_Knight Non-Combat=24×24/4×31**（≠③ 误用的 32/3，本次修正）。英雄多为 Combat(攻)/Non-Combat(走) 双 sheet、帧尺寸可不同。

#### V3-7b-1 — 单位精灵全量（仅 view）
- 新增 `view/sprite_db.gd`（manifest，纯表现层数据）：`unit_id → {scale, walk/attack:{tex,fw,fh,cols,row,row_up?,n,fps,sc?}}`，10 单位全覆盖。`frame(unit_id,state,owner,t)` 返回 `{tex,src:Rect2,scale}`；owner=0(玩家,朝上) 有 row_up 则取背面行。
- 改 `battle_scene._draw_units`：通用精灵查询取代骑士特例——状态派生（`current_target` 在 `attack_range`(塔目标 +半占位) 内→attack，否则 walk）；染队伍色(fill)+受击闪白；无精灵回退白膜。删 ③ 的 `_draw_sheet` + 错的 `KNIGHT_*`/`TEX_KNIGHT` 常量。
- **修正 ③ 遗留 bug**：骑士帧 `32px/3列` → 正确 `24×24/4列`。
- 范围：仅 view；塔仍 building1、FX 仍火爆炸（属 7b-2/7b-3）。
- 验收：单测 172/172；headless smoke 干净；选中帧预览拼图自查全对；**真人实机 1-7 全过**（10 兵皆精灵 + 走/攻动画 + 朝向 + 染色 + 大小 + 流程）。

#### V3-7b-2 — 塔换皮（仅 view）
- `battle_scene._draw_towers` 重写 + preload 拆 `TEX_TOWER_KING`(building1 大城堡)/`TEX_TOWER_PRINCESS`(building6 小堡)。
- **保持贴图原始长宽比 + 底部贴地**（不再压扁填正方形）；王塔系数更大保主次（building1 横宽、building6 方正，否则公主反而更高）；王塔顶画**金王冠**(`_draw_crown`)；摧毁态=**压低 42% + 暗色废墟堆**；队伍色改温和 `WHITE.lerp(base,0.5)` 让城堡细节透出 + 受击闪白。
- 候选核定：building2/3/8=城镇组合图(多房+散屋顶,不用)；building6 最干净对称单体→公主塔。
- 验收：单测 172/172；smoke 干净；预览图自查主次/染色/废墟成立；**MCP project_run 截图确认**引擎内王冠/王>公主/敌我蓝红/废墟态/长宽比全对、整局零运行期错误。

#### V3-7b-3 — 技能命中 FX 按卡区分 + 远程投射物（仅 view）
- **命中 FX 分派**（原所有出牌同一火爆炸）：`_fx` 项带 `kind`+`radius`；召唤兵=中性尘土环（程序化）/ 火球=火爆炸 / 闪电=蓝白电能环(Lightning_Energy 48×48×9) / 电火花=红电环(Red_Energy) / 箭雨=程序化落箭 / 滚石=褐尘 / 治疗=绿光环+上浮十字 / 塔毁=大火。`_draw_fx` 按 kind 分派 sheet 序列(`_fx_seq`) 或程序化(`_fx_dust/_fx_arrows/_fx_heal`)；`_fx_kind`/`_fx_dur` 助手。`_on_card_up` 据卡 id 定 kind+radius。
- **远程投射物**（路线 A，零逻辑改）：`_detect_attacks` 每帧读各远程兵(`attack_range≥2.5` 且在 `PROJ_KIND`)的 `_attack_cooldown`，检测**跳升**(`cur>prev+0.01`)=刚 `mark_attacked` → 发射 `from(disp位)→to(current_target.pos)` 投射物；弓箭手=箭(带头朝向)/女巫=紫法术弹/火颅=火球序列帧(fire_skull_fireball)。`_draw_projectiles` 线性飞行作画；`_projectiles`/`_atkcd` 状态随死亡剔除/按时回收。
- **bug 修复**（真人首验抓到「弓箭手只射第一发」）：原判据「冷却 ~0→满」错——逻辑层**同 tick 内**冷却减到 0 又立即设回满，view 永远采样不到 0（最低只见 ~0.1=一个 TICK_DELTA），故仅单位出生(初值0)那一发触发。改为检测**冷却跳升**（仅 `mark_attacked` 会让冷却上升，平时只递减）→ 每次攻击都触发。
- 范围/已知限制：仅 view；**AI(敌方)施放法术暂不显示命中大 FX**（路线 A 的 FX 只挂玩家出牌路径；敌方法术爆点需「同帧多兵聚集掉血」启发式推断=决策 30，留可选后续）。
- 验收：单测 172/172；smoke 干净（含 AI 远程兵触发投射物路径）；**MCP 临时计数器验证**——`PROJ` 累计 0→12→32 整局持续增长（旧 bug 下每兵只射一发，绝无可能），投射物修复确凿生效（临时计数器验后已撤）；真人玩通一整局无报错、帧率正常。

#### V3-7b-4 — 地形 tile（仅 view）
- `battle_scene._draw_terrain` 重写：纯色块 → **逐逻辑格铺 16px tile**（与河行/桥列精确对齐）。preload Lonesome Summer：FLOOR(地面) / simple_water(河水 4×3=12 帧**动画**) / COBBLESTONE(桥)。
- 助手：`_blit_tile` / `_draw_ground_tile`(纯土双变体 (4,1)/(4,2) 按坐标 hash + 敌方半场微暖调辨上下) / `_draw_bridge_tile`((1,1)/(2,1)) / `_draw_water_tile`(按 `_elapsed` 取帧)。塔占位下也铺地面（塔贴图透明盖上，免黑边）。删已无用旧地形色常量 `COL_GROUND/WATER/BRIDGE/GROUND_ENEMY`。
- tile 选格经 `tools/_tg_probe.py`(临时，不入 git) 行列网格图 + 拼贴预览坐定满铺格。
- 范围：仅 view，逻辑/config/单测零改。河岸为硬边（未用 RIVER 自动拼边 tile，留后续美化）。
- 验收：单测 172/172；headless smoke 干净；拼贴预览确认四类 tile 满铺无破绽。**真人观感待看（本步按约定只单测、不走 MCP）**。

#### V3-7b-5 — 战斗手牌卡面（仅 view）
- `battle_scene._draw_cards` +卡面图：兵牌画**单位精灵正面静帧**（`SpriteDB.frame(unit_id,"walk",owner=1,0)`，自然色不染队伍色）；法术牌画**代表图标**（火球=Fire_Explosion 帧 / 闪电=Lightning_Energy 帧 / 电火花=Red_Energy 帧 / 箭雨=程序化箭簇 / 滚石=程序化石块 / 治疗=绿十字）。
- 助手 `_draw_card_art`（spawn→精灵，否则→图标）/ `_draw_card_spell_icon`。卡名/费用珠/不可用扫光/选中框照旧叠在图上。
- 范围：仅**战斗内手牌**（immediate `_draw`）。**draft 奖励卡 / 组卡界面**用 Control(Button+Label) 渲染、需另用 TextureRect，留 7b-5b。
- 验收：单测 172/172；smoke 干净；**真人验收通过**。

#### V3-7b-5b — draft 奖励卡 + 组卡界面卡面（仅 view）
- `view/sprite_db.gd` +共享 API：`card_portrait_tex(card_id, loader)`（兵牌→单位正面帧 AtlasTexture；火球/闪电/电火花→特效帧；箭雨/滚石/治疗/未知→null）+ `make_card_portrait(...)`（产出配置好的 `TextureRect`：AtlasTexture + `STRETCH_KEEP_ASPECT_CENTERED` + 最近邻 + 鼠标穿透）+ FX 贴图 preload + `SPELL_ICON` 表。
- `view/run_scene.gd`：draft 卡牌候选左侧加肖像（relic 候选不加）。
- `view/deck_builder.gd`：卡池格（有肖像→图上名+费在下、无肖像法术→名+费居中）+ 已选 8 格（持久 `TextureRect`，`_refresh` 按选中卡设纹理/隐显，槽名改单行卡名）。
- 范围：仅 view，逻辑/config/单测零改。箭雨/滚石/治疗在菜单为文字（无单帧贴图）。
- 验收：编辑器导入解析全过；单测 172/172；deck_builder smoke 干净；**真人验收通过**。

#### V3-7b-6 — 美术圣经定稿（仅文档）
- `docs/ART_ASSETS.md` 升级为**定稿**（决策 42 升级）：§4 单位 manifest 帧网格/走攻行/朝向（权威实现 `view/sprite_db.gd`）+ §4.1 帧网格坐定方法/朝向约定/渲染前提 + §5 塔/FX/地形/卡面 as-built + §7 缺口与后续美化 + §10 待决策结算（卡名/塔/i18n 已结，git 版权策略仍未决）。
- 加单位/换皮以后照 §4 改 `sprite_db.DB` 即可；探测脚本是临时物、不入 git。
- 验收：纯文档，无代码/单测改动。

> **V3-7（精灵美术）整阶段收官**：准备 → ①卡牌改名 → ②多语言 → ③垂直切片 → 7b 量产（单位/塔/FX·投射物/地形/卡面）→ 7b-6 圣经定稿。单测全程 172/172。

**后续调整**：用户 2026-06-20 原计划 V3-7 后跳过 V3-8、先做 V3-9 平衡；随后明确要求先补"音频资源表 + 工程读取机制"，因此 V3-8 已在下节完成代码与配置管线。V3-5 短战役+引导仍暂缓，V3-9 平衡可继续并行推进。

---

## V3-8 — 音频资源表 + 运行时音频机制（并行补基础管线）  （commit `0c5ce0e`）

**前置决策**：用户 2026-06-20 明确要求 Codex 兼任音乐音效师，先把"音频资源表 + 工程读取机制"做出来；Claude 可继续并行做数值平衡。本步只搭音频配置与播放入口，**不引入真实音频素材**。

**配置工作流**
- 新增独立音频资源表：`config/AudioConfig.xlsx`（策划源表）→ `config/audio_assets.json`（Godot 运行时读取）。
- 新增 `tools/build_audio_config.py`：支持 `--init` / 默认 xlsx→json / `--from-json` / `--check`。音频管线不写入 `GameConfig.xlsx`，避免和卡牌/单位/关卡平衡表互相污染。
- 表字段：`asset_id / display_name_zh / type / group / bus / path / asset_status / loop / volume_db / pitch_min / pitch_max / max_polyphony / priority / suggested_duration_s / implementation_phase / trigger / effect_notes / source_notes`。
- `path` 是目标 Godot 资源路径，不代表文件已存在；`asset_status=planned/sourced/imported/final` 才表示素材状态。工作簿新增 `ColumnGuide` sheet 和表头注释，解释每一列用途。
- 首版清单覆盖 BGM、ambience、stinger、UI、圣水、run/reward/relic、部署、攻击/命中/死亡、远程投射物、塔、全部现有法术等资源；`display_name_zh` 为中文资源名，`effect_notes` 全部改为中文声音设计说明。

**新增 / 修改**
- `sound/` 根目录 + 子目录占位：`bgm/`、`sfx/`、`ui/`、`stingers/`、`ambience/`。所有音频文件路径统一从 `audio_assets.json` 指向 `res://sound/...`。
- `logic/config_loader.gd`：加载并校验 `audio_assets.json`，新增 `audio_assets` / `get_audio_asset` / `has_audio_asset`。
- `view/audio_manager.gd`（autoload `AudioManager`）：统一 `play_music` / `play_ambience` / `play_sfx` / `play` / `stop_music` / `stop_ambience`；BGM 与 ambience 分通道，SFX 按配置并发池播放；按配置读取 bus、音量、pitch、并发数；真实 `.ogg/.wav` 尚不存在时安全返回 false，不报错。
- `project.godot`：注册 `AudioManager` autoload。
- `view/main_menu.gd`：进主菜单播放 `music_main_menu`，停止 ambience，按钮点击走 `ui_button_press`。
- `view/run_scene.gd`：run 中枢播放 `music_run_map` + `amb_run_campfire`；进入战斗、奖励打开、draft/relic 选择、skip/new run/back 挂对应 UI 音效入口。
- `view/battle_scene.gd`：普通/elite/boss 对局切换 `music_battle_normal`/`music_battle_boss` + `amb_battle_wind`；拖卡、合法/非法落点、单位/法术出牌、受击、塔毁、远程开火、胜负结算 sting 挂音效入口。
- `tests/test_audio_config.gd`：覆盖音频清单加载、必需字段、中文资源名/素材状态/效果说明、路径统一在 `res://sound/` 下、P0 核心资源存在。
- Godot 导入生成：`view/audio_manager.gd.uid`、`tests/test_audio_config.gd.uid`。
- `AGENTS.md` / `CLAUDE.md`：补充音频配置工作流与 V3-8 当前进度，明确 Godot 运行时读 JSON、不直接读 xlsx，音频文件统一进 `sound/`。

**范围边界**
- 本步只建立"表 → JSON → AudioManager → 场景触发"的机制和完整需求表；不制作/导入实际音频文件。
- 当前没有 `Music/SFX/UI/Ambience` bus layout 时，`AudioManager` 会自动 fallback 到 `Master`，后续 V3-9 设置/音量面板再加 bus layout 与音量控制。
- 战斗音效当前仍按显示层状态 diff 触发，匹配现有 V3-6/7 路线；未来做音频精修时建议升级为逻辑层轻量 combat event buffer，避免高频 hit 重复过密。

**验收**
- `uv run --with openpyxl python tools/build_audio_config.py --check` → `audio config check ok`。✅
- `godot --headless --path . --script res://tests/test_runner.gd`（`HOME` 隔离）→ **177/177 全过**。✅
- `godot --headless --editor --path . --quit`（`HOME` 隔离）→ 导入/Autoload 解析通过；headless 下 MCP 插件按预期禁用。✅
- 退出时仍有一次 `ObjectDB/resource still in use` 警告，来自 headless/test teardown 阶段；命令退出码为 0，且无脚本解析或运行期错误。

---

## V3-9 — 平衡（进行中）

> 方向见决策 35（数据驱动测量 + 难度交真人）。用户 2026-06-20/21 反馈：纯公平对局**无卡牌数值养成 → 难度=AI 竞技水平**，玩家 vs AI 拼手速；最低档也太压迫，要求**降难度底**，进而定为 **5 档系统**。相关记忆 [[difficulty-is-ai-competence]]。

### V3-9 ① — 难度系统扩 5 档 + 降难度底（config/view/逻辑 + 单测）  （commit `0c5ce0e`）
**前置**：用户反馈训练场太凶（临时 harness 实测：旧 easy AI vs 不出兵的玩家 45s 团灭）。先把 easy 放缓、新手关 normal→easy；随后用户定为 5 档。
**测量方法**：临时 harness `tools/_pace_probe.gd`（**验后即删、不入 git**）三组——①节奏（双方镜像 bot）：全程拆王塔决胜、0 超时 0 平、44–128s，**节奏健康**；②对称卡组 + 交换出牌序对照：胜率噪声大且随序漂移 → proxy **测不准胜负/侧平衡**（印证决策 35，arena 塔位已验上下对称）；③**真实 AI 压迫度**（真 AIController vs 不出兵玩家）：测出兵节奏/拆塔速度，作难度梯度客观参照。

**改动**
- `ai/ai_controller.gd` `DIFF` 扩 5 档（`cooldown`=AI 出兵节奏主杠杆）：rookie 9/7.0 · easy 9/5.0（均不防守不集火）· normal 7/2.5（防守）· hard 5/1.2（防守+集火）· extreme 4/0.5（防守+集火）。`DEFAULT_DIFF` 仍 normal。
- `view/level_select.gd`：5 档排序权重 + **5 色渐变底**（青绿→绿→蓝→琥珀→深红）+ 标题按档一一映射（去掉旧 hard 按圣水分 blitz/champion 的分叉）。
- `config/i18n.json`（中英）：标题 新手村/试炼场/竞技场/冠军赛/生死战；徽章 新手/简单/普通/困难/极限；说明 5 条。
- `config/levels.json`：**5 关一档一关**——level_01 rookie(新手村) / level_02 easy(试炼场) / **level_05 normal(竞技场，新增)** / level_03 hard(冠军赛) / level_04 extreme(生死战)；修复「两个训练场」撞名 + 难度断层（level_select 标题原按难度档生成，两关同 easy 才会撞名）。
- `tools/build_config.py`：`DIFFICULTIES` 枚举扩 5 档；`GameConfig.xlsx` 重建 + `config check ok`。
- `tests/test_config_loader.gd` / `tests/test_ai_controller.gd`：更新断言/注释到 5 档。

**梯度实测**（真 AI 压迫度，首座公主塔被拆耗时，越久越温和）：rookie **34s** → easy 31 → normal 27 → hard 22 → extreme **17s**，单调递进、分档清晰；rookie 不出兵玩家撑到 59s/保 1120 塔血。

**范围边界 / 现状**：仅难度配置 + 选关 UI；不动战斗逻辑。难度**手感（5 档体感）整体交真人**（决策 35）；rookie/试炼场真人已确认能轻松取胜。

**验收**：单测 **177/177**；`build_config.py --check` → `config check ok`；梯度实测单调。

---

## V3 回归修复批次 — 寻路 / 塔射箭 / 亡语落水 / 攻击动画（2026-06-21，真人验收通过）  （commit `14a29e5`）

> 来源：V3 表现层回归验收（用户实机过核心对局）反馈的 4 个问题，一批修完并真人验收通过。跨 V3-1(寻路)/V3-1e(塔火表现)/V3-3(亡语)/V3-7b(攻击帧)。

**A5-1 地面寻路卡桥/被风筝（逻辑 bug + 单测）**
- 根因：地面兵 aggro 锁敌方单位后走「直线趋向」(`_step_toward_point`)，撞水即原地冻结；对岸/河上有敌兵时近战兵直奔对岸→撞河→卡岸/桥边，被对面远程(射程更长)持续风筝致死。
- 修 `logic/arena.gd`：①`_nearest_enemy_unit_in_aggro` 加地面直线可达性过滤(`_ground_path_clear` 沿线采样无水/界外)，隔河敌兵不分心→继续走流场绕桥；②`_step_toward_point` 撞水回退 `_step_toward`(流场绕桥)、绝不冻结(治「卡桥」：窄桥上分心斜拉会单步滑出桥落水冻结)。
- 单测 +2：`test_no_distraction_across_river`、`test_ground_unit_crosses_bridge_despite_across_river_enemy`。

**A5-2 塔不射箭（纯 view）**
- 逻辑层塔反击(V3-1e)一直在掉血，但 view 无开火视觉(V3-7b-3 投射物只挂远程兵、漏了塔)。
- `view/battle_scene.gd`：`_detect_attacks` 加塔循环——塔 `_attack_cooldown` 上升沿=刚 `mark_attacked`→从塔身射箭到射程内最近敌兵(新 `_tower_target` view 侧复刻选择、`_tatkcd` 记上帧冷却)，复用投射物系统(arrow)。

**亡语裂兵落水（逻辑 bug + 单测）**
- 根因：`_remove_dead` 亡语在 `pos+offset` 直接生成、未校验落点；golem 死在桥/水边时偏移溢出到水。
- 修 `logic/arena.gd`：新增 `_clamp_to_ground`(确定性环形搜最近可走地面 tile 中心)，地面裂兵生成经它钳制(飞行裂兵不钳)。
- 单测 +1：`test_death_spawn_never_lands_in_water`。

**攻击动画缺失（纯 view）**
- 根因：knight/archer/musketeer 用独立 Combat sheet，attack 行/帧尺寸为 V3-7b「初版最佳读数」未核准→静态/错位；其余单位 walk+attack 同 sheet、行碰巧对(食人魔有动画)。
- 经放大带行号预览图(临时 `_atk_*.png`，验后即删)核定，修 `view/sprite_db.gd` attack：knight row8→row0/row_up5；archer row4→row2/row_up3；**musketeer 实为 16×16 4列(原误配 32×32 2列)**、row0/row_up6；按 owner 补朝向(玩家朝上=row_up、敌朝下=row)。

**A7 亡语裂兵数量**：早有 `test_on_death_spawn_summons_units` 覆盖，本批确认逻辑无 bug、未改(用户先前「没裂兵」为混战没看清)。

**踩坑**：①battle_scene 多行 Edit 因某行空白匹配失败→改单行锚定。②女巫 Combat sheet 64×256 既可读作 32×32 2列、又可 16×16 4列，预览图按 32 渲染每格含 4 小人才发现实为 16px。

**范围 / 现状**：攻击动画仅修 3 个独立 CB sheet 单位；其余单位若实机仍缺攻击动画/朝向别扭，后续按单位核对其 sheet 行(真人验收已确认本批 OK)。

**验收**
- 单测 **180/180**(+3：寻路 2 + 亡语落水 1；旧 177 零回归)。
- battle_scene 360 帧 smoke 零脚本/运行期错误。
- **真人实机验收通过(2026-06-21)**：寻路绕桥不卡/不被风筝、塔射箭、亡语裂兵不落水、治愈回血、骑士/弓箭手/女巫攻击帧动画，均 OK。

---

## V3 UI/UX — 像素设计系统 + 全屏统一升级（2026-06-21，真人验收通过）  （commit `242b287`）

> 来源：用户要求「整个游戏菜单/系统界面整体优化一版、保持像素风」。先立设计系统 + 主菜单标杆（用户认可「夜色战场 + 石碑按钮」布局方向，美术=像素风），再一口气推广到所有屏。落地方式 = Theme/9-slice（用户选定）。

**设计系统 PixelUI（`view/ui/pixel_ui.gd` + `tools/gen_ui_assets.py` + `assets/ui/`）**
- 色板常量（黑暗中世纪夜色：羊皮纸字/金/圣水紫/石板/夜底）+ 字体（中文 Fusion Pixel；标题金描边）。
- `tools/gen_ui_assets.py`（PIL 生成器，保留以便重生成/调色）→ `assets/ui/` 12 张：9-slice 按钮石板/烫金/暗各三态 + 凸/凹面板 + 720×1280 夜色战场背景。
- API：`style_button(btn,kind)` 套 9-slice 三态 + 字色；`panel_box(kind)` 容器；`sbpixel(bg,bw,col)` 动态语义色 StyleBoxFlat 像素方块；`add_background()` 一键铺夜色背景。

**架构决策（编辑器开着 + MCP 无法导入新贴图）**：Godot 双实例锁 → 编辑器 GUI 开着时 MCP `reimport`/`write_text scan` 都无法为**全新** png 生成 `.import`（headless `--import` 又抢锁）。故定：**固定中性样式（按钮/面板）用 9-slice 贴图**（关编辑器时一次性 headless 导入）；**动态语义色（难度色等）用 `sbpixel` 程序化像素方块**，不新增贴图。曾试的 card_tint/badge_tint 可染贴图因此弃用、已删。

**6 屏统一（仅 view，逻辑/单测零改；MCP 逐屏实跑 game 截图验证、零 runtime error）**
- `main_menu`：夜色背景 + 9-slice 烫金石碑「开始」+ 石板按钮 + 像素金描边标题 + 按下 scale juice + 音效。
- `level_select`：5 档难度色像素方块卡（`sbpixel` 难度色）+ 夜色背景 + 金标题；**修复返回按钮被遮挡 bug**（5 卡固定布局 270 起×200 溢出屏外 → 压缩到 238 起×180，返回按钮进屏）。
- `settings`：夜色 + 中/英 gold/stone 按钮。
- `deck_builder`：像素方块卡池（SpriteDB 肖像保留）+ 9-slice 出战(金)/返回(暗) + 金选中框。
- `run_scene`：像素方块节点链（当前金/boss 红框）+ 9-slice 战斗(金)/新征程(石)/菜单(暗) + 金标题 + 奖励/结算覆盖层动画保留。
- `battle_scene` HUD **轻量对齐**：`COL_PANEL/CARD_BG/CARD_SEL/CROWN` 对齐 PixelUI 石板/金 + 顶栏底/卡面像素描边；**战场单位色 `COL_PLAYER/OPPONENT` 不动**（与单位染色耦合）。

**踩坑**：①新贴图 import（见架构决策）。②run_scene 重构误留垃圾行（`add_child.call_deferred`）→ 修。③`AudioManager` autoload 在 MCP 频繁 stop/run 切场景时报 `Identifier not found: AudioManager`（reload 时序瞬时误报，运行时 autoload 正常、正常启动不复现）——非 bug，记录备查。

**验收**：单测 **180/180**（view 改动零回归）；MCP 逐屏 game 截图 + 日志零 runtime error；**真人实机验收通过（2026-06-21，关卡 + roguelite 全流程）**。
**遗留**：①战斗节奏偏紧张（不够新手友好）→ 留作数值调优（用户作为策划后续调）。②battle HUD 深度 9-slice 改造、真实美术素材（itch UI kit/图形 logo）精致化留后续。

---

## V3-5 — 新手战役 + 新手引导（已完成）

> 方向见决策 45（教学专属 6 关 / 可重试 / 无剧情 / roguelite 不锁）。拆 V3-5a 框架 + V3-5b 引导。

### V3-5a — 战役框架（逻辑+config+view+单测）  （commit `80cf141`，真人 1-6 验收通过 2026-06-22）
**逻辑 + config**
- `logic/campaign_state.gd`（CampaignState）：线性进度 + 可重试流转（胜推进 / 败·平·未结束留原地重打 / 全胜→CLEARED；区别于 RunState 二元永久死亡）+ to_dict/load_dict。
- `config/campaign.json`（结构性、不进 Excel）：default = 6 关序列 `{level_id, focus}`（deploy→elixir→bridge→defend→spell→boss）。
- `config/levels.json` +6 教学关 `campaign_01~06`：AI 循序（前 3 关弱卡组+rookie / 中 2 关基础+easy / boss 关强卡组+normal+高塔血 3200/1800）；player_deck 统一教学卡组。**ai_deck 必须满 8 张**（build_config 校验 + AI Deck 需 ≥5 循环抽牌）。
- `config_loader.gd`：挂 campaign.json + 校验（每关 level_id 在 levels）+ get_campaign。
- 单测 `test_campaign_state`(5) + `test_config_loader`(+1) → 186/186；config check ok。
**view（接通，可玩）**
- `view/campaign_scene.gd`+`.tscn`（新）：战役中枢——6 关进度链(当前金▶ / boss 红框 / 完成✓) + 进度 + 战斗/菜单，PixelUI 风格；处理回传结果(推进/重打)+通关结算；会话内进度（落盘留后续）。
- `battle_scene.gd`：+战役模式（GameState.campaign 非空 → 用当前关 level_id + 关卡默认教学卡组建场；结算 CONTINUE 回中枢写 campaign_last_result；focus=boss 用 boss 音乐）。
- `main_menu.gd`：+「新手战役」金按钮（主线），5 按钮重排。
- `game_state.gd`：+campaign / campaign_last_result 握手。
- `i18n.json`：+战役文案（campaign_title/progress/node/cleared + focus_* 6 个，中英；「新手战役」命名）。
**踩坑 / 修复**
- ⚠️ **选关界面 bug（本步引入、当天修复）**：campaign_* 加进 levels.json 后 `level_select` 读全部 levels 把 6 教学关也按难度档显示（4 个「新手村」等）、列表溢出挤掉返回按钮 → 修 `level_select._sorted_level_ids` 过滤 `begins_with("campaign_")`（真人验收过）。教训：往 levels.json 加非自由对战关时，所有消费 `levels.keys()` 的地方都要考虑过滤。
- config_loader 多行 Edit 因深嵌套 Tab 数误判失败 → 改用浅缩进 ASCII 锚。
**验收**：单测 186/186；config check ok；MCP 逐场景截图（战役中枢 / 选关恢复 5 关）正常；**真人实机 1-6 验收通过 2026-06-22**（菜单战役入口→中枢→打关→胜推进/败重打→通关→续档）。
**遗留**：战役第一关仍偏难（首版 AI 占位，留后续整体大改时调，见 [[battle-pacing-too-tense]]）。
**下一步**：V3-5b 新手引导覆盖层（局部高亮 + 手指指引 + 气泡文字，数据驱动引导脚本）。

### V3-5b — 新手引导覆盖层（仅 view + config，真人验收）  （commit `4364dbb`，真人验收通过 2026-06-22）
**前置决策**：见决策 45 + 用户 2026-06-22 选定（JSON 数据驱动 / 首版只第 1 关核心引导 / 动作触发为主+点击）。纯 view 表现层（决策 30/41 路线），无逻辑改、无新单测。
**新增 / 修改**
- `config/tutorial.json`（新，结构性、不进 Excel）：`campaign_01` 引导 4 步 intro→elixir→deploy→push，每步 `{text_key, highlight, finger, advance}`；advance = tap(点击) / card_played(出兵动作触发)。
- `config_loader.gd`：挂 tutorial.json + `get_tutorial(level_id)`（结构性、无校验）。
- `config/i18n.json`：+引导文案 `tut_c1_*` + `tut_continue`（中英）。
- `view/battle_scene.gd`：引导集成——`_init_tutorial`（仅战役模式 + 当前关有脚本才加载，单关/roguelite 不触发）；`_input` tap 步骤吃掉点击推进（不误出兵）；出牌成功 `_tut_on_action("card_played")` 推进；`_draw_tutorial` 覆盖层（none=全屏压暗 / 有 highlight=四矩形挖洞高亮 + 金框脉动 + 手指箭头脉动 + 气泡多行文字 + tap 提示）；结算演出期不画引导。
**范围 / 现状**：仅第 1 关有引导（其余关 tutorial.json 无条目→不触发）。手指/高亮均程序化 `_draw`。加引导 = 改 tutorial.json + i18n（不改代码）。
**验收**：单测 186/186（view+config 改动零回归）；battle smoke 干净；MCP 截图确认「新手战役」改名；**真人实机验收通过 2026-06-22**（开局气泡→圣水高亮→出兵高亮→拖牌推进→结束，第 1 关）。

> **V3-5（新手战役 + 引导）收官**：5a 框架（CampaignState + 6 教学关 + 中枢 view + battle 战役模式）+ 5b 数据驱动新手引导。单测 186/186。**遗留**：战役关 AI 难度偏高（首版占位，留后续整体大改/V3-9 平衡时调，见 [[battle-pacing-too-tense]]）。
