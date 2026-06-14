# HISTORY_ARCHIVE.md — 已完成阶段的逐步历史（V1 / V2，存档）

> 这里是 **V1（Step 0–8）与 V2（V2-1..V2-8）的详细逐步历史 + V1 期遗留章节**，已完成、通常**不必每次读**。
> 跨阶段「为什么这么做」看 [HISTORY.md](../HISTORY.md) 的决策日志；当前阶段进度也在 HISTORY.md。
> 需要追完成阶段的具体改动/踩坑时再来翻本文件。

---

## Step 4 前置语义（已确认，可开做）

> **给接手的人 / agent**：`Unit` + `Lane`（Step 4）涉及战斗结算，依赖下面两个语义。PLAN §9 未定。
> 用户已于 2026-06-06 确认，可按下列结论开始 Step 4。

1. **`attack_range` 的单位**：lane 进度 `0~1` 的比例；例如 `0.5` 表示半条 lane。
2. **`target_type` 的含义**：单位自身的地面 / 空中类型（即该单位属于 `ground` 还是 `air`），用于后续命中/筛选判断；不要把它解释为“该单位能攻击什么”。如后续需要表达攻击能力，再另加字段（如 `attack_targets`）并走配置。

> 次要（可在 Step 4 过程中细化，不卡开工）：单位攻击目标规则（同 lane 最前敌人 / 优先塔）、`direct_damage` 的 `target` 枚举、多积木结算顺序。

---

## 与原计划（PLAN_V1.md）的出入

- **新增 `SimClock` 模块**：PLAN §4 模块表未列时钟模块；因 §8 要求"第 2 步定下固定 tick 机制"而新增。Battle（Step 5）将用它驱动逻辑步进。
- **配置规模扩充**：PLAN §5 仅给 3 卡/1 单位示例；实际做了 8 卡/5 单位/1 关卡（Step 3 抽牌需要完整牌组）。数值均为可调占位。
- **ConfigLoader 不建 typed 类**：PLAN 说"转为游戏内数据"，按最小化解读为字典。
- **额外的交叉引用校验**：超出"读入并打印"的验收，属主动加固。
- **Step 4 补充单位字段校验**：`ConfigLoader` 现在校验 `attack_speed` / `attack_range` / `target_type` 等 Step 4 必用字段，其中 `attack_range` 必须在 `0.0~1.0`。
- **验证命令调整**：PLAN 设想 `--headless --quit`，实际须用 `--headless --editor --quit`（空工程无主场景）。
- **godot.cmd shim 实现返工**：见下方 Step 0 踩坑。

> 以上出入均未超出 V1 锁定范围，仅为实现层面的合理细化/加固。

---

## 待你（用户）决策 / 未决事项

**已确认（2026-05-30）**
- ✅ **逻辑 tick 频率 = 10Hz**：保持。
- ✅ **起始圣水 = 0**（空槽开局）：先按此做；将来如需半槽起手再加 `levels.json.elixir_start` 字段。

**已确认（2026-06-06）**
- ✅ **`attack_range` 语义**：lane 进度 `0~1` 的比例。
- ✅ **`target_type` 语义**：单位自身类型（ground/air），不是攻击能力。

**已确认（2026-06-07）**
- ✅ **三塔制 + 胜负规则**：见决策日志 12–16（王塔归零判负、超时比塔血、单 lane 接王塔）。
- ✅ **Step 6 技能结算口径**：见决策日志 17–21（多积木数组顺序、`direct_damage.target=first_enemy_in_lane`、`aoe_damage` 一维圆心/半径、伤害只打敌方单位、出牌指令 `(card_id, owner_id, lane_index, target_progress)`）。原 PLAN §9 遗留项至此全部定稿。

**已确认（2026-06-08）**
- ✅ **V2-1 拓扑/转火/部署**：见决策日志 24–25（侧路公主毁后转打王塔；部署仅己方半场/任意 lane，强制校验留 V2-2）。

**仍待定（V2-2 开工前定）**
- [ ] **部署半场校验落点**：在 `Player.try_play_card` 拒绝越界出兵，还是在 `SkillSystem._spawn_unit` 钳制到己方半场？（仅约束 spawn，伤害法术 direct/aoe 不受限）
- [ ] **跨 lane 河道规则**：单位是否绑定生成 lane 不可换道（决策 25 已定「任意 lane 可选」，但生成后是否锁 lane 待 V2-2 确认）。

---

## 逐步历史

### Step 0 — 项目脚手架 + git + 工具链  （commit `77909c9`）
**新增**
- `project.godot`：Godot 4.6，竖屏 720×1280、`portrait`、GL Compatibility 渲染（利于安卓）。
- 目录：`logic/ view/ ai/ config/ tests/`（空目录用 `.gitkeep` 占位）。
- `icon.svg`：占位几何图标。
- `tests/test_runner.gd`（自写 headless runner）+ `tests/test_case.gd`（断言基类）+ `tests/test_smoke.gd`（冒烟）。
- `.gitignore`（忽略 `.godot/`、`/android/`、导出产物）、`.gitattributes`（统一 LF + 二进制标记）。
- `CLAUDE.md`（操作手册）。
- `.vscode/`：`extensions.json`（推荐 `geequlim.godot-tools`）、`settings.json`（LSP + GDScript 用 Tab）、`launch.json`（F5 调试）。
- `C:\Users\user\bin\godot.cmd` shim（项目外），并把 `~\bin` 追加到用户 PATH。

**决策**
- VS Code 完整 godot-tools 集成；Godot 加入 PATH（均为用户选择）。

**踩坑与修复**
1. **godot.cmd 被 cmd 解析失败**：首版用 `Write` 写出，是 **LF 换行 + UTF-8 中文注释**，`cmd.exe` 需要 CRLF 且对非 ASCII 注释敏感 → 报一堆 `'xxx' is not recognized`。
   修复：改用 PowerShell 以 **ASCII + CRLF** 重写，注释改英文。
2. **shim 找不到 exe**：原 `dir /s` 模式把通配符放在**中间目录**（`...\GodotEngine.GodotEngine_*\Godot_v*_console.exe`），`/s` 要求起始目录是**字面路径**，匹配失败。
   修复：改为字面 base + `/s` 递归文件名：`...\Packages\Godot_v*_console.exe`。
3. **`--headless --quit` 验证失败**：报"no main scene defined"。空工程没有主场景。
   修复：用 `--headless --editor --quit` 做导入式验证。

**验收**：`godot --version`→4.6.3.stable ✅；`--editor --quit` 导入 exit 0 ✅；测试 3/3 通过 ✅；git 仓库初始化于 `main` ✅。

---

### Step 1 — ConfigLoader + 三张 JSON 配置  （commit `a632dcd`）
**新增**
- `config/cards.json`：8 张卡（knight/archers/giant/goblins/minions/fireball/arrows/zap），仅用 3 种技能积木 `spawn_unit` / `aoe_damage` / `direct_damage`。
- `config/units.json`：5 个单位（字段按 PLAN §5.2：hp/damage/attack_speed/move_speed/attack_range/target_type）。
- `config/levels.json`：`level_01`（圣水回速/上限、对局时长、双方 8 张牌组、塔血量）。
- `logic/config_loader.gd`：`ConfigLoader`，`load_all()` 读三张 JSON → 字典；结构校验 + **交叉引用校验**；错误进 `errors`，全过返回 true。
- `tests/test_config_loader.gd`：6 断言 + 1 打印验证。

**决策**
- 配置存字典、不建 typed 类。
- 扩到 8 卡/5 单位以备 Step 3。
- `attack_range`/`target_type` 等语义暂不解释（PLAN §9）。

**踩坑**：无（一次通过）。注意 Godot 4 JSON 数字可能解析为 float，但 GDScript `3.0 == 3` 为真，断言不受影响。

**验收**：测试 7/7（含打印 `cards=8, units=5, levels=1`）✅。

---

### Step 2 — Elixir 圣水系统 + SimClock 固定 tick  （本次提交）
**新增**
- `logic/sim_clock.gd`：`SimClock` 固定时间步长累加器。`TICK_DELTA=0.1s`（10Hz）、`advance(real_dt)` 把可变帧 dt 转成离散 tick 数；含 `MAX_TICKS_PER_ADVANCE=100` 追帧风暴保护、`get_interpolation_fraction()` 供显示插值。
- `logic/elixir.gd`：`Elixir` 圣水系统。按 `regen_rate`（圣水/秒）线性回涨并 `minf` 封顶；`spend()` 扣除（不足/负数拒绝且不改状态）；`get_amount()`（float，平滑显示）/ `get_int()`（floor，判可出牌）/ `is_full()`。
- `tests/test_elixir.gd`：10 测试。
- `tests/test_sim_clock.gd`：6 测试，含**帧率无关性**集成测试（同 1.0s、10帧 vs 40帧 → 同样 10 tick、同样 1.0 圣水）。

**修改**
- `CLAUDE.md`：更新"当前进度"指针。

**决策**
- 逻辑 tick = 10Hz（PLAN §8 要求第 2 步定下）。
- `elixir_regen_rate` 解释为"每秒回涨量"。
- 起始圣水默认 0（构造可传 `start_`）。

**踩坑与修复**
- **固定步长累加器的浮点漂移**：`advance(0.35)` 后余量为 `0.04999…`（二进制浮点），再 `+0.05` 落在 `0.0999…` 略小于 `0.1` → 偶发**漏 tick**（长对局会抖动）。
  修复：阈值加 `_EPSILON=1e-9` 容差（`>= TICK_DELTA - _EPSILON`），固定步长循环的标准做法。

**验收**：测试 26/26 全过（含帧率无关性证明）✅。

---

### Step 3 — Deck 循环卡组  （本次提交）
**新增**
- `logic/deck.gd`：`Deck` 循环卡组（玩家与 AI 共用）。一副 8 张：4 张在手（格位固定）、4 张在队列。`play(hand_index)` 打出某格 → 队首补入该格 → 打出的牌回队尾，返回打出的 card id。另有 `get_hand()`（返回副本）、`peek_next()`（队首预览）、`total()`。非法下标/空队列返回 null 不改状态。
- `tests/test_deck.gd`：9 测试，含「集合不变量」（任意多次出牌无丢失/重复）、精确状态追踪、与 ConfigLoader 的真实牌组集成测试。

