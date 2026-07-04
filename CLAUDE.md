# CLAUDE.md

竖屏「皇室战争式对推小游戏」，**Godot 4.6.3 / GDScript**（客户端）+ **Go**（服务端），**Windows 开发**（早期 V1/V2 历史在 macOS）。**当前定位（决策 48，2026-06-26 起）= 实时在线 F2P 商业手游**：进游戏强制登录 + 持久连接、**服务器唯一权威**（账号/钱包/养成/进度/配置全在服务器 + PG DB）、客户端为瘦表现层（UI + 客户端 lockstep 战斗 sim + 非权威缓存）、**断线即不可玩**。玩法：圣水 + 循环卡组、**2D 场地自由部署、绕桥推塔决胜**；PvE 在线闯关养成（100+ 关 + 货币经济 + 卡牌升级/升阶 + 挂机）+ PvP lockstep 联网对战。早期 V1~V3「买断/单机」与决策 47「单机本地」**已被决策 48 取代**。

> **编码前必读**：[PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）→ [PLAN_V5.md](PLAN_V5.md)（**当前阶段权威规划：实时在线 F2P 闯关养成**）；[PLAN_V4.md](PLAN_V4.md)（V4 联网线，S0~S4 完成、转 V5 主干）；[docs/PLAN_V3.md](docs/PLAN_V3.md) / [docs/PLAN_V2.md](docs/PLAN_V2.md) / [docs/PLAN_V1.md](docs/PLAN_V1.md) 是已完成阶段的规格（存档备查）。本文件只是操作手册，当前阶段规格以 PLAN_V5.md 为准。

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
根 *.md     README / CLAUDE / AGENTS / PLAN_GRAND / PLAN_V5(+V4) / HISTORY（AI agent 真相源，刻意放根便于发现）
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

## 当前进度
> 完整进度总览表 + 决策日志 + 当前阶段逐步见 [HISTORY.md](HISTORY.md)；V1/V2 详细历史归档于 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)；V3 详细历史归档于 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。这里只放一句话现状。

- **V1 / V2 / V3 全部完成**：V1 机制白膜 → V2 3-lane + 程序化换皮 + AI 难度 + 内容平衡 → V3 2D 战斗 reboot + 空军 + 新积木 + Roguelite 主轴 + 交互手感 + 精灵美术 + 音频骨架 + 难度 5 档 + 像素 UI 设计系统 + 新手战役 + 引导。客户端单测 **217/217**（V4 累加）。
- **V4 进行中**（联网升级 + 实时对战，权威规划 [PLAN_V4.md](PLAN_V4.md)，方向锁定见决策 46）：
  - **战斗权威 = lockstep + 状态哈希校验**（沿用现有 `logic/` 10Hz 确定性 tick，不重写 Go 战斗逻辑）。
  - **服务端 Go / 协议 WS+protobuf / 库 PG+Redis / 认证 JWT+匿名 device_id**。
  - **当前阶段 = 玩法验证**：S0 脚手架 → S1 匿名登录 → S2 档案云存档 → **S3 lockstep 实时对战（头号工程）** → S4 匹配 → S5 赛季+榜。
  - **产品化推后**：S6 战绩回放 / S7 反作弊深化 / S8 部署上线 / S9 版本管理 / S10 IAP+养成 / S11 正式登录+合规 / S12 聊天好友。
  - **V3 Roguelite + 短战役 + 平衡剩余子项**作为单人训练营保留不动；V3-9 平衡可与 V4-S0~S2 并行做。
