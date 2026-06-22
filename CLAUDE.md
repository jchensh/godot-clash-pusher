# CLAUDE.md

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
- **音频资源表单独走 `config/AudioConfig.xlsx` → `config/audio_assets.json`**：Godot 运行时只读 JSON，不直接读 xlsx；音频文件统一放根目录 `sound/` 下（`bgm/`、`sfx/`、`ui/`、`stingers/`、`ambience/`）。常用命令：
  ```bash
  uv run --with openpyxl python tools/build_audio_config.py          # AudioConfig.xlsx → audio_assets.json
  uv run --with openpyxl python tools/build_audio_config.py --check  # 校验 xlsx↔json 一致
  uv run --with openpyxl python tools/build_audio_config.py --from-json
  ```
  `AudioAssets` sheet 中 `path` 是 **Godot 目标资源路径**，不是“文件已存在”的证明；`asset_status=planned/sourced/imported/final` 才表示素材状态。表内有 `display_name_zh` 中文资源名，`effect_notes` 必须写中文声音设计说明；`ColumnGuide` sheet 解释每一列用途。首版允许“清单先行、音频文件后补”：`AudioManager` 找不到实际 `.ogg/.wav` 时会静默跳过，避免空资源阶段阻塞开发。

## 目录布局
```
/logic   逻辑层（不依赖 Godot 渲染）
/view    显示层脚本与场景
/ai      AIController
/config  GameConfig.xlsx（策划源表）+ cards.json / units.json / levels.json（生成产物）
/sound   音乐/音效文件根目录（运行时路径来自 config/audio_assets.json）
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
- **`release` 分支**：用户用 Antigravity（Google IDE）创建，用于打安卓包；跟随 `develop` 推进，**agent 默认不在此分支提交、不主动同步**，需同步由用户主动指示。
- **仅当用户说"提交"时**才 `git commit`；提交后**顺带 `git push`**（develop 首次推送用 `git push -u origin develop` 建立跟踪）。
- 仍遵守"一步一确认"：每步做完先停下报告，待用户说提交再 commit+push。

## 当前进度
> 完整进度总览表 + 决策日志 + 当前阶段逐步见 [HISTORY.md](HISTORY.md)；V1/V2 详细历史归档于 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)。这里只放一句话现状。

- **V1 / V2 全部完成**（机制白膜 → 3-lane + 程序化换皮 + AI 难度 + 扩内容/数值平衡；详见归档）。
- **V3 进行中**（战斗核心 2D 重构 + 买断制单机，权威规划 [PLAN_V3.md](PLAN_V3.md)，方向见决策 36/37）：
  - V3-1 ✅ **2D 战斗 reboot**（取代 lane：地形/流场绕桥/仇恨分心/软推挤+攻击/塔反击/AI 2D/显示层 2D）
  - V3-2 ✅ 空军（飞兵越河 + 对空克制 `attack_targets`）
  - V3-3 ✅ 新技能积木（亡语召唤 `golem` / 治疗术 `heal`）→ 16 卡 / 10 单位
  - V3-4 ✅ Roguelite 主轴 a/b/c/d（决策 38/39）：骨架(RunState+线性连战链+二元永久死亡) + draft 三选一(卡组可增长) + relic(JSON 数值修正器、不污染 base) + boss/精英难度修正 + 局间 meta 解锁 + `user://` 存档 + 最简 run view（菜单 ROGUELITE→中枢→战斗→奖励→结算）
  - V3-6 ✅ 交互与游戏手感四 gate 代码完成（6a 拖拽部署真人 7/7 通过；6b 战斗 juice / 6c HUD / 6d 胜负·run 演出待真人手感验收）
  - V3-7 ✅ 精灵美术整阶段收官（单位/塔/FX·投射物/地形/卡面 + `docs/ART_ASSETS.md`）
  - V3-8 ✅ 音频资源表 + 运行时音频机制代码完成（`AudioConfig.xlsx`→`audio_assets.json`，首版 79 条；`sound/` 目录；`AudioManager` autoload；真实音频素材待补）
  - V3-9 ① ✅ 难度 5 档（rookie→extreme）；**V3-R 回归修复**（寻路绕桥/塔射箭/亡语裂兵不落水/攻击帧动画，真人 2026-06-21 通过）。
  - V3-UI ✅ 像素 UI 设计系统(PixelUI 9-slice) + 6 屏全统一（主菜单/选关/设置/组卡/run/战斗 HUD）+ 选关返回 bug 修复（真人 2026-06-21 通过）。
  - V3-5 ✅ 新手战役框架（5a）+ 引导覆盖层（5b，数据驱动 tutorial.json）（按决策 40 后置到 V3-6/7 之后执行，真人 2026-06-22 通过）。
  - 单测 **186/186**。
- **Now**：**V3-9 平衡剩余子项**可继续推进（数值/节奏调优 + 设置/导出/上架打磨）。