**决策**
- **手牌格位置固定**（打出哪格补哪格），对齐皇室战争视觉/手感（Model 1）。
- **V1 不洗牌**：确定性循环，利于测试；如需开局随机化再加可选 seeded shuffle（记为后续可加项）。
- **一副 = 8 张总数**（4 手 + 4 队列），对齐 `levels.json` 的 8 张 `player_deck` 与皇室战争规则；澄清了 PLAN「8 库 + 4 手」措辞的歧义。

**踩坑**：无（一次通过）。

**验收**：测试 35/35 全过（+9 deck）✅。

---

### Step 4 — Unit + Lane 推进与碰撞  （本次提交）
**新增**
- `logic/unit.gd` + `.uid`：单位运行时状态。包含 `unit_id`、`owner_id`、`lane_index`、`progress`、血量、伤害、攻击间隔、移动速度、攻击范围、单位自身类型；支持扣血、死亡判断、攻击冷却、方向判断。
- `logic/lane.gd` + `.uid`：单 lane 纯逻辑推进与碰撞/攻击结算。每 tick 推进冷却、判断范围内最近敌人、停下攻击、未接敌则按 owner 方向推进，并在结算后移除死亡单位。
- `tests/test_unit.gd` + `.uid`：6 个测试，覆盖配置初始化、进度钳制、owner 推进方向、扣血死亡、攻击冷却、真实配置 unit。
- `tests/test_lane.gd` + `.uid`：8 个测试，覆盖加入 lane、双方方向推进、相遇互伤、攻击冷却、死亡移除、接近后战斗、最近目标选择、真实配置 lane 结算。

**修改**
- `config/units.json`：按已确认语义把所有 `attack_range` 调整为 `0.0~1.0` 的 lane 比例（例如骑士/巨人近战 `0.05`，弓箭手 `0.25`）。
- `logic/config_loader.gd`：单位配置校验补齐 Step 4 必用字段，并校验 `attack_range` 范围与 `target_type` 枚举。
- `tests/test_runner.gd`：测试脚本加载失败时计入失败，避免坏测试文件被静默跳过。
- `AGENTS.md`：同步当前 worktree、开发分支、Step 4/5 指针与 Step 4 语义。

**决策**
- 逻辑坐标采用全局 lane 进度：`OWNER_PLAYER` 从 `0` 向 `1` 推进，`OWNER_OPPONENT` 从 `1` 向 `0` 推进。
- `move_speed` 解释为 lane 进度/秒；`attack_range` 解释为 lane 进度比例；`attack_speed` 解释为攻击间隔（秒/次）。
- Lane 中攻击目标为自身攻击范围内最近敌方单位；双方同 tick 中已排定的攻击统一结算，因此相遇时可以互相掉血。

**踩坑与修复**
1. **GDScript 跨脚本类型标注/推断不稳定**：新脚本尚未注册 `.uid` 时，`Unit` 类型标注和 `:=` 推断会导致测试脚本解析失败。
   修复：`Lane` 内部保持动态参数风格，关键局部变量显式转 `int/float`；随后用 `--headless --editor --quit` 让 Godot 注册 `Unit` / `Lane` 全局类并生成 `.uid`。
2. **测试 runner 漏报坏测试文件**：脚本加载失败原先只 `push_error`，未计入失败。
   修复：加载失败时增加总数和失败数，并记录失败信息。
3. **攻击范围边界浮点误差**：距离理论上等于 `attack_range` 时可能因二进制浮点略大，导致一侧未出手。
   修复：Lane 范围判断加入 `_EPSILON=1e-6` 容差。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 49/49 全过 ✅
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`Unit` / `Lane` 注册成功 ✅

---

### Step 5 — Tower + Battle 胜负判定  （本次提交）
**前置语义（用户 2026-06-07 确认）**
- 三塔制：每方 1 王塔 + 2 公主塔。
- 王塔归零 → 该方立即负；公主塔毁不结束对局，只计入剩余塔血。
- 超时（match_duration）→ 比双方剩余塔血总和，多者胜、相等判平。
- V1 单 lane 两端接双方王塔，单位推到底直接削王塔。

**新增**
- `logic/tower.gd` + `.uid`：`Tower` 纯血量容器。`kind`（king/princess）、`owner_id`、`max_hp/hp`；`is_king()` / `is_alive()` / `is_destroyed()` / `take_damage()`（钳零、非正伤害与已毁后 no-op）。不含像素/位置。
- `logic/battle.gd` + `.uid`：`Battle` 战斗总控。持双方塔列表 + 王塔引用 + lane 列表 + `match_duration`/`elapsed`/`result`。`step(dt)` 先结算各 lane 再计时与判负（对局结束后 no-op）；`build_v1_single_lane(level)` 按配置搭「双方各 3 塔 + 单 lane 接双王塔」并返回 lane；`total_tower_hp()` / `remaining_time()` / `is_over()`。胜负枚举 `RESULT_ONGOING/PLAYER_WIN/OPPONENT_WIN/DRAW`。跨脚本一律 `preload` 加载，不依赖 class_name 全局注册。
- `tests/test_tower.gd` + `.uid`：6 测试（建塔、公主非王、扣血、钳零摧毁、非正伤害 no-op、已毁后 no-op）。
- `tests/test_battle.gd` + `.uid`：10 测试（建三塔、削敌王塔、王塔归零判玩家胜、对手镜像胜、公主毁不结束、超时比塔血胜、超时平、结束后不再推进、停在塔攻击范围边界不穿塔、真实配置 level_01+骑士集成）。

**修改**
- `logic/lane.gd`：**加性扩展**。新增可空两端塔引用 `tower_at_start`（守 progress 0）/ `tower_at_end`（守 progress 1）+ `set_towers()`；`tick()` 在无敌方单位可打时改打尽头敌塔；`_move_unit()` 增加「停在敌塔攻击范围边界」夹取；新增 `_find_enemy_tower_in_range()` / `_enemy_tower_for()`（按方向取尽头敌塔且需异阵营）/ `_tower_position()`。不接塔时全部 null → 与 Step 4 行为完全一致。
- `HISTORY.md` / `CLAUDE.md` / `AGENTS.md`：进度指针与决策同步。

**决策**：见上方决策日志 12–16。

**踩坑与修复**
- 无（一次通过）。沿用 Step 4 经验提前规避：① 跨脚本统一 `preload`，不靠 class_name 全局名，先 `--editor --quit` 注册 `Tower`/`Battle` 并生成 `.uid`；② 攻击范围边界判断复用 `_EPSILON` 容差；③ Lane 改动保持加性，旧 8 个 lane 测试零回归。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`Tower` / `Battle` 注册成功 ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 65/65 全过（+6 tower +10 battle，旧 49 零回归）✅

---

### Step 6 — SkillSystem 三积木  （本次提交）
**前置语义（用户 2026-06-07 确认）**：见决策日志 17–21（多积木数组顺序、`direct_damage.target=first_enemy_in_lane`、`aoe_damage` 一维圆心/半径、伤害只打敌方单位、出牌指令 `(card_id, owner_id, lane_index, target_progress)`）。

**新增**
- `logic/skill_system.gd` + `.uid`：`SkillSystem` 解析卡牌 `skills` 数组并执行。`play_card(card_id, owner_id, lane_index, target_progress)` 按数组顺序逐个结算（卡不存在返回 false）；`_spawn_unit`（在出牌位置生成 `count` 个该单位，owner=出牌方）、`_direct_damage`（命中 `_first_enemy_in_lane` = 最逼近出牌方塔的敌方单位，无则空放）、`_aoe_damage`（沿 lane 命中 `|progress-center|<=radius` 的敌方单位）。伤害类只打敌方、不打塔；**不校验/扣圣水**。跨脚本一律 `preload`。
- `tests/test_skill_system.gd` + `.uid`：11 测试（生成数量/owner/位置、未知单位 no-op、直伤选玩家/对手各自最前敌、无敌空放、AOE 半径边界命中、AOE 不误伤己方、多积木全执行、未知卡 false、真实卡入对局并随 tick 推进）。

**修改**
- `logic/battle.gd`：新增 `get_lane(lane_index)`（按 `lane_index` 查 lane），供 SkillSystem 定位 lane。加性，无回归。
- `HISTORY.md` / `CLAUDE.md` / `AGENTS.md`：进度指针与决策同步。

**决策**：见决策日志 17–21。补充实现细节：`SkillSystem` 依赖注入 `(ConfigLoader, Battle)`，自身不持有圣水/卡组逻辑；AOE/直伤通过 `lane.get_units()` 读单位、`take_damage` 改血，死亡单位由后续 `lane.tick` 统一移除（直伤目标选择已过滤 `is_alive`）。

**踩坑与修复**
- 无（一次通过）。AOE 边界沿用 `_EPSILON` 容差；多积木/自定义半径测试用「向已加载的 `loader.cards` 注入内存卡」实现，不污染 `config/*.json`。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`SkillSystem` 注册成功 ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 76/76 全过（+11 skill_system，旧 65 零回归）✅

---

### Step 7 — 显示层 MVP（白膜 + UI）
> 第一步带画面。按「逻辑/显示分离」拆成两段：**7a** 先补可测的逻辑编排层，**7b** 再搭 Godot 画面并真跑验证。
> 用户 2026-06-07 确认的 MVP 口径：①对手被动（只有静止三塔、不出牌，AI 留到 Step 8）②单 lane ③出牌两段式（先点卡再点落点，落点限己方半场 progress 0~0.5）④竖屏白膜：己方在下、敌方在上，近战方块/远程圆/建筑三角，蓝=己方红=对手。

#### 7a — 对局编排层 Player + Match（本次提交）
**新增**
- `logic/player.gd` + `.uid`：`Player` 一方对局状态（owner + 注入 Elixir/Deck/ConfigLoader/SkillSystem）。`try_play_card(hand_index, lane_index, target_progress)` 串起「圣水门槛 → 扣圣水 → 循环卡组 → 触发技能」（不足/下标非法则 false 且不改状态）；`can_play()` 供 UI 置灰；`regen(dt)`、`card_cost()`。**玩家与 AI 共用此出牌入口**（对称性落点）。
- `logic/match.gd` + `.uid`：`Match` 一局总驱动。组合 Battle + 两个对称 Player + SkillSystem + SimClock；`setup(level_id)` 按配置搭好（双方各 3 塔 + 单 lane、起始圣水 0）；`update(real_dt)` 把可变帧 dt 经 SimClock 折成固定 10Hz tick，逐 tick 双方圣水回涨 + `battle.step`，对局结束即停；`is_over()`/`get_result()`/`get_interpolation_fraction()`（供显示插值）。
- `tests/test_player.gd` + `.uid`：6 测试（圣水不足拒绝、出牌扣费+生成+落点、卡组循环、can_play 反映圣水、回涨、非法下标 no-op）。
- `tests/test_match.gd` + `.uid`：6 测试（搭双方 Player+battle、起始圣水 0、双方对称回涨、**帧率无关性**一大帧 vs 多小帧一致、update 驱动战斗使单位前进、结束后 update 不再推进）。

