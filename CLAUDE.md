# CLAUDE.md

<!-- AGENT-SHARED:BEGIN -->
> **共享规范镜像**：Claude Code、Codex 及其他智能体必须先读 [docs/engineering/AGENT_SHARED_RULES.md](docs/engineering/AGENT_SHARED_RULES.md)。`HISTORY.md` + Jira 是当前进度真相源；Prod 无 GM、长期 JWT 不进 URL、Gateway 状态外置前单活、占用 Godot/Docker 前先查占用并获许可。修改本块必须同步另一根级智能体文件，并运行 `python tools/check_docs.py`。
<!-- AGENT-SHARED:END -->

竖屏「皇室战争式对推小游戏」，**Godot 4.6.3 / GDScript**（客户端）+ **Go**（服务端），**Windows 开发**（早期 V1/V2 历史在 macOS）。**当前定位（决策 48，2026-06-26 起）= 实时在线 F2P 商业手游**：进游戏强制登录 + 持久连接、**服务器唯一权威**（账号/钱包/养成/进度/配置全在服务器 + PG DB）、客户端为瘦表现层（UI + 客户端 lockstep 战斗 sim + 非权威缓存）、**断线即不可玩**。玩法：圣水 + 循环卡组、**2D 场地自由部署、绕桥推塔决胜**；PvE 在线闯关养成（100+ 关 + 货币经济 + 卡牌升级/升阶 + 挂机）+ PvP lockstep 联网对战。早期 V1~V3「买断/单机」与决策 47「单机本地」**已被决策 48 取代**。

