# AGENTS.md

竖屏「皇室战争式对推小游戏」，**Godot 4.6.3 / GDScript**，**macOS 开发**。玩家 vs 规则 AI，圣水 + 循环卡组、**2D 场地自由部署、绕桥推塔决胜**（V3 起为 2D 战斗核心，做成买断制单机：短战役 + Roguelite）。

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
- **agent 默认改 JSON**：直接编辑 `config/cards.json` / `units.json` / `levels.json`（Godot 运行时读取路径，省上下文）。`config/arena.json` 是 V3 2D 场地结构性配置，**不进 Excel 镜像**。
- 改完 JSON → 同步并校验 Excel（下载 openpyxl 走代理）：
  ```bash
  uv run --with openpyxl python tools/build_config.py --from-json   # JSON → 重建 GameConfig.xlsx
  uv run --with openpyxl python tools/build_config.py --check       # 校验 JSON↔Excel 一致（提交前必跑）
  ```
  人类策划直接改 Excel 后，用无参 `build_config.py` 反向生成 JSON。
- ⚠️ `--from-json` 会覆盖 `GameConfig.xlsx`；若疑似 Excel 有用户未同步到 JSON 的手改，**先停下询问**，别直接覆盖。只分析方案时不擅自改配置。
- 工作簿 sheet：`Units`（单位数值；`attack_interval_s`→JSON `attack_speed`）/ `Cards` / `CardSkills`（一行一积木，按 `card_id+order` 聚合）/ `Levels` / `Decks` / `Balance_View`（公式视图，不导出）/ `_Enums`（隐藏，不导出）。

## 目录布局
```
/logic   逻辑层（不依赖 Godot 渲染）
/view    显示层脚本与场景
/ai      AIController
/config  GameConfig.xlsx（策划源表）+ cards.json / units.json / levels.json（生成产物）
/tests   单元测试（test_*.gd） + test_runner.gd + test_case.gd
/tools   配置生成脚本等项目工具
```

## 工具链 / 常用命令
引擎：**Godot 4.6.3 stable**（**macOS / Homebrew**，`godot` 直接可用）。

```bash
HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd  # 跑全部单测
HOME=/private/tmp/godot-home godot --headless --editor --path . --quit                      # 验证导入/生成 .uid
godot --path . -e                                                                           # 打开编辑器 GUI
```
> 测试用自写轻量 runner（零依赖）：自动发现 `tests/test_*.gd`、跑 `test_*`、exit 0/1。新测试 `extends "res://tests/test_case.gd"`。
> push / `brew` / `uv` 等下载走代理：`HTTPS_PROXY=http://127.0.0.1:7897`。IDE = VS Code（`geequlim.godot-tools`，F5 调试）。

## godot-ai MCP（编辑器联动，**辅助工具**）
`addons/godot_ai/` 在 **Godot 编辑器开着时**起本地 MCP server（`127.0.0.1:8000/mcp`），让 AI 读写引擎（场景树/节点/脚本/截图/跑测试，工具名 `mcp__godot-ai__*`）。
**使用守则**：❌ 默认不主动用，仅用户明确叫用才用、绝不自行驱动引擎；✅ 被叫到时只读操作（看树/截图/读日志/跑测试）可直接做；⚠️ 写操作先按「一步一确认」。MCP 是补充手段，不替代真人肉眼验收。
> 安装/注册、管理命令、**画面/FX 验收协议**（截图序列/临时 harness 定格/日志掐时机）→ 见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

## 分支 / 提交 / 推送约定
- **开发在 `develop` 分支进行**；`main` 为稳定线，远端 `origin` = https://github.com/jchensh/godot-clash-pusher 。
- **仅当用户说"提交"时**才 `git commit`；提交后**顺带 `git push`**（develop 首次推送用 `git push -u origin develop` 建立跟踪）。
- 仍遵守"一步一确认"：每步做完先停下报告，待用户说提交再 commit+push。

## 当前进度
> 完整进度总览表 + 决策日志 + 当前阶段逐步见 [HISTORY.md](HISTORY.md)；V1/V2 详细历史归档于 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)。这里只放一句话现状。

- **V1 / V2 全部完成**（机制白膜 → 3-lane + 程序化换皮 + AI 难度 + 扩内容/数值平衡；详见归档）。
- **V3 进行中**（战斗核心 2D 重构 + 买断制单机，权威规划 [PLAN_V3.md](PLAN_V3.md)，方向见决策 36/37）：
  - V3-1 ✅ **2D 战斗 reboot**（取代 lane：地形/流场绕桥/仇恨分心/软推挤+攻击/塔反击/AI 2D/显示层 2D）
  - V3-2 ✅ 空军（飞兵越河 + 对空克制 `attack_targets`）
  - V3-3 ✅ 新技能积木（亡语召唤 `golem` / 治疗术 `heal`）→ 16 卡 / 10 单位
  - 单测 **129/129**；**V3-1h / V3-2 / V3-3 的画面·手感留真人实机验收**（首次可玩 2D 重构）。
- **Now**：下一步 **V3-4 Roguelite 主轴**（run / 节点地图 / 连战 / draft 三选一 / relic / boss / 存档）。