**决策**：`Battle` 保持只管塔/lane/胜负不膨胀；圣水门槛与对局循环放新的 `Player`/`Match`（PLAN §4 列了 Player；Match 是 §3 数据流「逻辑层」侧的总驱动）。SkillSystem 仍不碰圣水。起始圣水 0（决策日志 7）。

**踩坑与修复**
1. **`match.gd` 的 `var n := clock.advance(dt)` 解析失败**：`clock` 是无类型 var，跨脚本方法返回类型推断不出 → `Cannot infer the type of "n"`（同 Step 4 的 `:=` 不稳定）。修复：显式 `var n: int = ...`。
2. **test_runner 汇总会「假绿」**：当 `match.gd` 解析失败时，`test_match.gd` 预载到的是坏 GDScript，`MatchScript.new()` 返回 null、后续 `m.player` 等抛**运行时** SCRIPT ERROR，但这些错误不会写入 `_failures`，runner 仍把用例计为 PASS、汇总显示 88/88。**教训：逻辑层验收不能只看汇总，必须 grep stderr 的 `SCRIPT ERROR`/`Parse Error`/`Compilation failed`**。已据此确认修复后 0 错误行。（**已跟进加固**，见下方「测试基建加固 — test_runner 防『假绿』」。）

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → 无解析错误，`Player`/`Match` 注册并生成 `.uid` ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → **SCRIPT ERROR 行数=0**，88/88 全过（+6 player +6 match，旧 76 零回归）✅

#### 7b — Godot 显示层（白膜 + UI）（本次提交）
**新增**
- `view/battle_scene.gd` + `.uid` + `view/battle_scene.tscn`：主场景。`_ready` 建 `Match` 并程序化搭白膜；`_process(delta)` → `match.update(delta)` 后每帧只读逻辑状态作画。三塔=三角（红=对手在上 / 蓝=己方在下）+ 绿血条；单位近战=方块、远程=圆（按 `attack_range` 粗分），按 `progress` 映射屏幕 y、视图侧 `lerp` 平滑；圣水条 + 4 手牌按钮（显示卡 id+费用、`can_play` 置灰）；胜负横幅读 `battle.result`。两段式出牌：点卡选中 → 点己方半场（progress 0~0.5）→ `player.try_play_card`。坐标 `0~1`→像素映射只活在本层。
- `project.godot`：设 `run/main_scene=res://view/battle_scene.tscn`。

**决策 / 范围**
- 对手被动（不出牌，AI 留 Step 8）、单 lane、落点限己方半场——均按 2026-06-07 确认口径。
- 视图侧用「`lerp` 趋近目标」做平滑（够顺够简），未用 SimClock 子 tick 严格插值；`get_interpolation_fraction()` 已就绪，需要再升级。
- **UI 全英文（决定，用户 2026-06-07 确认）**：手牌显示卡 id（knight/fireball…）而非中文 name，胜负横幅与数字也全英文，整个显示层不出现中文。故 V1 **不引入中文字体**——既规避 PLAN §7 的「中文豆腐块」问题，又零字体资源依赖。将来若要显示中文 name，再导入一个 CJK `.ttf` 即可（届时仅改显示层，逻辑不动）。

**踩坑与修复**
1. `battle_scene.gd` 的 `var r := match_obj.get_result()` 解析失败（同 `:=` 跨脚本推断坑）→ 显式 `var r: int = ...`。
2. 全屏背景/装饰 `ColorRect` 默认拦截鼠标 → 统一 `mouse_filter=IGNORE`，让点击穿透到 `_unhandled_input` 做部署；按钮保持默认 STOP。

**验收（真跑 Godot 渲染，非仅 headless）**
- `--headless --quit-after` 跑主场景：`battle_scene` 0 脚本错误 ✅
- 渲染截图（临时 runner 出牌后存 PNG，验后删）：白膜场地 / 三塔+血条 / 单位 / 圣水条 / 手牌——出两张牌后手牌正确轮换为 `minions·fireball·giant·goblins` 且 `giant[5]` 因圣水不足置灰，确认「部署→推进→卡组循环→圣水扣费」闭环 ✅
- 强制残血王塔 + 部署骑士截图：王塔归零变灰、空血条、显示 **YOU WIN** 横幅，确认「推塔→出胜负」✅
- 全量单元测试仍 88/88（显示层无单测，逻辑零回归）✅

#### 测试基建加固 — test_runner 防「假绿」（2026-06-07，跟进 7a 踩坑 #2）
> 把"逻辑脚本编译失败时 runner 仍全绿"的隐患，从"靠人工 grep stderr"升级为"runner 自动判失败、非 0 退出"。只改 `tests/test_runner.gd`，零新依赖（守住"逻辑层必测、零外部依赖"纪律）。

**根因**：坏逻辑脚本（解析/编译失败）被测试 `preload` 后，`Script.new()` 返回 null；其后对 null 的调用抛的是**运行时** SCRIPT ERROR——GDScript 无 try/catch、运行时错误只静默中止当前方法、进程 exit 仍 0——这些错误不写入 `_failures`。实测两种"假绿"表现：① **soft 编译错误**（如 `Cannot infer the type`）→ 预载方测试文件仍能加载、用例被计为 PASS；② **hard 语法错误** → 预载方测试文件解析失败、`load()` 后非 null 但无可见 `test_*` 方法 → 整文件被静默跳过、根本不计数。两者汇总都「全绿」。

**方案（调研 4 个候选后择优）**
- ✅ **启动预检 `res://logic`（核心修复）**：runner 跑测试前遍历 `logic/*.gd`，`load()` 后判 `can_instantiate()`；为 false（或 load 返回 null）即坏脚本 → 打印点名 + **整体非 0 退出、不放行**。`can_instantiate()==false` 恰好等价于"被 preload 后 `.new()` 返回 null"，与根因一一对应。
- ✅ **测试脚本 `can_instantiate()` 校验**：发现/加载测试文件时原仅判 `== null`，现加判 `can_instantiate()`，堵住表现 ② 的静默跳过。
- ✅ **每个测试 `script.new()` 加 null 守卫**：实例化失败即计失败，避免后续访问 `_failures` 再抛运行时错误被吞。
- ❌ **放弃"读引擎 SCRIPT ERROR 计数"**：Godot 4 无公开的运行时错误计数 API，GDScript 也无 try/catch；实测坏脚本 `.new()` 触发的 SCRIPT ERROR 静默中止、exit 仍 0 → 此路不通。
- 选 `can_instantiate()` 而非 `GDScript.reload()`：两者实测都能判坏（reload 坏脚本返回 `ERR_PARSE_ERROR=43`、好脚本 `OK=0`；can_instantiate 坏=false、好=true），但 reload 会重新编译有副作用，can_instantiate 只读首次 load 的编译结果、无副作用且语义更贴合。实测全部 11 个真实 logic 脚本两法均判「好」，零误报。

**自验（临时坏脚本 + 对应测试，验后即删）**
- 造 `logic/_selftest_broken.gd`（分别试 hard 语法错误、soft `var n := <untyped>.method()` 类型推断错误）+ `tests/test_selftest_broken.gd`（复刻 `test_match` 的"preload 后直接 `.new()` 用、不先 null 断言"）。
- **旧 runner**：EXIT=0、汇总 88/88（坏用例被静默跳过）→ 复现假绿。
- **新 runner**：预检捕获、点名 `_selftest_broken.gd`、EXIT=1（hard 与 soft 两种错误均被拦下，soft 即本节根因里的 `Cannot infer the type of "n"`）。
- 删除临时文件后跑全量回归。