- **V4 完成线**：**V4-S0/S1/S2/S3 全部完成**。S0 脚手架 + 双端 protobuf；S1 匿名 device_id 登录；S2 玩家档案云存档（profile + decks + 乐观锁 + 离线缓存）；**S3 lockstep 实时对战（头号工程）整阶段收官**——确定性地基 + Go gateway/battle room + 客户端 net 层 + 联机对战场景 + 心跳/断线重连重放/超时认输，**两台 Windows 真机对战验收通过**（完整对局 + 实时同步 + 胜负入库）。客户端单测 **217/217**；Go battle 14 unit + auth/profile integration 全过。**V4-S0~S4 全部完成（KAN-36/37/38/39/40 Done）**。S4 匹配：profiles 加隐藏 MMR（ELO @1200，结算调分）+ 杯数（可见进度，主菜单显示）；Redis ZSET 队列（首次用 Redis）+ 窗口放宽匹配器 + Lobby 替代 Hub（FindMatch→配对→建房）；客户端匹配 UI（匹配中/取消）+ 会话自动登录。端到端真匹配 smoke + **两台 Windows 真机验收通过**（ELO 配对+对局+MMR/杯数入库）。客户端单测 **221/221**；Go unit + integration（含 Redis）全过。**V4-S5（赛季+排行榜）暂缓**（KAN-41 退回 To Do）。
- **Now = V5 在线 F2P 闯关养成**（**决策 48 推翻 47**：服务器权威、实时在线；权威规划 [PLAN_V5.md](PLAN_V5.md)，Epic KAN-50）：100+ 关闯关（难度系数）+ 货币经济（金币/碎片/宝石）+ 卡牌升级/升阶（数值 + 技能解锁）+ 挂机，**全部服务器权威**（账号/钱包/养成/进度/配置在服务器 + PG），客户端瘦表现层 + 持久连接 + 断线不可玩。**本地原型 S0~S6 完成**（单测 **270/270**；逻辑算法将镜像进 Go 做权威结算，客户端那份保留 UI 预览 + 战斗内计算）：S0 配置骨架 / S1 出兵数值乘区 / S2 存档+战力 / S3 闯关+星级 / S4 升级 / S5 升阶+技能解锁 / S6 经济产出。**转向后施工**：在线地基 + 服务器经济 **N1~N7 整线收官**——N1/N2 持久会话+登录门 + 配置服务器化下发；N3/N4 服务器权威经济状态+DB / 升级升阶解锁结算（服务器算成本+校验+落库）；N5 通关发奖+sanity；N6 挂机服务器时钟结算（堵改时钟刷资源）；N7 瘦客户端化（养成数据服务器权威 + 本地档降为非权威缓存，堵改存档）。复用 V4 的 Go+PG+账号+WS+lockstep 作地基（V4 服务端线从"暂缓"转主干）。
  - **S7 UI 整合完成（KAN-58 Done）**：基地 Hub + 闯关地图 + 领奖开箱 + 养成 collection/detail + 钱包/挂机/战力 + deck builder 接已解锁卡（接 EconomyStateCache + 服务器权威经济），真人全流程验收过；派生 **S7+ 养成卡多维排序（KAN-67 Done）** + **GM 作弊工具（KAN-68 Done，服务器权威改库；V5-S9/KAN-70 起去掉 `GM_ENABLED` 门控、所有部署含 prod 始终开放——用户决策）**。
  - **🚧 Now = V5-S8 内容铺量 + 平衡（KAN-59 进行中）**：S8a 遭遇模板池→15 / S8b 平衡 probe harness（AIController 可选边）/ S8c stages 生成器铺 **100 关** / S8d 敌塔随 coef 平衡 pass——**代码均已完成并提交**，剩 **S8e 真人验收**（从第 1 章推进体验难度曲线，`docs/ACCEPTANCE_V5_S8.md`）未签收。**客户端单测 313/313**。
  - **联机视觉对齐完成（KAN-49 Done，真人双机验收过——net_battle 满视觉 + 双方名片）**；V4-S5 赛季+榜暂缓（KAN-41）。
  - **✅ V5-S9 账号+引导+菜单改版完成（KAN-70~75，真人验收过）**：账号身份系统（创号起名+选怪物头像，服务器权威 + migration 0007）+ 名片显示（主菜单/PVE/PVP 双方）+ 新手引导自动化（创号后强制一局→主菜单）+ 主菜单重构（天梯征途/闯关/养成/卡组/探险/设置，去退出+新手战役入口）+ 天梯先选卡组再匹配 + GM 解禁。施工图 [PLAN_V5_S9_ACCOUNT_UX.md](PLAN_V5_S9_ACCOUNT_UX.md)。客户端 **313/313** + Go 全过 + 真 docker migrate→schema v7。
  - **🃏 卡池扩充线（KAN-80~89，独立于 S8/S9，2026-07-03 启动）**：16→48 卡三维体系设计（稀有度/流派/觉醒，[docs/design/01-04](docs/design/)）+ **三件套引擎(splash/building-target/status) + retrofit + KAN-85 铺 32 卡→48 + KAN-86 十六张 epic+legendary 觉醒**全完成（KAN-80~86/89 Done）；客户端 **353/353**。剩 KAN-87 probe 平衡 + KAN-88 延后件（**均挂起**，见三国化线）。⚠️ 反作弊运维铁律：改 logic/config→`docker restart server-verifier-1`；加卡→另重启 api（`ensureSeeded` 播种 economy_cards）。
  - **🀄 三国题材改版（轨道A，2026-07-04 启动）**：世界观/画风全换三国（魏/蜀/吴/群雄，热血物语高清像素），**卡ID/数值/机制/结构冻结**；施工图 [PLAN_V5_SANGUO.md](PLAN_V5_SANGUO.md)，美术真相源 docs/design/card_art_spec_48cards.xlsx（三国版）。**A1 美术表口径对齐 + A2 文案层三国化已完成待真人验收**（48 卡名/39 单位名/22 觉醒名 + cards.json `faction` 字段 12×4 + 稀有度显示名 寻常/精良/非凡/无双 + i18n 补全 48 卡双语——顺带修复 32 新卡 UI 显示原始键名的断层）；**A3 场景/系统美术清单已产出待评审**（docs/design/scene_system_art_spec.xlsx，6 sheet：塔分阵营 5 套/FX 18 项/UI 中式小改/头像 16/音频方向；决策 7~10 入 PLAN_V5_SANGUO §0）；A4 素材接入+世界观文本+遭遇奖励回填待做。**真人验收台账 = docs/ACCEPTANCE_SANGUO.md**（A1A2/A2.5/A3 均欠验收，Jira 建议 In Review）。**数值线 KAN-87/88 挂起**（轨道A 后复盘）。48 卡机制层已全可玩（GM 解锁后）；**A2.5 占位精灵铺满完成待验收**（sprite_db 39/39 全覆盖：复用贴图+tint 阵营染色+scale 体型 + `ph` 占位标记与替换三步指引）。**四滚动界面（组卡/创号/图鉴/闯关）统一 `view/ui/drag_scroll.gd` 鼠标按住拖动**（真机触摸走引擎原生）；**首批 BGM 已入库**（菜单 Oriental / 战斗 Ninja Theme，均 OpenGameArt CC0 可商用免署名，AudioManager 已补清单 loop 生效）。客户端 **358/358**。**横版战斗（表现层）已立项未开工**：施工图 [PLAN_V5_HBATTLE.md](PLAN_V5_HBATTLE.md)（纵改横便于侧视帧素材，logic 零改动、纵横共存，建议排 A3 后）。
