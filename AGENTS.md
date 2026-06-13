# AGENTS.md

竖屏「皇室战争式对推小游戏」，**Godot 4.x / GDScript**。玩家 vs 规则 AI，圣水 + 循环卡组部署单位，沿 lane 互推、推塔决胜。V1 纯 2D 白膜，先 Windows 跑通再导出安卓。

> **编码前必读**：[PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）→ [PLAN_V3.md](PLAN_V3.md)（**当前阶段权威规划**）；[PLAN_V2.md](PLAN_V2.md) / [PLAN_V1.md](PLAN_V1.md) 是已完成阶段的规格（存档备查）。本文件只是操作手册，当前阶段规格以 PLAN_V3.md 为准。

## 开发纪律（最高优先级）
- **一步一确认**：严格按 PLAN_V3.md 的施工图步骤顺序；**每完成一步停下等用户确认**，再进下一步，不要一次做多步。
- **每步一次 git commit**，message 描述本步内容（如 `step2: elixir system + unit tests`）。
- **每步同时更新 [HISTORY.md](HISTORY.md)**：记录新增/修改文件、决策、踩坑与修复、验收结果，随该步一起 commit。它是跨对话的进度与历史真相源。
- **第 0~6 步是纯逻辑层，必须配单元测试，测试通过才算完成。**
- **遇配置含义/接口不清，先提问，不要猜着往下跑。**
- 给成功标准而非实现细节；不自行扩大范围。
- **需实机操作验证的（点界面、看画面/动画/手感等表现层行为），优先让真人验收**：AI 不要自己去驱动鼠标点引擎窗口跑（低效、易错）。正确做法 = AI 写好**可执行的测试用例**（开什么场景、点哪、预期看到什么、判定通过的标准），用户在 Godot 编辑器里执行后回报 通过/不通过；AI 据反馈修。能 headless 单测覆盖的逻辑仍走单测，**只有真正需要肉眼看画面的才交给真人**。进入表现层（D 模块 V2-3+）后这类验收会很多。

## 硬性 DO-NOT
- ❌ 不用物理引擎（`RigidBody2D`/`Area2D`）做单位碰撞——用**自写的确定性 2D 软分离**（固定顺序遍历推开重叠），纯逻辑、可单测。（V3 前为 1D「队列前后关系」，2D 重构后改此。）
- ❌ 逻辑层禁用**渲染/屏幕像素坐标**——单位位置用**抽象 2D 场地坐标**（tile 空间，view 负责映射）。（V3 前为 `0.0~1.0` 的 1D lane 进度，2D 重构后改此；详见 PLAN_V3 §4。）
- ❌ 游戏速度禁绑渲染帧率——圣水/时间/推进用**固定逻辑 tick** 结算，显示层做插值。
- ❌ 不过度设计，不写用不到的「未来扩展」代码。
- ❌ 不擅自删改与当前任务无关的代码/注释。

## 架构铁律
- **逻辑层 / 显示层彻底分离**：逻辑层持有真实状态（位置/血量/圣水），不关心画面；显示层每帧读逻辑状态画出来。
- 玩家与 AI **完全对称**：两者都只是「向逻辑层发指令」。
- 数值/卡牌**走配置，不硬编码**。Godot 运行时读取 `config/cards.json`、`config/units.json`、`config/levels.json`；`config/GameConfig.xlsx` 是给人类策划读改的工作簿镜像。

## 配置工作流（JSON / Excel 双入口）
- **agent 默认改 JSON**：Codex / Claude 做配置、数值、卡牌、关卡调整时，优先直接编辑 `config/cards.json`、`config/units.json`、`config/levels.json`，因为这是 Godot 实际读取路径，也更省上下文和操作成本。
- agent 确认 JSON 配置正确后，用当前 JSON 覆写同步 Excel：
  ```powershell
  uv run --with openpyxl python tools/build_config.py --from-json
  ```
  这会从 `config/*.json` 重建 `config/GameConfig.xlsx`，让人类之后仍能用 Excel 查看和继续改。
- **人类策划可以直接改 Excel**：如果用户自己在 `GameConfig.xlsx` 里调数值，改完后运行：
  ```powershell
  uv run --with openpyxl python tools/build_config.py
  ```
  这会从 Excel 重新生成 `config/cards.json`、`config/units.json`、`config/levels.json`。
- 提交前必须校验 JSON 与 Excel 已同步：
  ```powershell
  uv run --with openpyxl python tools/build_config.py --check
  godot --headless --path F:\godotProject --script res://tests/test_runner.gd
  ```
- `tools/build_config.py --from-json` 会覆盖 `GameConfig.xlsx`。如果发现 Excel 可能有用户尚未同步到 JSON 的改动，agent 必须先停下询问，不要直接覆盖。
- agent 修改配置时必须遵守：先改 JSON，再 `--from-json` 同步 Excel，再跑 `--check` 和 Godot 单测；如果用户只要求分析方案，不要擅自生成或改配置。
- **结构性配置 `config/arena.json`（V3 新增）**：2D 场地几何（网格/河/桥/塔位），由 `ConfigLoader` 统一读取，但**非平衡数值、不进 Excel 镜像**（不经 `build_config.py`）。
- 当前工作簿 sheet 约定：
  - `Units`：单位基础数值。`attack_interval_s` 会生成到 JSON 的 `attack_speed` 字段，语义是「攻击间隔（秒/次）」。
  - `Cards`：卡牌主表，控制 `card_id`、名称、费用、启用状态。
  - `CardSkills`：一行一个技能积木，按 `card_id + order` 聚合成 JSON 的 `skills` 数组。
  - `Levels`：关卡主表，包含圣水、时长、AI 难度、塔血。
  - `Decks`：每关玩家/AI 的 8 张卡组。
  - `Balance_View`：公式视图，辅助看 DPS 等派生指标；不导出。
  - `_Enums`：下拉枚举源，隐藏表；不导出。

## 目录布局
```
/logic   逻辑层（不依赖 Godot 渲染）
/view    显示层脚本与场景
/ai      AIController
/config  GameConfig.xlsx（策划源表）+ cards.json / units.json / levels.json（生成产物）+ arena.json（V3 2D 场地，结构性）
/tests   单元测试（test_*.gd） + test_runner.gd + test_case.gd
/tools   配置生成脚本等项目工具
```

## 工具链 / 常用命令
引擎：**Godot 4.6.3 stable（标准 GDScript 构建）**。已加入用户 PATH（经 `~\bin\godot.cmd` shim，指向 WinGet 安装的 `_console.exe`）。新终端中 `godot` 直接可用。

```powershell
godot --version                                   # 确认可用
godot --headless --quit --path F:\godotProject    # 验证工程能打开/导入
godot --headless --script res://tests/test_runner.gd   # 跑全部单元测试（CI/逻辑层验收）
godot --path F:\godotProject -e                   # 打开编辑器 GUI
```
> 测试用**自写轻量 runner**（零外部依赖）：`tests/test_runner.gd` 自动发现 `test_*.gd`、跑 `test_*` 方法、汇总并以 exit 0/1 返回。新测试文件 `extends "res://tests/test_case.gd"`。

IDE：**VS Code**（默认）。装 `geequlim.godot-tools` 扩展（`.vscode/extensions.json` 已推荐）；F5 用 `.vscode/launch.json` 的「Debug Godot Project」启动调试。

## godot-ai MCP（编辑器联动，**辅助工具**）
项目装了 `godot-ai` 插件（`addons/godot_ai/`），在 **Godot 编辑器内**起一个 MCP server（`http://127.0.0.1:8000/mcp`），让 AI 能直接读写引擎：看场景树、建/改节点、改脚本、跑测试、截图等（工具名 `mcp__godot-ai__*`，如 `editor_state` / `scene_get_hierarchy` / `node_create` / `script_patch` / `test_run` / `editor_screenshot`）。

**前提条件**
- server 本体由 Godot 插件提供：**只有 Godot 编辑器开着时才可用**，关掉就断。
- 注册信息在用户级 `~\.claude.json`（scope=user，全局生效），非项目内。
- **必须先开 Godot 编辑器，再开 Claude Code 会话**；顺序反了当前会话连不上，需新开会话重连。

**管理 / 排查**
```powershell
claude mcp list            # 看所有 MCP 与连接状态（godot-ai ✓ Connected 即正常）
claude mcp get godot-ai    # 看详情
claude mcp remove godot-ai -s user   # 卸载注册（不删插件）
```
界面里敲 `/mcp` 也能看状态；Godot 那边在「项目设置→插件」启停 `godot_ai`。

**使用守则（重要）**
- ❌ **不主动用**——默认当辅助工具，**仅当用户明确叫我用时才用**，绝不自行驱动引擎。
- ✅ 被叫到时：**只读操作**（看场景树/截图/读日志/跑测试）可直接做。
- ⚠️ **写操作**（建节点/改脚本/改属性等会改工程的）先按"一步一确认"跟用户确认再动手。
- 这条与上面「实机/画面验收交给真人」纪律一致：MCP 是补充手段，不替代真人肉眼验收。

**画面/FX 验收用 MCP 时的协议（V2-4 教训，别让用户陪打）**
- **一次性载全工具**：开头一个 ToolSearch 把 `editor_state / project_run / project_manage / editor_screenshot / game_manage / logs_read` 全拿到；认准 **`editor_screenshot source="game"`** 截运行中游戏（2D 工程别用默认 `viewport` 源，会因无 Node3D 报错）。
- **干净启动序列**（避开缓存滞后/截图桥未就绪）：`project_manage(op=stop)` → `editor_state`（刷新缓存，等 `is_playing=false`）→ `project_run(autosave=false)` → 轮询 `editor_state` 到 `game_capture_ready=true` 才截图。
- **不被动碰运气抓 <0.3s 瞬时 FX、绝不让用户手动延长对局陪打**：写**临时(不提交)验收 harness**把要看的 FX 摆好并定格够久（`Engine.time_scale≈0.15` 慢放／暂停／循环），在已知时刻截图，验后删（headless 探针的"有画面"版）。
- **用日志掐时机**：`logs_read(source="game")` 能拿到运行中游戏 stdout（`battle_scene._log` 的 SPAWN/DEATH/TOWER HIT 都在那），据此把截图对准关键事件。
- **`game_manage input_mouse` 坐标不可靠**：position 被映射到桌面全局坐标（多屏），点不准卡牌/落点；要交互走代码钩子/harness 或让用户点。

## 分支 / 提交 / 推送约定
- **开发在 `develop` 分支进行**；`main` 为稳定线，远端 `origin` = https://github.com/jchensh/godot-clash-pusher 。
- **仅当用户说"提交"时**才 `git commit`；提交后**顺带 `git push`**（develop 首次推送用 `git push -u origin develop` 建立跟踪）。
- 仍遵守"一步一确认"：每步做完先停下报告，待用户说提交再 commit+push。

## 当前进度
- Step 0 ✅ 脚手架 + git + 工具链
- Step 1 ✅ `ConfigLoader` + 三张 JSON 配置
- Step 2 ✅ `Elixir` 圣水系统 + `SimClock` 固定逻辑 tick（10Hz / `TICK_DELTA=0.1s`）
- Step 3 ✅ `Deck` 循环卡组（8 库 + 4 手，出一张补一张）
- Step 4 ✅ `Unit` + `Lane` 推进与碰撞（纯逻辑）
- Step 5 ✅ `Tower` + `Battle` 胜负判定（三塔制；王塔归零判负；超时比塔血）
- Step 6 ✅ `SkillSystem` 三积木（spawn_unit / direct_damage / aoe_damage）
- Step 7 ✅ 显示层 MVP（白膜方块 + 手牌 UI + 圣水条 + 血条；单 lane 跑通；7a Player/Match 逻辑 + 7b Godot 画面）
- Step 8 ✅ `AIController` 规则 AI（简单进攻型；对手自驱出牌、一局正常分胜负）
- Step 9 ⏸ 安卓导出（缓做，移至 V3-9；编辑器内即可体验/开发）
- **V1 收官**。**V2**（顺序 A→D→B→C，规格见 PLAN_V2.md）**已全部完成**：
  - V2-1 ✅ 3-lane 逻辑层；V2-2 ✅ 3-lane 接通（A 模块完成）。
  - V2-3 ✅ 程序化美术换皮；V2-4 ✅ 动画与特效（仅 view 层、视觉验收通过）。
  - V2-5 ✅ D 模块收尾：5a 主菜单+结算闭环、5b 战斗内 HUD 美化（5c 音频缓做，决策 32）。
  - V2-6 ✅ 规则 AI 升级（攻防结合+选向+难度分级，决策 33）。
  - V2-7 ✅ 扩卡池（14 卡/9 单位）+ 多关卡（4 关）+ 选关界面 + 组卡界面（决策 34）。流程：菜单→选关→组卡→对局→结算。
  - V2-8 ✅ 数值平衡 pass（轻量，纯配置；决策 35）：仅改 `arrows`（→AOE）、`baby_dragon`（提速）。难度曲线交真人实机验收。**至此 V2 主线全部完成**；剩 5c 音频缓做。
- **V3 启动**（2026-06-10）：**战斗核心 2D 重构** + 做成买断制单机（短战役 + Roguelite，2D 卡通精灵）。权威规划见 [PLAN_V3.md](PLAN_V3.md)（决策日志 36）。
  - **V3-1 = 2D 战斗 reboot（头号工程，取代 lane）**：河 + 左右双桥 + 己方半场自由落点 + 流场绕桥寻路 + 完整 CR 仇恨/分心 + 软推挤碰撞 + 塔会反击。拆 8 小步（a 场地地形 / b 移动寻路 / c 仇恨 / d 软分离+攻击 / e 塔反击 / f 技能 2D / g AI 2D / h 显示层 2D）。绞杀式迁移：新 `arena.gd` 与旧 `lane.gd` 并存、单测全程绿，V3-1h 后删 lane。
    - V3-1a ✅ 场地与地形：`config/arena.json` + 新 `logic/arena.gd`（地形/塔占位/落点合法性）+ `Battle.build_arena` + `tests/test_arena.gd`。单测 132/132，与 lane 并存。
  - **Now**：执行 **V3-1b**（移动 + 流场寻路绕桥；`Unit` 加 2D 字段，`move_speed`/`attack_range` 量纲 lane 比例→tile）。