**验收**：`HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → **EXIT=0、88/88 全过、SCRIPT ERROR 行数=0、预检零噪声**（健康时预检不打印）✅

#### 7 过程备忘 — 后台任务与本会话共用 worktree（2026-06-07，忠实记录）
> Step 7 期间用户启动了上面的「test_runner 加固」后台任务，它与本会话**共用同一个 git worktree**（并非独立 worktree）。如实记下，免得以后人/agent 困惑。
- **探针文件一度混入 7a 提交**：任务为自验加固效果，在 `logic/` 放了临时坏脚本 `_probe_broken.gd`、根目录放了 `zzz_probe.gd`。本会话提交 7a 时 `git add -A` 把这两个文件一并卷入；随即 `git rm --cached` + `git commit --amend` 把它们从 7a 提交剔除（文件留在磁盘供任务继续用，后由任务自行清理删除）。
- **改动混在同一工作区**：任务完成后，其 `tests/test_runner.gd` 加固与 HISTORY 记录，和本会话 7b 的 `view/*`、`project.godot`、HISTORY 改动同处一个未提交工作区，提交时按文件归属分开（runner 加固代码 → 独立提交；view/项目配置/HISTORY → 7b 提交）。
- **教训**：后台任务可能与主会话共用同一 worktree；`git add -A` 前务必先 `git status` 看清每个文件归属，分别提交，别把对方的活卷进自己的提交。

---

### Step 8 — AIController 规则 AI（本次提交）
**前置规则（用户 2026-06-07 确认）**：见决策日志 22（简单进攻型、阈值 6、最贵可用兵、法术不空放、自家塔前部署、出牌间隔 1s、确定性无随机）。

**新增**
- `ai/ai_controller.gd` + `.uid`：`AIController(match, config)`。`tick(dt)` 由 Match 固定 tick 循环驱动：冷却中跳过，否则 `_decide()`——圣水 `<6` 则等；否则在手牌里选「出得起且有用」的最贵牌（兵随时可出、法术仅在对面有敌方单位时可出，避免空放），兵部署 `progress 0.9`、法术落最前敌人处，经 `opponent.try_play_card` 出牌；出牌后进 `1.0s` 冷却。`_has_spawn()`/`_lead_enemy_progress()` 辅助。无随机。
- `tests/test_ai_controller.gd` + `.uid`：6 测试（圣水不足等待、出最贵可用兵+部署位+扣费、冷却拦截再出、无敌跳过法术改出兵、有敌则放法术削敌、**整局 AI 自驱跑到分胜负且削到玩家王塔**）。

**修改**
- `logic/match.gd`：加 `opponent_controller`（可空、鸭子类型）+ `set_opponent_controller()`；`update()` 的每 tick 循环里在 `opponent.regen` 后、`battle.step` 前调用 `opponent_controller.tick(TICK_DELTA)`。Match 不 import AIController（保持逻辑层不依赖 ai 层，控制器注入）。不注入则对手被动（= Step 7 行为）。
- `view/battle_scene.gd`：`_ready` 里 `set_opponent_controller(AIControllerScript.new(match_obj, loader))` 接入 AI——MVP 画面现在有会出牌的对手。

**决策**：见决策日志 22。补充：AI 驱动放在 Match 的固定 tick 内（保证与圣水/战斗同频、帧率无关），而非显示层每帧——否则 AI 决策会绑渲染帧率。控制器用注入而非 Match 直接 new，守住「逻辑层不依赖 AI 层」与「玩家 AI 对称」。

**踩坑与修复**：无（一次通过）。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`AIController` 注册 ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 94/94 全过、SCRIPT ERROR 行=0（+6 ai_controller，旧 88 零回归）✅
- 真跑渲染截图：AI 自驱部署红方单位、与玩家蓝方单位在 lane 内对推 ✅

---

## V2 阶段

> 环境切换说明：自此阶段起开发机为 **Windows**（工程根 `F:\godotProject`，PowerShell，godot 4.6.3 经 `~\bin\godot.cmd` shim 在 PATH）。HISTORY/PLAN 中 Mac 路径(`/Users/jeffchen/...`)与 bash 命令为历史记录，Windows 下命令一律翻译为 PowerShell。GitHub 远端 git/gh 走本机代理 `127.0.0.1:7897`。

### V2-1 — 3-lane 逻辑层 + 侧路公主倒后转打王塔（纯逻辑）  （本次提交）
**前置语义（用户 2026-06-08 确认）**：见决策日志 24–25（侧路公主毁后转打王塔；部署仅己方半场/任意 lane，强制校验留 V2-2）。

**范围边界**：仅做 3-lane 的 `Battle`/`Lane` 拓扑与转火逻辑 + 单测；**不动** `Match.setup`（仍单 lane）、显示层、AI——「Match 接通 3 lane + 出牌选 lane + AI 最小适配 + 部署半场校验」整体留 **V2-2**（对齐 PLAN_V2 验收划分：V2-1=单测、V2-2=编辑器可玩）。

**新增/修改**
- `logic/lane.gd`：加兜底王塔 `king_at_start/king_at_end` + `set_king_fallback()`；`_enemy_tower_for` 改为「主塔活着打主塔，主塔（侧路公主）毁则转打该端兜底王塔」；塔位置改 `_enemy_tower_end(unit)` 按单位方向取（替换原 `_tower_position(tower)` 的对象身份判断——否则兜底王塔会被误算到错误端，是必修 bug）。
- `logic/battle.gd`：加 `build_v2_three_lanes(level)`——lane 0 左公主↔公主、lane 1 中王↔王、lane 2 右公主↔公主；侧路挂同一对王塔兜底；6 塔全计入 `player/opponent_towers`，胜负与超时比塔血规则不变。
- `tests/test_battle_v2.gd`：新增 12 个测试（拓扑/中路打王/侧路打公主/**公主毁转打王**/共享王塔双重承伤/三 lane 独立推进/跨 lane 不交战/破王取胜/超时比 6 塔血/平局/真实配置烟雾）。

**决策**：见决策日志 24–25。补充：兜底王塔与主塔同处 lane 端点（progress 1.0/0.0），公主一倒，原本停在 `端点∓attack_range` 攻击公主的单位下一 tick 即对同位置王塔在射程内、自动转火；王塔的「物理靠后」由显示层（V2-2+）做视觉偏移，逻辑层用一维端点足矣。

**踩坑与修复**
1. `var before := battle.opponent_king.hp` 解析失败：`opponent_king` 是 Variant，`:=` 无法从其成员推断类型 → 改 `var before: float = ...`。
2. 独立性测试初版 10 tick（move 0.5 仅走到 0.5，未达 0.9 射程）误判「公主未被削」→ 增到 30 tick 让单位走到边界并出手。

**验收**：
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **106/106 全过**、exit 0（+12 battle_v2，旧 94 零回归）✅
- `godot --headless --quit --path F:\godotProject` 工程加载 exit 0 ✅

### V2-2 — 3-lane 接通（Match + 显示层 + 出牌选 lane + AI 最小适配）  （本次提交）
**前置语义（用户 2026-06-08 确认）**：见决策日志 26–28（越界部署拒绝、AI 固定中路、tap-to-place 选 lane）。

**新增/修改**
- `logic/match.gd`：`setup()` 由 `build_v1_single_lane` 改 `build_v2_three_lanes`——实际对局变 3 lane。
- `logic/player.gd`：`try_play_card` 加部署半场校验（决策 26）——含 `spawn_unit` 的兵牌落点须在出牌方己方半场（玩家 `[0,0.5]`、对手 `[0.5,1.0]`），越界返回 false、不扣圣水/不抽牌；纯法术不受限。新增 `_spawns_troops()` / `_deploy_allowed()`，preload `UnitScript` 取 owner 常量。
- `ai/ai_controller.gd`：`LANE_INDEX 0→1`（固定中路，决策 27），出兵与感知敌情都在中路。
- `view/battle_scene.gd`：单 lane → 3 lane。`LANE_X` 标量改 `LANE_XS=[160,360,560]` 三列；`_build_field` 画 3 道 + 各自己方半场/中线；`_build_towers` 把 6 塔按 `[king中, 左公主, 右公主]` 摆 3 列；`_sync_units` 遍历 3 lane 定位；输入加 `_lane_from_x()` 按点击 x 归属最近列，`_unhandled_input` 改为出到选中 lane。
- `tests/test_ai_controller.gd`：`_opponent_units` 与放敌人 lane 由 0 改 1（跟随 AI 中路）。
- `tests/test_player.gd`：+4 部署校验测试（越界拒绝/边界 0.5 允许/纯法术可打敌方半场/对手越界拒绝）。
- `view/battle_scene.gd`：**运行期事件日志**（`LOG_EVENTS` 开关，仅显示层）——MATCH START / SELECT / PLAY(含圣水增减、被拒原因) / SPAWN / DEATH / TOWER HIT / TOWER DOWN / RESULT，带对局时间戳，打到 Output 面板。白膜阶段肉眼分不清兵种/战况，靠日志观测；**逻辑层零改动、headless 单测不受影响**（view 不进测试）。用户反馈（决策见下）：实机/画面验收以后优先真人执行。

**范围边界**：表现仍白膜（贴图/动画/音频是 D 模块 V2-3+）；AI 仍单一难度、只打中路（完整 lane 攻防是 V2-6）。

**决策**：见决策日志 26–28。补充：半场校验放对称入口 `Player.try_play_card`，玩家与 AI 同受约束（AI 在 0.9 出兵属对手半场 `[0.5,1.0]`，合法）；显示层落点已 `minf(_, DEPLOY_MAX)` 钳在 0.5，正常点击不会触发拒绝，逻辑层校验是兜底。

**踩坑与修复**：无（test_match 因 lane 0 仍在、玩家在己方半场 0.1 出牌而零回归；仅 AI/player 测试随中路与新规则相应更新）。

**验收**：
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过**、exit 0（+4 player 部署校验，旧 106 零回归；含 `test_full_match_with_ai_resolves` 在 3-lane 下 AI 自驱正常分胜负）✅
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，`battle_scene.gd` 无 parse/编译错误 ✅
- `godot --headless --path F:\godotProject` 实跑游戏循环数秒 → 无 SCRIPT ERROR（3-lane 场景 + AI 自驱运行期干净）✅
- **GUI 实机验收（截图核验）**：3 lane + 6 塔（中王大/两侧公主小）布局正确；点选左/右 lane 出 goblins，蓝方单位分别落到左/右路并推进、攻击对手对应公主塔；AI 红方走中路；破王出 YOU/LOSE 横幅 ✅
- **平衡观察（留 V2-8）**：headless 量得「人类挂机、AI 自驱」一局 AI 6.1s 首出兵、王塔 7.6s 首次受伤、19.8s 破王。因中路 lane 直通王塔无公主保护，单路直推威胁很大；非 bug（决策 24 拓扑使然），数值/河道平衡到 V2-8 统一处理。

### V2-3 — 程序化美术换皮（仅显示层）  （本次提交）
**前置决策（用户 2026-06-08 确认）**：美术来源选「**程序化区分**」——不引外部素材，view 层按兵种给不同形状/大小/朝向，塔与背景程序化美化。理由：零依赖、零导入/授权、最快让兵种可辨；逻辑层零改动正好验证「逻辑/显示分离 → 换皮零成本」。

**修改（全部在 `view/battle_scene.gd`）**
- **单位按兵种造型**：新增 `UNIT_VIS` 表——巨人=大八边形(24)+内圈铠甲、骑士=盾形(16)、弓箭手=小圆(12)+远程白点、哥布林=小尖三角(12)、亡灵=菱形(13)+两翼+**地面阴影且机体抬高**(空中一眼可辨)。队伍色作主体填充辨敌我；形状/大小辨兵种；**朝向按推进方向翻转**（我方朝上/对手朝下）。新增 `_unit_shape` / `_flip_y` / `_scale_pts` 辅助，`_make_unit_node` 返回 `Node2D`（多部件）。
- **塔造型**：方形塔身 + 描边；**王塔顶城垛、公主塔尖顶**；摧毁置灰由 `body.color` 改 `body.modulate`（body 现为 Node2D）。
- **背景**：草绿底 + 敌(淡红)/我(淡蓝)半场分区 + 三 lane 通道描边 + **横贯河道 + 每 lane 木桥**（把部署分界线可视化）。

**范围边界**：动画/投射物/AOE 特效/攻击受击反馈是 **V2-4**；音频/主菜单/结算是 **V2-5**；本步只换静态造型。仍无外部素材文件、无 `.import`、无授权负担。

**验收**
- 逻辑层零改动；`godot --headless ... test_runner.gd` → **110/110**（视觉换皮，无新单测，旧测零回归）✅
- `godot --headless --path F:\godotProject` 实跑 → `_ready` 跑通、无 SCRIPT ERROR ✅
- **GUI 视觉验收交用户**（按新纪律：实机/画面验收由真人在编辑器执行；见决策日志「人工验收原则」）。