> **编码前必读**：[PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）→ [PLAN_V5.md](PLAN_V5.md)（**当前阶段权威规划：实时在线 F2P 闯关养成**）；[PLAN_V4.md](docs/PLAN_V4.md)（V4 联网线，S0~S4 完成、转 V5 主干）；[docs/PLAN_V3.md](docs/PLAN_V3.md) / [docs/PLAN_V2.md](docs/PLAN_V2.md) / [docs/PLAN_V1.md](docs/PLAN_V1.md) 是已完成阶段的规格（存档备查）。本文件只是操作手册，当前阶段规格以 PLAN_V5.md 为准。

## 开发纪律（最高优先级）
- **一步一确认**：严格按 PLAN_V5.md 的施工图步骤顺序；**每完成一步停下等用户确认**，再进下一步，不要一次做多步。
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
- ❌ **决策 48 起：客户端禁止权威化任何经济/养成/进度/配置**——钱包/货币/卡养成(等级·阶·解锁·碎片)/关卡进度/挂机全由**服务器算 + PG 落库**（服务器时钟，改本地存档/改时钟均无效）；所有产出/扣费/解锁/升级/升阶/领奖/挂机结算走服务器 API 校验；配置以**服务器为权威源**（登录下发带版本配置包），客户端只内存持有 + 薄版本缓存、不落权威。客户端本地缓存仅供秒启动/只读展示，永远以服务器覆盖。
- ❌ 不过度设计，不写用不到的「未来扩展」代码。（注：决策 48 起养成/货币/经济已是 V5 实做范围；仅 IAP 支付/合规 按上线节奏推后。）
- ❌ 不擅自删改与当前任务无关的代码/注释。

## 架构铁律
- **逻辑层 / 显示层彻底分离**：逻辑层持有真实状态（位置/血量/圣水），不关心画面；显示层每帧读逻辑状态画出来。
- 玩家与 AI **完全对称**：两者都只是「向逻辑层发指令」。
- 数值/卡牌**走配置，不硬编码**。Godot 运行时读取 `config/cards.json`、`config/units.json`、`config/levels.json`；`config/GameConfig.xlsx` 是给人类策划读改的工作簿镜像。
- **UI 层级走骨架，不走树序**（2026-07-05 起，PLAN_V5_UIFRAME/KAN-97）：覆盖类 UI（弹窗/确认框/结算/教程覆盖）一律继承 `view/ui/modal.gd` 经 autoload `UI.modal()` 推入弹窗层（CanvasLayer 50）；提示/跳字走 `UI.toast()`（90 层恒不挡手）。❌ 禁手搓全屏 Control 靠 add_child 树序压层（z_index 只管绘制不管点击命中，想挡输入必须配 mouse_filter）；前置 `Node._input` 拦截器（DragScroll 类）必须查 `UI.modal_open()` 对弹窗让路。规约细则见 `view/ui/pixel_ui.gd` 文件头。
- **场景切换走 Router，不散装**（2026-07-06 起，框架地基#1/KAN-99）：切场景一律 autoload `Router.goto(route)`（路由表 ROUTES 集中在 `view/scene_router.gd`，加新场景先登记再跳），重载走 `Router.reload()`；转场黑幕层 CanvasLayer=100（恒压 MODAL/TOAST，转场期挡输入防连点）。❌ 禁直调 `get_tree().change_scene_to_file` / `reload_current_scene`（`test_scene_router` 规约扫描把关，唯一豁免 = scene_router.gd 本体）。
- **跨模块通知走 Events 总线，逻辑层禁入**（2026-07-06 起，框架地基#2/KAN-100）：服务器状态变更→界面刷新走 autoload `Events` 信号（首个 `economy_changed`，发射端收口在 `EconomyStateCache._apply/seed_from_local`）；页面 `_ready` 订阅一次，动作 handler 不再手动重刷界面。加新信号原则：有真实消费方才加。❌ logic/ 战斗逻辑层禁用总线——lockstep 确定性要求调用顺序严格固定（`test_events` 源码扫描把关）。
- **日志走 Log，禁裸 print**（2026-07-06 起，框架地基#3/KAN-101）：客户端业务日志一律 `Log.d/i/w/e`（`view/log.gd` 静态类：相对时间戳 + 分级，release 构建剥离 d 级，w/e 转发引擎调试器），沿用 `[模块]` 前缀约定；d 用于高频噪声（modal 点击/PVE 批次上报类），失败/掉线/解析异常用 w。❌ view/net/logic/ai 禁裸 `print`（`test_log` 规约扫描把关；豁免 = log.gd 本体与 net/proto/ godobuf 生成物）。

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
> **一句话仓库地图**：单一 monorepo = 🎮Godot 客户端（**仓库根即 Godot 工程根**）+ 🖥Go 服务端（`server/`，独立 module）+ 🔗双端共享（`config/`·`proto/`）+ 📚文档（`docs/`）。
> **边界铁律**：Godot 的 `res://` **不能跨工程根** → 客户端相关目录（含 `config/`，客户端用 `res://config/*.json` 读）必须留在仓库根、**不能装进子文件夹**；只有 `server/` 可独立隔离。（这也是为何**不采用**"前端/后端/配置/文档"四平级——会断在 config 上；2026-06-28 评估结论。）
```
# ── 🎮 客户端 = Godot 工程（根 = project.godot 所在；res:// 相对此根）──
/logic    逻辑层（不依赖渲染；lockstep 沿用本层 10Hz 确定性 tick）
/view     显示层脚本与场景（autoload I18n/AudioManager；主场景 main_menu.tscn）
/ai       AIController（单机训练营 + V5-S8 平衡 probe 驱动；联机不调用）
/net      网络层：WS 客户端 + protobuf(net/proto/) + 会话/token + EconomyStateCache
/assets   在用美术（bosses/fonts/fx/map/terrain/towers/ui/units，已 import）
/sound    音乐/音效（路径来自 config/audio_assets.json）
/addons   godot-ai MCP 插件（编辑器联动辅助）
/tests    客户端单测 test_*.gd + test_runner.gd + test_case.gd
project.godot   Godot 工程入口（把工程根钉死在仓库根）

# ── 🔗 双端共享（客户端 res:// 读 + 服务端 CONFIG_DIR 挂载 / proto 双生成）──
/config   GameConfig.xlsx(策划源) + cards/units/levels/arena/stages/encounters/run/relics/campaign/tutorial/i18n/audio_assets.json（客户端 res://config/；服务端 docker 挂 ../config，决策48 同源）
/proto    共享 .proto 源 → 双生成：客户端 net/proto/*.gd + 服务端 internal/pb/*

# ── 🖥 服务端 = Go（独立 module，可隔离）──
/server   cmd/{gateway,api,battle,migrate} + internal/* + migrations/ + Dockerfile + docker-compose + go.mod + Makefile

# ── 📚 文档 / 工具 / 素材源 ──
/docs       归档与专题（PLAN_V1~V3、HISTORY_ARCHIVE、HISTORY_V3_DETAILED、ART_ASSETS、ENVIRONMENT、DESIGN/ACCEPTANCE/BALANCE_V5_*）
/tools      配置/平衡脚本（build_config.py、build_stages.py、balance_probe.gd…）
/scripts    环境脚本（setup-godot-ai.ps1）
/testAssets 原始美术素材源（84 PNG，加工后进 /assets；非运行时引用）
根 *.md     README / CLAUDE / AGENTS / PLAN_GRAND / PLAN_V5 + 支线施工图 / HISTORY（AI agent 真相源，刻意放根便于发现）
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

Lint（框架地基#4/KAN-102；规则=根 `gdlintrc`，取舍理由见其文件头；CI 在 `.github/workflows/lint.yml` 对 master 推送/PR 自动跑）：
```bash
HTTPS_PROXY=http://127.0.0.1:7897 uv run --with "gdtoolkit==4.*" gdlint .            # 静态检查（提交前必绿）
HTTPS_PROXY=http://127.0.0.1:7897 uv run --with "gdtoolkit==4.*" gdradon cc <路径>   # 圈复杂度报告（观测用）
```
> `gdformat` 备而不用：全库重排会污染 blame；新建文件可单独 `gdformat <file>`。

> ⚠️ 反作弊运维铁律：改 `logic/` 或 `config/` 后必须 `docker restart server-verifier-1`（重放验证器挂载工程代码跑重放）；**新增卡牌**还需重启 api 容器（`ensureSeeded` 播种 economy_cards）。

## godot-ai MCP（编辑器联动，**辅助工具**）
`addons/godot_ai/` 在 **Godot 编辑器开着时**起本地 MCP server（`127.0.0.1:8000/mcp`），让 AI 读写引擎（场景树/节点/脚本/截图/跑测试，工具名 `mcp__godot-ai__*`）。
**使用守则**：❌ 默认不主动用，仅用户明确叫用才用、绝不自行驱动引擎；✅ 被叫到时只读操作（看树/截图/读日志/跑测试）可直接做；⚠️ 写操作先按「一步一确认」。MCP 是补充手段，不替代真人肉眼验收。
> 安装/注册、管理命令、**画面/FX 验收协议**（截图序列/临时 harness 定格/日志掐时机）→ 见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

## 分支 / 提交 / 推送约定
> 与 [AGENTS.md](AGENTS.md)「分支 / 提交 / 推送约定」同口径（2026-06-28 起：`develop` 已删、改主干 + 临时 feature 分支流）。
- **稳定线 = `master`**（原 `main`，已于 2026-06-28 重命名合并；旧的 `develop` 分支已并入 `master`、不再维护）。远端 `origin` = https://github.com/jchensh/godot-clash-pusher 。
- **直接在 master 改（允许）**：文档/注释、配置小调、单行 bug fix 等改动小、风险低的内容，可直接在 `master` 工作树 commit，无需切 worktree。
- **切 worktree（推荐用于）**：功能开发、重构、多步改动、需要跑测试验证的任务——在独立 worktree 里开发，避免污染 master 且支持并行。
  ```bash
  git worktree add ../master-<feature> -b feat/<feature>   # 建 worktree + 临时分支
  cd ../master-<feature>                                     # 进 worktree 开发 + 提交 + 测试
  # 合回前先 rebase，把改动接到最新 master 末尾，冲突在自己这边解决
  git fetch origin && git rebase master                      # ⚠️ 必做，不可跳过
  cd <master 目录> && git merge --no-ff feat/<feature>       # 验证通过后合回稳定线
  git worktree remove ../master-<feature> && git branch -d feat/<feature>   # 清理
  ```
- **Claude Code 自动建的 worktree 分支**（`claude/<random-name>`）：Claude Code 每次新建 session 时自动从 master 创建，与 `feat/<feature>` 同等对待——开发完合回 master 后删除，不长期保留。
- **`release` 分支**：用户用 Antigravity（Google IDE）创建，用于打安卓包；跟随 `master` 推进，**agent 默认不在此分支提交、不主动同步**，需同步由用户主动指示。
- **打包前必检**：①`config/network.json` 的 `api_url`/`ws_url`（默认 localhost，真机/公网需改）；②安卓明文流量（cleartext）—— 当前定走 HTTPS/WSS（方式 B），公网服务端就绪前不打包正式联机包，详见 HISTORY.md「发布与打包」附录。
- **仅当用户说"提交"时**才 `git commit`；提交后**顺带 `git push`**。feature 分支首次推送用 `git push -u origin feat/<feature>` 建立跟踪（worktree 内推送同理）。
- 仍遵守"一步一确认"：每步做完先停下报告，待用户说提交再 commit+push。
- **Git 禁止事项**（违反时立即纠正）：
  - ❌ 禁止 `git push --force` 到 `master`——不可逆，必须警告用户确认
  - ❌ 禁止 `git commit --no-verify`——hook 失败要查根因修复，不绕过
  - ❌ 禁止 `git commit --amend` 已推送的 commit——用新 commit 修正
  - ❌ 禁止在 `master` 工作树目录直接开发功能——切 worktree

## PM 工作流 / Jira 看板（Atlas MCP，**Claude Code + Codex 都适用**）

项目用 **Jira project `KAN`**（站点 `jchensh.atlassian.net`）作为 PM 真相源，与 [HISTORY.md](HISTORY.md) 并列：HISTORY.md 记**叙事/决策/踩坑**，Jira 记**结构化进度看板**。读写经 **Atlas（Atlassian）MCP 连接器**——**Claude Code 与 Codex 都必须装该 MCP**；没连上就停下提示用户装，**不要静默跳过 Jira 维护**。安装/注册/连通性检查见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

- **层级映射**（团队管理项目，Epic 下只有一层，故不用 Feature）：**Epic = 版本线**（V1=`KAN-5` / V2=`KAN-6` / V3=`KAN-7` / V4=`KAN-8` / **V5=`KAN-50`**）；**Story = 玩法/玩家价值步**；**Task = 工程/基建步**；**Bug = 回归修复**。小步（a/b/c）按中粒度折进 issue 描述，不单独建 Subtask（除非用户要求）。
- **状态语义（按状态名理解，不看 Jira 内部 category）**：`Idea` = 构思中可能不做（建单默认）；`To Do` = 已明确排进计划、确定要做；`In Progress` = 正在开发中；`Done` = 做完且测过、**经用户同意**。
- **生命周期（主动维护，与「一步一确认」一致）**：①规划建单 → ②开工改 `In Progress` → ③完成 + 测过 + 用户同意 → 改 `Done`。改 `Done` 与 `git commit` 同属需用户拍板的收尾动作。

## 当前进度快照（非真相源；以 HISTORY.md + Jira 为准）
> 完整进度总览表 + 决策日志 + 当前阶段逐步见 [HISTORY.md](HISTORY.md)；全部文档索引见 [docs/README.md](docs/README.md)。这里只放一句话现状。

- **V1~V4 全部完成**（V4-S5 赛季/榜暂缓 KAN-41）；详细历史按版本线归档于 docs/HISTORY_*.md。
- **V5 = 实时在线 F2P 闯关养成（决策 48，服务器权威；[PLAN_V5.md](PLAN_V5.md)，Epic KAN-50）**：本地原型 S0~S8 + 在线化 N1~N7 + S9 账号/引导/菜单 + 卡池 16→48 + 框架地基（Router/Events/Log/lint）**代码全部完成**；S8e 难度手感等多组真人验收欠账，台账见 [docs/ACCEPTANCE_SANGUO.md](docs/ACCEPTANCE_SANGUO.md) 与各 ACCEPTANCE_* 文档。
- **Now = 上线工程线 E0~E9（[PLAN_V5.md](PLAN_V5.md) §13）**：E0 契约 + E1 在线主流程接线（唯一 `Online` autoload、fail-closed、结算幂等）已 Done；**下一步 E2 公网安全**（Prod 去 GM / WS ticket / WSS）。E2 完成前不得上公网、不打正式联机包。
- **内容支线**：**王国领地系统 K0~K5 代码完成**（城建经营+城防→塔养成维度，[docs/DESIGN_KINGDOM.md](docs/DESIGN_KINGDOM.md)/KAN-112，K6 IAP 待排、真人验收欠）；三国改版轨道A（A1~A3 欠验收、A4 文本/遭遇/奖励回填完成·素材接入进行中，[PLAN_V5_SANGUO.md](PLAN_V5_SANGUO.md)）；横版战斗 H3~H6 未开工（[PLAN_V5_HBATTLE.md](PLAN_V5_HBATTLE.md)）；UI 骨架 F 组验收欠（[PLAN_V5_UIFRAME.md](PLAN_V5_UIFRAME.md)）；数值线 KAN-87/88 挂起。
- 基线：客户端单测 **409/409**；Go unit+integration 全过；服务端 schema **v8**（0008_pve_battles）；docker **6 容器**（含 verifier）。
