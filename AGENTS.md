# AGENTS.md

竖屏「皇室战争式对推小游戏」，**Godot 4.6.3 / GDScript**（客户端）+ **Go**（V4 起服务端），**Windows 开发**（早期 V1/V2 历史在 macOS）。玩家 vs 规则 AI（V3 完）/ 玩家 vs 玩家（V4 起，lockstep 联网）；圣水 + 循环卡组、**2D 场地自由部署、绕桥推塔决胜**；单机：短战役 + Roguelite（V3 已完，留作单人训练营）；联机：天梯 + 赛季 + 排行榜（V4 玩法验证阶段）。长期 F2P，但前期不实现支付。

> **编码前必读**：[PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）→ [PLAN_V4.md](PLAN_V4.md)（**当前阶段权威规划**）；[docs/PLAN_V3.md](docs/PLAN_V3.md) / [docs/PLAN_V2.md](docs/PLAN_V2.md) / [docs/PLAN_V1.md](docs/PLAN_V1.md) 是已完成阶段的规格（存档备查）。本文件只是操作手册，当前阶段规格以 PLAN_V4.md 为准。

## 开发纪律（最高优先级）
- **一步一确认**：严格按 PLAN_V4.md 的施工图步骤顺序；**每完成一步停下等用户确认**，再进下一步，不要一次做多步。
- **每步一次 git commit**，message 描述本步内容（如 `V4-S0: proto schema + go scaffold`）。
- **每步同时更新 [HISTORY.md](HISTORY.md)**：记录新增/修改文件、决策、踩坑与修复、验收结果，随该步一起 commit。它是跨对话的进度与历史真相源。V3 及更早的详细段写到 `docs/HISTORY_V3_DETAILED.md`（V3）/ `docs/HISTORY_ARCHIVE.md`（V1/V2），不再追加到主 HISTORY.md。
- **每步同步 Jira 看板（project `KAN`）**：规划时把步骤建成 issue（确定做→`To Do` / 仅构思→`Idea`）；开工时改 `In Progress`；**做完 + 测试通过 + 经用户明确同意后**才改 `Done`（等同 git commit，需用户拍板，不擅自标完成）。Jira KAN 与 HISTORY.md 并列为 PM 真相源，详见下文「PM 工作流 / Jira 看板」。**前提：必须装 Atlas（Atlassian）MCP 连接器**——Claude Code 与 Codex 都要装，没装就停下提示用户装、不要跳过 Jira 步骤；安装/注册见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。
- **逻辑层步骤必须配单元测试**（客户端 GDScript 走 `tests/test_*.gd`；V4 服务端 Go 走 `server/.../*_test.go`），测试通过才算完成。
- **遇配置含义/接口不清，先提问，不要猜着往下跑。**
- 给成功标准而非实现细节；不自行扩大范围。
- **需实机操作验证的（点界面、看画面/动画/手感等表现层行为），优先让真人验收**：AI 不要自己去驱动鼠标点引擎窗口跑（低效、易错）。正确做法 = AI 写好**可执行的测试用例**（开什么场景、点哪、预期看到什么、判定通过的标准），用户在 Godot 编辑器里执行后回报 通过/不通过；AI 据反馈修。能 headless 单测覆盖的逻辑仍走单测，**只有真正需要肉眼看画面的才交给真人**。V4 真人对战也属于这类（两台机器实测）。

## 硬性 DO-NOT
- ❌ 不用物理引擎（`RigidBody2D`/`Area2D`）做单位碰撞——用**自写的确定性 2D 软分离**（固定顺序遍历推开重叠），纯逻辑、可单测。
- ❌ 逻辑层禁用**渲染/屏幕像素坐标**——单位位置用**抽象 2D 场地坐标**（tile 空间，view 负责映射）。详见 [docs/PLAN_V3.md](docs/PLAN_V3.md) §4。
- ❌ 游戏速度禁绑渲染帧率——圣水/时间/推进用**固定逻辑 tick (10Hz)** 结算，显示层做插值。**确定性无随机**（V4 lockstep 依赖此前提）。
- ❌ **V4 起：客户端禁止权威化战斗状态**——所有出兵/法术指令必须经服务端转发；战斗状态以双方+服务端三方 hash 对帐为准（lockstep 路线）；客户端本地预测仅用于显示插值，不影响仲裁。
- ❌ 不过度设计，不写用不到的「未来扩展」代码。**V4 schema 预留的 F2P 字段（IAP/养成/货币）属玩法验证范围外，仅建表不实现逻辑**。
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
/logic   客户端逻辑层（不依赖 Godot 渲染；V4 lockstep 沿用本层确定性 tick）
/view    客户端显示层脚本与场景
/ai      AIController（单机训练营用；V4 联机模式不调用）
/net     V4 网络层：WS 客户端 + protobuf 解析 + token 存盘（S1+ 起加）
/config  GameConfig.xlsx（策划源表）+ cards.json / units.json / levels.json / arena.json / run.json / relics.json / campaign.json / tutorial.json / i18n.json / audio_assets.json（运行时读）
/sound   音乐/音效文件根目录（运行时路径来自 config/audio_assets.json）
/tests   客户端单元测试（test_*.gd） + test_runner.gd + test_case.gd
/tools   配置生成脚本等项目工具
/proto   V4 共享 protobuf 定义（.proto 源 + 生成产物入 client net/proto + server internal/pb）
/server  V4 Go 服务端（cmd/{gateway,api,battle,migrate} + internal/* + migrations/ + Dockerfile + go.mod + Makefile）
/docs    归档文档（PLAN_V1/V2/V3、HISTORY_ARCHIVE、HISTORY_V3_DETAILED、ART_ASSETS、ENVIRONMENT）
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

## PM 工作流 / Jira 看板（Atlas MCP，**Claude Code + Codex 都适用**）

项目用 **Jira project `KAN`**（站点 `jchensh.atlassian.net`）作为 PM 真相源，与 [HISTORY.md](HISTORY.md) 并列：HISTORY.md 记**叙事/决策/踩坑**，Jira 记**结构化进度看板**。读写经 **Atlas（Atlassian）MCP 连接器**——**Claude Code 与 Codex 都必须装该 MCP**；没连上就停下提示用户装，**不要静默跳过 Jira 维护**。安装/注册/连通性检查见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

- **层级映射**（团队管理项目，Epic 下只有一层，故不用 Feature）：**Epic = 版本线**（V1=`KAN-5` / V2=`KAN-6` / V3=`KAN-7` / V4=`KAN-8`）；**Story = 玩法/玩家价值步**；**Task = 工程/基建步**；**Bug = 回归修复**。小步（a/b/c）按中粒度折进 issue 描述，不单独建 Subtask（除非用户要求）。
- **状态语义（按状态名理解，不看 Jira 内部 category）**：`Idea` = 构思中可能不做（建单默认）；`To Do` = 已明确排进计划、确定要做；`In Progress` = 正在开发中；`Done` = 做完且测过、**经用户同意**。
- **生命周期（主动维护，与「一步一确认」一致）**：①规划建单 → ②开工改 `In Progress` → ③完成 + 测过 + 用户同意 → 改 `Done`。改 `Done` 与 `git commit` 同属需用户拍板的收尾动作。

## 当前进度
> 完整进度总览表 + 决策日志 + 当前阶段逐步见 [HISTORY.md](HISTORY.md)；V1/V2 详细历史归档于 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)；V3 详细历史归档于 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。这里只放一句话现状。

- **V1 / V2 / V3 全部完成**：V1 机制白膜 → V2 3-lane + 程序化换皮 + AI 难度 + 内容平衡 → V3 2D 战斗 reboot + 空军 + 新积木 + Roguelite 主轴 + 交互手感 + 精灵美术 + 音频骨架 + 难度 5 档 + 像素 UI 设计系统 + 新手战役 + 引导。客户端单测 **186/186**。
- **V4 进行中**（联网升级 + 实时对战，权威规划 [PLAN_V4.md](PLAN_V4.md)，方向锁定见决策 46）：
  - **战斗权威 = lockstep + 状态哈希校验**（沿用现有 `logic/` 10Hz 确定性 tick，不重写 Go 战斗逻辑）。
  - **服务端 Go / 协议 WS+protobuf / 库 PG+Redis / 认证 JWT+匿名 device_id**。
  - **当前阶段 = 玩法验证**：S0 脚手架 → S1 匿名登录 → S2 档案云存档 → **S3 lockstep 实时对战（头号工程）** → S4 匹配 → S5 赛季+榜。
  - **产品化推后**：S6 战绩回放 / S7 反作弊深化 / S8 部署上线 / S9 版本管理 / S10 IAP+养成 / S11 正式登录+合规 / S12 聊天好友。
  - **V3 Roguelite + 短战役 + 平衡剩余子项**作为单人训练营保留不动；V3-9 平衡可与 V4-S0~S2 并行做。
- **Now**：**V4-S0 起步**（写 PLAN_V4 ✅ → 写 protobuf schema + Go 项目脚手架 + Docker Compose + Makefile）。