### 工具链 — 引入 Godot AI MCP（表现层辅助）
**背景**
- 进入 V2 D 模块后，后续 V2-4 / V2-5 会集中处理动画、特效、UI、截图、运行时日志与编辑器场景状态。纯逻辑阶段的 CLI + 单测仍足够，但表现层排查需要更直接的编辑器联动。
- 调研 `godot-mcp-pro`、`tomyud1/godot-mcp`、`hi-godot/godot-ai` 后，优先选择 **Godot AI**：免费 MIT、明确支持 Codex / Claude Code、工具面覆盖场景树/日志/截图/测试/节点和 UI 操作，且工具数量相对克制。

**来源**
- GitHub：https://github.com/hi-godot/godot-ai
- 导入版本：`2.6.1`（下载源码 commit `5818173` / tag `v2.6.1`）

**项目内新增/修改（进 git）**
- `addons/godot_ai/`：Godot 编辑器插件本体。
- `project.godot`：
  - `[editor_plugins] enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")`
  - `[autoload] _mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"`（插件首次加载后自动加入）
- `AGENTS.md`：新增 Godot AI MCP 的使用方法、前提与守则。
- `HISTORY.md`：记录本节。

**项目外配置（不进 git）**
- `uv`：通过 winget 安装 `astral-sh.uv`，版本 `0.11.19`。当前 Codex shell 若 PATH 未刷新，可临时前置 `C:\Users\user\AppData\Local\Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe`。
- Codex 用户配置：`C:\Users\user\.codex\config.toml` 增加 `[mcp_servers."godot-ai"] url = "http://127.0.0.1:8000/mcp"`。
- Claude Code 用户配置：`claude mcp add --scope user --transport http godot-ai http://127.0.0.1:8000/mcp`，写入 `C:\Users\user\.claude.json`。
- 用户环境变量关闭遥测：`GODOT_AI_DISABLE_TELEMETRY=true` / `DISABLE_TELEMETRY=true`。

**使用方法**
- 先打开 Godot 编辑器：`godot --path F:\godotProject -e`。Godot AI MCP server 由编辑器插件启动；关掉编辑器后 MCP 会断开。
- 正常连接时：
  - MCP HTTP：`127.0.0.1:8000`
  - Godot WebSocket：`127.0.0.1:9500`
  - Claude Code 检查：`claude mcp list` 应显示 `godot-ai ... ✓ Connected`
- 若网络下载依赖，命令行使用 Clash Verge 系统代理：`HTTP_PROXY=http://127.0.0.1:7897` / `HTTPS_PROXY=http://127.0.0.1:7897`。

**踩坑与修复**
1. `uv` 用 winget 装完后当前 shell 的 PATH 未刷新；本次安装用完整 WinGet 包目录临时前置 PATH 继续执行。
2. 插件在 `--headless` 下会打印 `MCP | plugin disabled in headless mode`，这是设计行为；必须用 Godot 编辑器 GUI 启动 server。
3. 用 `Start-Process powershell ...` 嵌套设置环境变量时，Godot 进程没有拿到 `uvx` PATH，日志报 `MCP | no server found — install uv or run: pip install godot-ai`。改用显式环境启动后，日志显示 `MCP | started server` 与 `MCP | connected to server`。
4. 临时诊断日志 `godot_ai_live.log` 属本地排查产物，不纳入 git。

**验收**
- `uvx godot-ai --version` → `godot-ai 2.6.1` ✅
- Godot 编辑器启动后端口检查：`127.0.0.1:8000` / `127.0.0.1:9500` 均监听 ✅
- `claude mcp list` → `godot-ai: http://127.0.0.1:8000/mcp (HTTP) - ✓ Connected` ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过** ✅

### 工具链 — 环境复现指南与 Windows setup 脚本
**背景**
- Godot AI MCP 的插件本体已经进入项目 git，但 agent 客户端注册、`uv`、用户环境变量、Godot/gh/git 等本机工具安装都属于机器级状态；换电脑后不会随仓库自动恢复。
- 因此新增项目级环境指南，类似 Node 项目的 `package.json`/README 角色：说明哪些东西在 git，哪些东西需要每台机器单独装和配。

**新增**
- `docs/ENVIRONMENT.md`：记录 Godot 4.6.3、Godot AI `2.6.1`、`uv`、Codex/Claude MCP 注册、代理、运行测试、打开编辑器、MCP 使用与排错方式。
- `scripts/setup-godot-ai.ps1`：Windows PowerShell 辅助脚本。检查 `addons/godot_ai/plugin.cfg`，检查 `godot`/`git`/`uv`，必要时通过 winget 安装 `astral-sh.uv`，设置 Godot AI 遥测关闭变量，并按需写入 Codex 与 Claude Code 的用户级 MCP 配置。

**决策**
- OS 依赖必须写清楚：Windows 使用 PowerShell + winget + `.ps1`；macOS 使用 Terminal + Homebrew，按 `docs/ENVIRONMENT.md` 手动执行 `brew install --cask godot` / `brew install git uv gh` 并配置 MCP。
- 不把 `C:\Users\user\.codex\config.toml`、`C:\Users\user\.claude.json`、用户环境变量或 winget/uv 安装目录纳入 git；这些是每台机器的本地状态。
- `addons/godot_ai/`、`project.godot` 插件启用、`docs/ENVIRONMENT.md`、`scripts/setup-godot-ai.ps1` 才是项目可追踪部分。

**验收**
- PowerShell parser 检查 `scripts/setup-godot-ai.ps1` 通过，无语法错误。
- `git diff --check` 通过。
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过** ✅

### V2-4 — 动画与特效（仅显示层，路线 A 纯显示层还原）  （本次提交）
**前置决策（用户 2026-06-09 确认）**：见决策日志 30——事件来源走**路线 A：纯显示层、零改逻辑**。逻辑层一行不改，显示层逐帧读状态 + 复刻「目标选择」还原攻击/投射物；玩家法术按点击点/直伤目标精确出特效，AI 法术按「同帧多单位聚集掉血」推断爆点（近似）。

**范围边界**：**只改 `view/battle_scene.gd`**；`logic/*`、`ai/*`、`config/*` 零改动 → 单测仍 110/110。音频/主菜单/结算是 V2-5。仍无外部素材、无 `.import`、无授权负担。

**修改（全部在 `view/battle_scene.gd`）**
- **受击闪白**：逐帧 diff 单位 hp，下降即把主体 `body.color` 向白 lerp + 轻微放大（`modulate>1` 在 GL Compatibility 不保证提亮，故用颜色 lerp，稳定可见）。
- **攻击顶刺**：新增 `_view_find_target` 复刻 `Lane._find_enemy_in_range`（范围内最近敌方单位）+ 尽头敌塔判定来识别「交战」；交战时按 `attack_speed` 节拍把机体朝目标方向顶出再回落（`beat` 预热使接敌当帧即出手，对齐逻辑「接触即攻击」；真伤判定仍以受击闪白为准，二者解耦）。
- **远程投射物**：`attack_range ≥ 0.15`（仅弓箭手 0.25）判远程，攻击节拍时从自身朝目标当前位置发飞镖，按距离折算飞行时长，命中留烟。
- **死亡消散**：单位从 lane 消失时不再立即 `queue_free`，先冒烟，再缩小+淡出+旋转 0.35s 后释放（`dying_units` 承接，逻辑单位早已被 `_remove_dead` 移除）。
- **AOE/法术爆点**：玩家法术（可靠，`_play_spell_fx` 直接知道卡/落点）——火球落点橙色扩张爆盘、电击青蓝放射火花、射箭落箭+尘；直伤落在「最逼近自己塔的敌方单位」处（`_first_enemy_screen_pos_for`，与 `SkillSystem` 选择一致）。AI 法术（显示层看不到其经 `opponent_controller.tick` 的出牌）——按「同帧某 lane ≥2 个玩家单位聚集掉血」推断一次爆点（近似，0.5s 节流 + 0.25 聚集窗）。
- **塔受击/摧毁**：受击抖动 + 白色火花（按 flash 节流）；摧毁瞬间碎块向上爆裂、受重力下落、淡出 + 塔身置灰 + 大抖动。
- 新增轻量特效系统：`fx_layer`（盖在单位/塔之上）+ `projectiles`/`effects`/`dying_units` 列表 + 通用 `_update_effects`（扩张/淡出/速度+重力/自旋）、`_update_projectiles`、`_update_dying`。动画时长一律按渲染 `delta` 推进（显示层插值，**不绑逻辑 tick**——游戏速度仍由 `SimClock` 固定 tick 决定）。

**决策**：见决策日志 30。补充：动画与随机散布（抖动、碎块）仅活在显示层，不影响逻辑确定性；攻击节拍在显示层近似计时，与逻辑 tick 的精确伤害时刻可能微小漂移，但受击闪白由真血量 diff 驱动，锚定真实掉血时刻。

**踩坑与修复**
- 临时 headless 探针时序坑：场景 `_ready` 要等加入树后的首帧才跑，探针在 `_initialize` 即访问 `scene.match_obj` 报 `Nil.config`；改到 `_process` 首帧（_ready 已就绪）后正常。**这是探针自身问题，非 `battle_scene.gd`**；探针（`tests/_fxsmoke.gd`）验后即删、不入 git。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0、`battle_scene.gd` 无解析/编译错误 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过、SCRIPT ERROR=0**（逻辑零改动，无新单测）✅
- `godot --headless --path F:\godotProject` 实跑主场景 14s（AI 自驱）→ 0 运行期错误；常驻路径（出兵建节点 / 攻击节拍复刻 / 塔受击）干净 ✅
- 临时探针强制触发 AI 独跑碰不到的 FX 路径 → **0 运行期错误**；正向证据：DEATH×1（死亡消散实体）、TOWER DOWN×1（碎块）、投射物在飞×1、特效×8（火球/电击/射箭/AI-AOE 推断），玩家三种法术 + 兵牌 no-op 分支均无错 ✅
- **GUI 视觉验收**：人工主观验收**通过**（2026-06-09，用户在编辑器实机确认）；过程用 godot-ai MCP `editor_screenshot source="game"` 辅助核对静态换皮 / 塔摧毁置灰 / 运行时节点树（unit_layer 6 单位 + 6 塔 + fx_layer）。提交 `55c2fb7`、已推 develop。

