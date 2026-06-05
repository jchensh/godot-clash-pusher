# HISTORY.md — 开发历史与进度记录

> **本文件用途**：给任何接手的人/agent（新开对话也一样）一个**准确、自足**的项目进度与历史。
> 阅读顺序建议：先 [PLAN.md](PLAN.md)（唯一权威规划）→ [CLAUDE.md](CLAUDE.md)（操作手册）→ 本文件（已发生了什么、为什么这么做、踩过什么坑）。
> **维护约定**：每完成一个 PLAN 步骤（或做出重要决策/踩坑修复），都要在此**追加记录**，再随该步 commit。

---

## 快速上手（新 agent 必看）

- 引擎：**Godot 4.6.3 stable（标准 GDScript 构建）**，已通过 `~\bin\godot.cmd` shim 加入用户 PATH。新终端里 `godot` 直接可用；同一会话内若 PATH 未刷新，先 `$env:PATH = "$env:USERPROFILE\bin;$env:PATH"`。
- 跑全部单元测试（逻辑层验收的主手段）：
  ```powershell
  godot --headless --path F:\godotProject --script res://tests/test_runner.gd
  ```
  退出码 0 = 全过；非 0 = 有失败（末尾打印失败明细）。
- 验证工程能打开 / 重新导入（生成 .uid、刷新资源）：
  ```powershell
  godot --headless --editor --path F:\godotProject --quit
  ```
  > 注意：空工程阶段**不能**用 `--headless --quit`（会因"无主场景"报错），要用上面的 `--editor --quit`。
- 测试框架：**自写轻量 runner**（零依赖）。新测试文件放 `tests/test_*.gd`，`extends "res://tests/test_case.gd"`，方法名以 `test_` 开头。`tests/test_runner.gd` 自动发现并执行，汇总 + exit 0/1。

---

## 当前进度总览

| 步骤 | 内容 | 状态 | commit |
|---|---|---|---|
| 0 | 脚手架 + git + 工具链 | ✅ 完成 | `77909c9` |
| 1 | ConfigLoader + 三张 JSON | ✅ 完成 | `a632dcd` |
| 2 | Elixir 圣水系统 + SimClock 固定 tick | ✅ 完成 | `22b75cb` |
| 3 | Deck 循环抽牌 | ✅ 完成 | `1da44e3` |
| 4 | Unit + Lane 推进与碰撞 | ✅ 完成 | _本次提交_ |
| 5 | Tower + Battle 胜负判定 | ⬜ | — |
| 6 | SkillSystem 三积木 | ⬜ | — |
| 7 | 显示层 MVP（白膜 + UI） | ⬜ | — |
| 8 | AIController 规则 AI | ⬜ | — |
| 9 | 安卓导出 + 触摸 + 竖屏 | ⬜ | — |

**测试现状**：49 个测试全部通过（config_loader 7 + elixir 10 + sim_clock 6 + deck 9 + unit 6 + lane 8 + smoke 3）。

**分支 / 远端**：开发在 **`develop`** 分支；`main` 为稳定线。远端 `origin` = https://github.com/jchensh/godot-clash-pusher （Public）。约定：用户说"提交"时才 commit + push。

---

## Step 4 前置语义（已确认，可开做）

> **给接手的人 / agent**：`Unit` + `Lane`（Step 4）涉及战斗结算，依赖下面两个语义。PLAN §9 未定。
> 用户已于 2026-06-06 确认，可按下列结论开始 Step 4。

1. **`attack_range` 的单位**：lane 进度 `0~1` 的比例；例如 `0.5` 表示半条 lane。
2. **`target_type` 的含义**：单位自身的地面 / 空中类型（即该单位属于 `ground` 还是 `air`），用于后续命中/筛选判断；不要把它解释为“该单位能攻击什么”。如后续需要表达攻击能力，再另加字段（如 `attack_targets`）并走配置。

> 次要（可在 Step 4 过程中细化，不卡开工）：单位攻击目标规则（同 lane 最前敌人 / 优先塔）、`direct_damage` 的 `target` 枚举、多积木结算顺序。

---

## 关键决策记录（Decision Log）

1. **语言 = GDScript**：装的是 Godot 标准构建（非 .NET/Mono），且 PLAN 未提 C#。
2. **逻辑 tick = 10Hz（`SimClock.TICK_DELTA = 0.1s`）**：取 PLAN §8 示例值。配置里的速率（如 `elixir_regen_rate`）一律按**每秒**解释，tick 频率改变不影响数值含义，故此值低风险、可后改。**（用户 2026-05-30 确认保持。）**
3. **逻辑层数值用「每秒」单位 + dt 累加**：而非"每 tick 固定量"，保证 tick 频率与数值解耦。
4. **ConfigLoader 输出字典**而非 typed 数据类：遵守"不过度设计"，消费方（Step 4/6）真正需要时再加包装。
5. **测试用自写 headless runner**：零外部依赖（用户选择）。
6. **配置数据存为字典 + 交叉引用校验**：主动校验 deck→card、spawn_unit→unit 的引用完整性，提早抓 id 笔误。
7. **起始圣水 = 0（空槽开局）**：PLAN/配置未定义起手圣水；先按 0 做，将来如需半槽起手再加 `levels.json.elixir_start` 字段（用户 2026-05-30 确认）。
8. **`attack_range` = lane 进度比例**：用户 2026-06-06 确认，范围数值按 `0.0~1.0` 的 lane 进度解释。
9. **`target_type` = 单位自身类型**：2026-06-06 决策，`ground` / `air` 表示单位属于地面/空中，用于命中筛选；攻击能力后续若需要用独立配置字段表达。
10. **`attack_speed` = 攻击间隔（秒/次）**：Step 4 决策，单位初次接敌可立即攻击，攻击后按 `attack_speed` 秒进入冷却。
11. **Lane 目标选择 = 范围内最近敌人**：Step 4 决策，单位只打同 lane 中距离最近且在自身 `attack_range` 内的敌方单位；未接敌时沿 owner 方向推进，接近前方敌人时停在自身攻击范围边界。

---

## 与原计划（PLAN.md）的出入

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

**仍待定**
- [ ] **多积木结算顺序、direct_damage 的 target 枚举**：PLAN §9，到 Step 6 前细化。

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