### 工具链 — godot-ai MCP 画面/FX 验收协议（V2-4 复盘，2026-06-09）
**背景**：V2-4 用 MCP 截图验收时效率差——找工具慢、与「播放状态/截图桥」反复较劲、截图时机靠碰运气、还让用户手动延长对局来配合。用户要求改进，协议已固化进 [CLAUDE.md](CLAUDE.md)「画面/FX 验收用 MCP 时的协议」（可移植、随 repo 走）。
**协议要点**：① 开头一次 ToolSearch 载全工具（editor_state/project_run/project_manage/editor_screenshot/game_manage/logs_read），认准 **`editor_screenshot source="game"`**（2D 工程别用默认 `viewport` 源会报错）；② 干净启动 `stop`→`editor_state`(等 is_playing=false)→`project_run(autosave=false)`→轮询 `game_capture_ready=true` 再截；③ 不碰运气抓 <0.3s 瞬时 FX、不让用户陪打——写**临时(不提交)验收 harness** 用 `Engine.time_scale≈0.15` 慢放/暂停/循环把 FX 定格再截（headless 探针的"有画面"版）；④ `logs_read(source="game")` 读局内事件（`_log` 的 SPAWN/DEATH/TOWER HIT）掐时机；⑤ `game_manage input_mouse` 坐标被映射到桌面全局坐标(多屏)、点不准 UI，别依赖，要交互走代码钩子/harness 或让用户点。
**踩坑**：① input_mouse 注入坐标映射到全局桌面坐标（多显示器），点不中卡牌；② 截图桥须用 MCP 自己 `project_run` 启动的实例（手动 Play 的实例 `_mcp_game_helper` 不一定建桥），且 stop 后要先 `editor_state` 刷新缓存再 run。

### 工具链 — Excel 策划源表 + JSON 生成配置（2026-06-09）
**背景**
- 现有配置只有 `cards.json` / `units.json` / `levels.json` 三张 JSON，早期实现轻量，但继续进入 V2-B/V2-C 后会扩卡、扩关卡、扩 AI 难度与数值平衡；直接手改 JSON 不适合策划长期读改。
- 目标是让人类日常维护 Excel，同时保持 Godot 运行时继续读取 JSON，避免为游戏逻辑引入 Excel 解析依赖。

**新增 / 修改**
- `config/GameConfig.xlsx`：新的策划源表。包含 `Units`、`Cards`、`CardSkills`、`Levels`、`Decks`、`Balance_View`、`_Enums`。`Balance_View` 用公式辅助看 DPS 等派生指标；`_Enums` 为下拉枚举源，不导出。
- `tools/build_config.py`：配置同步脚本。默认从 `GameConfig.xlsx` 生成 `config/cards.json`、`config/units.json`、`config/levels.json`；`--check` 校验 Excel 生成结果与磁盘 JSON 一致；`--from-json` 从当前 JSON 重建 Excel，用于 agent JSON 优先改配置后的同步，以及初始化/救急反向同步。
- `CLAUDE.md`：新增「配置工作流（JSON / Excel 双入口）」；明确 agent 默认直接改 JSON，确认后 `--from-json` 同步 Excel。
- `AGENTS.md`：按用户要求用更完整的 `CLAUDE.md` 内容覆写补齐，并同步配置工作流。
- `.gitattributes`：将 `*.xlsx` 标记为 binary。
- `tests/test_config_loader.gd`：新增 `test_excel_source_workbook_exists`，确保策划源表随项目存在。
- `config/*.json`：当前由 `GameConfig.xlsx` 生成过一次；后续 agent 可直接改 JSON，最终再同步回 Excel。

**决策**
- 运行时仍读 JSON，`ConfigLoader` 与战斗逻辑不为本次迁移改架构。
- agent 默认 JSON 优先；Excel 是给人类读改的工作簿镜像，也是最终需要保持同步的策划视图。
- `CardSkills` 采用“一行一个技能积木”，按 `card_id + order` 聚合成 JSON 的 `skills` 数组，避免在单元格里手写 JSON。
- `attack_interval_s` 是 Excel 面向策划的字段名，生成到 JSON 仍叫 `attack_speed`，沿用现有代码字段；语义记录为「攻击间隔（秒/次）」。
- `--from-json` 是 agent 配置工作流的常规收尾步骤；但它会覆盖 Excel，所以遇到疑似用户未同步 Excel 改动时必须先确认。

**验收**
- `uv run --with openpyxl python tools\build_config.py --check` → `config check ok`、exit 0（uv 首次解析依赖时有 openpyxl 依赖版本 warning，但不影响执行）✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **111/111 全过**、exit 0 ✅

### V2-5a — 主菜单 + 结算面板（场景闭环骨架，仅显示层）  （本次提交）
**前置决策（用户 2026-06-10 确认）**：见决策日志 32（V2-5 拆 3 小步、音频缓做、UI 全英文）。本步只做 **a 场景闭环骨架**。

**范围边界**：仅显示层 / 场景层；`logic/*`、`ai/*`、`config/*`、`tests/*` 零改动 → 单测仍 111/111。战斗内 HUD 美化是 V2-5b，音频已定缓做（V2-5c）。仍无外部素材、无新 `.import`、无授权负担。

**新增 / 修改**
- `view/main_menu.gd` + `view/main_menu.tscn`（新，**主场景**）：主菜单。深绿底 + 三 lane 暗条 + 上下蓝色带；标题 `CLASH PUSHER`、副标题 `3-LANE TOWER RUSH`；`START` → `change_scene_to_file(battle_scene)`、`QUIT` → `get_tree().quit()`。纯程序化绘制、全英文。
- `view/battle_scene.gd`：把原本一行 `banner` Label 的胜负展示升级为**结算面板** `result_layer`（全屏 `Control` + `MOUSE_FILTER_STOP` + 压暗 backdrop，天然拦截身后卡牌点击）——胜负标题（YOU WIN / YOU LOSE / DRAW，按结果着色）+ 比分（`Towers You x Enemy y`，读 `battle.total_tower_hp`）+ `REMATCH`（`reload_current_scene` → 全新一局）/ `MENU`（`change_scene_to_file(main_menu)`）两按钮。`_build_result_panel()` 于 `_build_hud` 末尾建好并隐藏，`_sync_result()` 在对局结束首帧显示一次。删除旧 `banner` 与 `_sync_banner`。
- `project.godot`：`run/main_scene` 由 `battle_scene.tscn` 改为 `main_menu.tscn`，串起 菜单→对局→结算→(再来一局 / 回菜单) 闭环。

**决策**：见决策日志 32。补充：结算面板用「全屏 STOP Control + 子按钮」而非单 Label——覆盖层在 `visible=true` 时拦截身后输入、`visible=false` 时不参与输入，无副作用；REMATCH 用 `reload_current_scene()` 拿到全新一局（Match 重建、圣水归零、塔满血、手牌重置），MENU/START 用 `change_scene_to_file`——标准 Godot 场景切换，逻辑层无需参与、不持跨场景引用。

**踩坑与修复**
- 无（一次通过）。沿用既有显示层经验：跨场景按路径切换、不持引用；新文件先 `--headless --editor --quit` 导入生成 `.uid`；`project.godot` 仅主场景一行变更、无编辑器 churn。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，`main_menu.gd` / `battle_scene.gd` 无解析/编译错误，`project.godot` 仅 `run/main_scene` 一行变更 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **111/111 全过**（逻辑零改动，无新单测）✅
- 两场景 headless 烟测（`--quit-after`）→ 0 运行期错误 ✅
- 临时探针强制对局结束 → 结算面板 `visible` 切换正常、WIN/LOSE/DRAW 文案与比分（`Towers You 5200 Enemy 5200`）均无报错，验后即删、不入 git ✅
- **GUI 视觉验收**：人工主观验收**通过**（2026-06-10，用户在编辑器实机确认闭环：菜单 → START → 对局 → 分胜负弹结算 → REMATCH 全新局 / MENU 回菜单）✅

### V2-5b — 战斗内 HUD 美化（仅显示层）  （本次提交）
**前置决策**：见决策日志 32（V2-5 拆 3 小步、音频缓做、UI 全英文）。本步做 **b 战斗内 HUD 美化**。

**范围边界**：仅改 `view/battle_scene.gd`；`logic/*`、`ai/*`、`config/*`、`tests/*`、`view/main_menu.*` 零改动 → 单测仍 111/111。仍无外部素材、无新 `.import`、全英文。程序化样式（`StyleBoxFlat` 圆角/描边 + `ColorRect`/`Panel`/`Label`）。

**修改（全部在 `view/battle_scene.gd`）**
- **顶部信息条**（新）：屏幕顶 `YOU {王冠}`(蓝) · 倒计时 `m:ss`(中) · `{王冠} ENEMY`(红)。王冠 = 该方已拆掉的对方塔数（遍历 `opponent_towers`/`player_towers` 的 `is_destroyed()` 计数）；时间读 `battle.remaining_time()`。
- **圣水条**：紫色填充 + 按 `elixir.maximum` 分段刻度 + 外框/槽底 + 左侧圆形数字徽章（`Panel` 圆角 stylebox + 居中 `Label`）。取代旧的单条+左上角小数字。
- **手牌卡面**：`Button` 套 `StyleBoxFlat`（圆角/描边，normal/hover/pressed/disabled 四态）；左上角费用徽章（圣水紫圆 `Panel` + 数字 `Label`）；选中态用一层透明金边 `Panel`（`frame.visible`）取代旧的黄色 `modulate`；不可出牌走 disabled 灰样式 + 灰字色。卡名直接用 `card_id`。`card_buttons`(Button 数组) 改为 `card_slots`（`{btn,cost,frame}` 字典数组）。
- **塔血条**：加外框 + 槽底，条高 8→10；填充色按血量比例变色（`_hp_color`：>50% 绿 / 25–50% 橙 / <25% 红），每帧在 `_sync_towers` 更新。
- **结算面板按钮**：REMATCH（绿）/ MENU（灰蓝）套圆角描边样式（`_style_button`）。
- 新增显示层小工具：`_sbflat()`（圆角填充 stylebox）、`_style_button()`、`_hp_color()`；`_build_hud` 拆为 `_build_topbar` / `_build_elixir` / `_build_cards`。

**决策**：纯样式美化，不引入新交互/逻辑；选中态从 `modulate` 改为独立金边 `Panel`（modulate 会连带影响子节点/文字着色，金边层更干净）；费用/选中/可出牌状态每帧在 `_sync_hud` 同步（数据仍来自 `Player`，显示层只读）。**音频仍缓做**（决策 32）。

**踩坑与修复**
- 无（一次通过）。沿用既有经验：徽章/金边 `Panel` 设 `MOUSE_FILTER_IGNORE` 不挡按钮点击；`_build_hud` 在 `_ready` 内、`match_obj` 已 setup，可安全读 `elixir.maximum` 建分段。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，`battle_scene.gd` 无解析/编译错误 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **111/111 全过**（逻辑零改动，无新单测）✅
- `battle_scene` headless 烟测 400 帧 → 每帧 `_sync_hud`（卡面/圣水/顶部条）+ `_sync_towers`（血条变色）0 运行期错误 ✅
- **GUI 视觉验收**：人工主观验收**通过**（2026-06-10，用户在编辑器实机确认顶部条/圣水分段/卡面+费用徽章+选中框/塔血变色/结算按钮样式，且出牌/选牌/部署等交互未被破坏）✅

### V2-6 — 规则 AI 升级（攻防结合 + 按 lane 选向 + 难度分级，逻辑层）  （本次提交）
**前置决策（用户 2026-06-10 确认）**：见决策日志 33（3 档 easy/normal/hard × 4 维度；防守 = 越中线威胁 lane 空投拦截兵；进攻 = 集火最弱敌塔）。

**新增 / 修改**
- `ai/ai_controller.gd`：重写。难度参数表 `DIFF`（threshold/cooldown/defends/smart_lane）+ `_resolve_params`（构造未指定则读 `match.ai_difficulty`）；`_decide` 防守优先（`_most_threatened_lane` 选玩家单位 `progress≥0.55` 且最逼近 AI 塔的 lane → `_deploy_best_troop` 空投最贵兵）→ 其次进攻（`_attack`：`_attack_lane` 智能档选 `_target_tower_hp` 最低的 lane、easy 固定中路；最贵可用兵；法术落 `_lead_enemy_anywhere`）。确定性无随机，仍走 `opponent.try_play_card`。
- `logic/match.gd`：`setup` 存 `ai_difficulty = String(level.get("ai_difficulty","normal"))`（+1 var、+1 行），供 AIController 读取。
- `tests/test_ai_controller.gd`：旧 6 测更新为多 lane 行为（`_all_opponent_units`/`_units_in_lane` 扫全 3 lane），新增 5 测：难度阈值有别(hard vs easy)、难度从关卡解析、受威胁 lane 防守、easy 无视威胁固定中路、集火最弱塔。

**范围边界**：仅逻辑层 + 单测；`view/*`、`config/*` 零改动（难度选择界面是同批的另一改动/提交）。`level_01.ai_difficulty` 仍为 `normal`。

**决策**：见决策日志 33。补充：AI 视角 = `opponent`（塔在 progress 1、部署 0.9 往 0 推、攻击玩家塔 `lane.tower_at_start`，侧路公主毁后兜底 `lane.king_at_start`）；玩家单位 progress 越大越逼近 AI 塔，故威胁线取 `progress ≥ 0.55`。

**踩坑与修复**
- 无（一次通过）。旧测因「固定中路」假设需改：起手全塔满血时最弱守军 = 公主(1400)，集火取 lane 0（tie-break 小 index），故 `test_plays_most_expensive_affordable_troop` 的落点 lane 由 1 改 0；`_opponent_units`(只看 lane1) 改为扫全 3 lane。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，无解析/编译错误 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **116/116 全过**（+5 ai_controller，旧测更新后零回归）✅
- `battle_scene` headless 实跑日志佐证新行为：`SPAWN 敌方 giant_body lane0 → TOWER HIT 我方 公主(左)`——AI 从固定中路变为集火侧路最弱公主塔 ✅
- 逻辑层步骤，正确性由单测覆盖（按纪律无需肉眼验收）。

### 难度选择界面（仅显示层/场景，配合 V2-6）  （本次提交）
**背景**：V2-6 让 AI 支持 easy/normal/hard，用户要求在进对局前加一个让玩家选难度的界面。

**新增 / 修改**
- `view/difficulty_select.gd` + `.tscn`（新）：难度选择界面。EASY(绿)/NORMAL(蓝)/HARD(红) 三个彩色按钮（各带一句说明）+ BACK。选一个 → 写入 `GameState.ai_difficulty` 并 `change_scene_to_file(battle_scene)`；BACK 回主菜单。全英文、纯程序化、零外部素材。
- `view/game_state.gd`（新）：跨场景会话状态。`static var ai_difficulty := "normal"`，难度界面写入、battle_scene 读取（用静态变量在场景切换间保持，不引入 autoload；经 preload 引用读写）。
- `view/main_menu.gd`：`START` 改为进难度界面（`difficulty_select.tscn`）而非直接进对局。
- `view/battle_scene.gd`：`_ready` 读 `GameState.ai_difficulty` 并以之构造 `AIController(match, loader, difficulty)`（覆盖关卡默认）；顶部信息条下加小字 `AI: <难度>`；起始日志带难度。

**新流程**：主菜单 `START` → 难度界面 → 选难度进对局（用所选难度建 AI）→ 结算 `REMATCH`(同难度，GameState 持续) / `MENU`(回主菜单)。

**决策**：难度做成独立一屏（贴合「难度选择界面」）；难度经 `GameState` 静态变量传递（最轻、无需 autoload、跨 `change_scene_to_file` 持续）；逻辑层不参与（难度仅经已测的 `AIController` 构造参数注入）。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0、无解析错误 ✅
- 单测 **116/116**（逻辑零改动）✅
- 难度界面 / 主菜单 headless 烟测 → 0 报错 ✅
- 临时探针：`GameState=hard → battle._ai_diff=hard → AIController.get_difficulty()=hard`，确认难度经界面接到 AI；验后即删、不入 git ✅
- **GUI 视觉验收**：人工实机确认菜单→难度→对局闭环 + AI 难度生效（2026-06-10，用户验收）✅

### V2-7a — 扩卡池（+6 卡 / +4 单位，纯 JSON + 单测）  （待提交）
**前置决策**：见决策日志 34（V2-7 拆 3 小步、卡池适中、关卡=遭遇战含难度、自由组卡、会话内持久化）。本步只做 **7a 扩卡池**（内容/配置层，零碰 view 与战斗逻辑）。

**修改**
- `config/units.json`：+4 单位——`mini_pekka_body`（反坦克爆发近战 700hp/320dmg/1.8s/move1.1/range0.05/ground）、`musketeer_body`（远程高 DPS 340/110/1.1/1.0/range0.35/ground）、`skeleton_body`（极廉价群体 40/40/1.0/1.3/0.04/ground）、`baby_dragon_body`（空中肉盾远程 900/80/1.6/1.0/0.18/air）。
- `config/cards.json`：+6 卡——`mini_pekka`(4)/`musketeer`(4)/`baby_dragon`(4) 各 spawn 1、`skeletons`(2) spawn 4 骷髅、`lightning`(4) direct_damage 280、`log`(2) aoe_damage radius0.4/dmg130。命名沿用中文 `name`（UI 显示 card_id、不渲染中文、零字体依赖）。
- `config/GameConfig.xlsx`：`build_config.py --from-json` 从新 JSON 重建（人类策划镜像）。
- `tests/test_config_loader.gd`：+2 测——`test_v2_7a_expanded_pool`（卡池 ≥14 / 单位 ≥9 + 6 新卡 4 新单位存在）、`test_v2_7a_new_cards_well_formed`（skeletons spawn 4、lightning direct/target、log aoe、baby_dragon air、mini_pekka 高伤）。

**范围边界**：仅 config + 单测；`logic/*`、`ai/*`、`view/*` 零改动。新卡暂未进任何卡组（`level_01` 牌组不变），故对局画面暂不变——接入留 7b/7c。`config_loader._validate` 的交叉引用（spawn_unit→unit、deck→card）对新内容天然生效。

**决策**：见决策日志 34。新数值均为白膜占位、可调，统一平衡 pass 留 V2-8。

**踩坑与修复**
- 无。动 JSON 前先跑基线 `--check`（确认 JSON↔Excel 已同步、`--from-json` 不会覆盖未同步的手改，CLAUDE.md 安全协议）；编辑后 `--from-json` + `--check` 往返一致。数值刻意守 `build_config.py` 的 int/float 往返语义（hp/damage/count/elixir_cost 整数、attack_speed/move_speed/radius 带小数、`direct_damage.target` 仅 `first_enemy_in_lane`）。

**验收**
- `build_config.py --check`（基线 + 同步后两次）→ `config check ok`，JSON↔Excel 往返一致 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **118/118 全过**（+2 config_loader，旧 116 零回归），SCRIPT ERROR / Parse Error 计数 = 0 ✅
- 纯配置/逻辑层步骤，正确性由单测 + 配置校验覆盖（按纪律无需肉眼验收）✅

### V2-7b — 多关卡 + 选关界面（关卡=独立遭遇战含难度）  （本次提交）
**前置决策**：见决策日志 34（关卡=独立遭遇战、自带难度；选关界面取代难度界面；所选关卡经 `GameState` 跨场景传递）。

**新增 / 修改**
- `config/levels.json`：1 关 → **4 关**（level_01 原样不动，守住旧测试假设）。新增 `level_02`「训练场/EASY」（regen1.0、180s、塔2400/1400、基础 AI 卡组）、`level_03`「冠军竞技场/HARD」（regen1.2、180s、塔**2600/1500**、AI 卡组含新卡 mini_pekka/musketeer/baby_dragon/lightning）、`level_04`「闪电赛/HARD」（**regen2.0、120s** 快节奏、循环 AI 卡组）。各关携带独立 `ai_difficulty` + AI 卡组 + 塔血 + 圣水节奏；`player_deck` 暂统一为经典 8 张（7c 组卡再覆盖）。同步 `GameConfig.xlsx`。
- `view/level_select.gd` + `.tscn`（新）：选关界面，**取代** `difficulty_select`。关卡从 `ConfigLoader` 动态读取（加关只改 JSON、界面自动出现），按难度档由易到难排；每关一张卡片 = 英文标题（难度档命名 TRAINING/ARENA/CHAMPION/BLITZ，避开 CJK 字体）+ 难度徽章（绿/蓝/红）+ 数值行（圣水节奏/时长/王塔血）+ 一句说明。选一关 → 写 `GameState.level_id` 进对局；BACK 回菜单。全英文、纯程序化、零外部素材。
- `view/game_state.gd`：`ai_difficulty` 静态变量 → **`level_id`**（难度不再单独选，随关卡而定）。
- `view/main_menu.gd`：`START` 目标 `difficulty_select.tscn` → `level_select.tscn`。
- `view/battle_scene.gd`：`setup("level_01")` → `setup(GameState.level_id)`；`_ai_diff` 由 `GameState.ai_difficulty`（覆盖）改为读 `match.ai_difficulty`（关卡解析）；`AIController.new(match, loader)` 去掉难度覆盖参数（难度由关卡流入 `match.ai_difficulty`，AIController 自行解析）；顶部小字与起始日志改用 `_level_id`。
- 删除 `view/difficulty_select.gd` / `.gd.uid` / `.tscn`（被选关界面取代）。
- `tests/test_config_loader.gd`：+1 测 `test_v2_7b_multi_level`（≥4 关、新关难度/牌组合法、level_01 仍 normal、level_04 双倍圣水+120s 差异化生效）。
- `tests/test_match.gd`：+1 测 `test_setup_other_level_carries_its_difficulty_and_config`（`setup("level_03")`→`ai_difficulty=hard` + 双方 8 张牌组；`setup("level_04")`→`battle.match_duration=120`）。

**范围边界**：逻辑层零改动（`Match.setup` 本就读 `level.ai_difficulty` 存 `match.ai_difficulty`，AIController 本就在未给难度时读它——V2-6 已铺好）；新增仅 config + 2 view 场景 + 2 单测。新流程：菜单 → **选关** → 对局 → 结算（组卡 7c 后插在选关与对局之间）。

**决策**：见决策日志 34。补充：选关界面**不显示中文 `name`**（零 CJK 字体延续），改用难度档英文标题；标题对 hard 关按圣水节奏 ≥1.5 分 BLITZ / 否则 CHAMPION（cosmetic，自包含于 view）。`GameState.ai_difficulty` 退役为 `level_id`，难度统一由关卡承载。

**踩坑与修复**
- 无。先确认 `level_01` 被多处测试断言（`test_ai_controller` 断言其 `=normal`、`test_battle/match/deck/skill_system` 用其牌组/塔血/时长）→ **完全不改 level_01，只新增关卡**，旧测试零回归。

**验收**
- `build_config.py --from-json` + `--check` → JSON↔Excel 往返一致（4 关）✅
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，新脚本无解析/编译错误、`level_select.gd.uid` 生成 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **120/120 全过**（+1 config_loader +1 match，旧 118 零回归），SCRIPT ERROR = 0 ✅
- headless 烟测（临时 harness，验后删）：`GameState.level_id="level_03"` → `battle_scene` 实跑 7s，日志 `MATCH START level_03 | AI=hard`、AI 部署**新卡** `mini_pekka_body`/`musketeer_body` 并击中公主（hp/1500 = level_03 塔血），零运行期报错 ✅；`level_select` / `main_menu` 场景 `_ready` 实跑（`--quit-after`）零报错 ✅
- **GUI 视觉验收**：选关界面外观 / 4 关卡片排版属表现层，留用户实机过目（不阻塞本步逻辑+接线验收）。

### V2-7c — 组卡界面（自由选 8 张，覆盖关卡默认卡组）  （本次提交）
**前置决策**：见决策日志 34（组卡=自由选任意 8 张唯一卡、不限费用；所选卡组经 `GameState` 传递、覆盖关卡默认 `player_deck`）。

**新增 / 修改**
- `view/deck_builder.gd` + `.tscn`（新）：组卡界面。卡池从 `ConfigLoader` 动态读 14 张（兵牌/法术按类配色：troop 钢蓝 / spell 紫），点卡片切换加入/移出，选中描金边；上方 8 格当前卡组（点格移除）；计数 `N / 8`（满 8 变绿）；`BATTLE` 仅满 8 张可点（disabled 灰样式），`BACK` 回选关。预填：优先沿用本会话已组卡组，否则用所选关卡默认 `player_deck`（便于不改直接开战）。全英文（卡显示 `card_id` + 费用，不显示中文 name）、纯程序化、零素材。
- `view/game_state.gd`：+ `static var player_deck: Array = []`（组卡界面写入；空=用关卡默认）。
- `logic/match.gd`：`setup(level_id, player_deck_override := [])` 加可选第二参；非空则玩家卡组用覆盖、否则用关卡默认；**对手卡组永远用关卡 ai_deck**（不受玩家组卡影响）。加性、向后兼容（旧调用 = 空覆盖 = 原行为，旧测试零回归）。
- `view/battle_scene.gd`：`setup(_level_id)` → `setup(_level_id, GameStateScript.player_deck)`。
- `view/level_select.gd`：选关后目标 `battle_scene` → **`deck_builder`**（流程插入组卡步）。
- `tests/test_match.gd`：+1 测 `test_setup_player_deck_override`（覆盖卡组 → 玩家手牌=覆盖前 4 张含新卡、对手卡组不受影响；空覆盖 → 回退关卡默认）。

**范围边界**：逻辑层仅 `Match.setup` 加一个可选参数（+单测）；其余为 view 场景。最终流程闭环：菜单 → 选关 → **组卡** → 对局 → 结算。

**决策**：见决策日志 34。补充：覆盖仅作用于**玩家**卡组（对手始终用关卡 `ai_deck`，保持关卡设计的对手强度）；持久化按决策 34 走 `GameState` 会话内静态变量、不落盘；UI 沿用零 CJK 字体（显示 card_id）。

**踩坑与修复**
- 无。`Deck.setup` 取 `card_ids.slice(0,4)` 为手牌，故端到端可用「玩家手牌 == 覆盖卡组前 4 张」精确断言覆盖是否生效。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，`deck_builder.gd` 无解析/编译错误、`.uid` 生成 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **121/121 全过**（+1 match，旧 120 零回归），SCRIPT ERROR = 0 ✅
- headless 烟测（临时 harness，验后删）：① `deck_builder` 场景 `_ready` 实跑（`--quit-after`）零报错；② 设 `GameState.player_deck=[mini_pekka,musketeer,baby_dragon,skeletons,...]` + `level_02` → `battle_scene` 实跑，`match.player.deck.get_hand()` = `[mini_pekka,musketeer,baby_dragon,skeletons]`，证明组卡经 GameState→battle_scene→Match 端到端生效、零运行期报错 ✅

### V2-8 — 数值平衡 pass（轻量：arrows→AOE + baby_dragon 提速，纯配置）  （本次提交，macOS）
**前置决策**：见决策日志 35（轻量、重点对局节奏+难度曲线、proxy 不可调难度、仅改两张卡）。

**测量方法**：临时 headless harness `tools/_balance_probe.gd`（**已删、不入 git**）。用真 `AIController` 驱动 AI(opponent) 侧，写一个几何镜像控制器（部署 0.1、威胁线 0.45、进攻打 end 端塔）驱动 player 侧、同一套 DIFF 难度参数；跑三组：①多变体胜率（固定玩家牌组、只变关卡、扰动出牌相位+卡序 16 变体）→ 难度曲线；②对称对局（双方同牌组同难度）→ 节奏；③单卡 ×8 刷塔 → raw 强度。结论见决策 35（节奏健康 / 难度 proxy 不可读 / 单卡印证）。

**修改**
- `config/cards.json`：`arrows` `direct_damage 150 / first_enemy_in_lane` → `aoe_damage radius 0.5 / damage 140`（费用仍 3）。
- `config/units.json`：`baby_dragon_body.attack_speed` 1.6 → 1.3（DPS 50→62）。
- `config/GameConfig.xlsx`：`uv run --with openpyxl python tools/build_config.py --from-json` 从新 JSON 重建（人类策划镜像）。
- `tests/test_skill_system.gd`：3 个 `direct_damage` 机制用例（`test_direct_damage_player/opponent_hits_frontmost_enemy`、`test_direct_damage_no_enemy_is_noop`）由 `arrows`（已改 AOE）改指向 `lightning`（仍 direct_damage 280），断言中招血 150→20；arrows 的 AOE 行为由既有 `test_aoe_*` 用例覆盖。
- view 层**零改动**：`battle_scene._play_spell_fx` 按技能类型派发（卡有 `aoe_damage` 块 → 自动走爆点 FX），arrows 改 AOE 后自动正确显示爆点；`_spawn_arrows` 仍由 lightning（else 分支）复用。

**范围边界**：仅 config（2 JSON + Excel 同步）+ 1 测试文件；`logic/*`、`ai/*`、`view/*` 零改动。swarm/mini_pekka/zap 及各关卡塔血/回速/时长/难度档/AI 卡组本轮不动。

**决策**：见决策日志 35。

**踩坑与修复**
- 无。改 JSON 前先用 harness 建基线；arrows 改 AOE 经核查显示层 FX 按技能类型自动派发（无错配/报错）、`test_ai_controller`/`test_player` 不受影响（arrows 仍为「无 spawn 法术」、费用不变）。
- 本机（macOS）`uv` 未装 → 按 `docs/ENVIRONMENT.md` macOS 路径 `brew install uv`（走代理 `127.0.0.1:7897`），再用 `uv run --with openpyxl python tools/build_config.py --from-json/--check` 同步并校验 Excel。

**验收**
- `uv run --with openpyxl python tools/build_config.py --from-json` + `--check` → `config check ok`，JSON↔Excel 往返一致 ✅
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **121/121 全过**（test_skill_system 3 用例改指向 lightning 后零回归）✅
- harness 复测：arrows→AOE 后对称对局的 0-0 僵局消失、全部拆王塔决胜（35–120s），节奏健康；难度曲线 proxy 倒挂/噪声确认（交真人）✅
- **难度曲线**：按决策 35 交真人实机验收（清单见下），本步不靠 proxy 调。

**V2-8 难度曲线 — 真人实机验收清单（交用户）**
逐关在 Godot 编辑器里打一局（菜单 → 选关 → 组卡用默认 → 对局），按下表回报手感：

| 关卡 | 难度档 | 期望手感 | 通过标准 |
|---|---|---|---|
| level_02 训练场 | easy | 最简单：AI 慢、只走中路、不防守 | 轻松取胜、有「练手」感 |
| level_01 新手关 | normal | 入门：AI 会防守+选路，节奏中等 | 需认真打但能赢 |
| level_03 冠军竞技场 | hard | 难：AI 强卡组(含新卡)+高塔血+反应快 | 有挑战、要打法才赢、不必败 |
| level_04 闪电赛 | hard | 快节奏：双倍圣水、120s 限时 | 手忙脚乱但刺激、能在限时内决胜 |

反馈格式：每关「胜/负、时长感受、太易/适中/太难、AI 哪里蠢或哪里强」。据反馈再决定是否调各关 `ai_difficulty`/`tower_hp`/`elixir_regen_rate`/`match_duration`/AI 卡组（届时为下一轮配置调整）。

---
