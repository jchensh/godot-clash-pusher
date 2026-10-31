# 萌萌对垒 · Cuddly Clash

竖屏对推塔手游：圣水 + 循环卡组，在场地上自由部署单位，绕桥过河、推塔决胜。卡通萌系题材，**3D 战场 + 2D 界面**。
客户端 **Godot 4.6.3 / GDScript**，服务端 **Go + PostgreSQL + Redis**。

> **定位（决策 48）= 实时在线 F2P 手游，服务器权威**：进游戏必须登录并保持连接；账号、钱包、卡牌养成、关卡进度、配置全在服务器 + PostgreSQL；客户端只负责表现和本地战斗模拟；断线即不可玩。

## 🎮 在线试玩

| | 地址 |
|---|---|
| **正式服 Web 客户端** | **https://tower-push-godot.web.app** （浏览器直接打开，竖屏体验最佳） |
| 正式服后端（API + WebSocket） | `https://towerpushserver.jeffgame.tech` |

- 正式服由 `release` 分支发布（GCP 虚拟机 + Caddy 自动 HTTPS；Web 前端在 Firebase Hosting），当前是对有限测试人员开放的公网测试阶段，安全边界见 [GCP 发布手册](docs/deployment/GCP_RELEASE_TLS.md)。
- 正式服版本可能落后于 `master`：目前上线到 3D 迁移 D6，D7（菜单/卡详情 3D 预览）、D8（3D 特效）和 D8b（画质三档）尚未发布。
- ⚠️ 旧地址 `towerpush.web.app` 已弃用，历史文档里出现的一律作废。

## 现状一览（2026-10-31）

| | |
|---|---|
| **阶段** | 🚧 V5：实时在线 F2P 闯关养成 |
| **已完成** | V1 机制白膜 → V2 三路 + 换皮 → V3 2D 战斗 + Roguelite → V4 联网（账号 / lockstep 对战 / 匹配） |
| **V5 已完成** | 在线化 N1~N7、账号与新手引导、100 关 10 章闯关、卡牌升级/升阶、挂机、王国领地 K0~K5、卡通改版（48 卡，当前可玩 31 张）、上线工程 E0/E1 + E2-lite（HTTPS/WSS） |
| **进行中** | **全 3D 表现迁移**：D0~D8 已真人验收；D8b 画质三档代码完成、待验收；D5 联机双机验收欠账；D9 切换收官未开工 |
| **下一步** | 微信 / 抖音小游戏适配评估（低画质档即小游戏基线）；上线工程 E2 完整版（去 GM、WS 单次票据等） |
| **测试基线** | 客户端单测 ✅ **518 / 518**；Go unit + integration 全过；服务端 schema v9 |

最新进度以 [`HISTORY.md`](HISTORY.md) 为准（本表是快照）。

## 玩法

- **战斗**：10Hz 固定 tick 的确定性模拟；单位自动寻路绕桥、索敌、软分离碰撞；地面 / 空军、法术、亡语召唤等技能积木全部走配置。
- **PvE 闯关**：100 关、10 章，三星评价；金币 / 宝石 / 碎片经济，卡牌升级与升阶，离线挂机收益。所有产出和扣费由服务器结算。
- **PvP 对战**：lockstep 联网，服务器转发指令并对双方状态 hash 对帐，支持断线重连追帧。
- **王国领地**：城建经营（建造 / 升级 / 收取资源），城防养成反哺战斗塔。
- **防作弊**：PvE 战斗全程录制，服务端 verifier 容器用同一套逻辑代码重放校验。

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端引擎 | Godot 4.6.3 stable（GDScript，GL Compatibility 渲染器） |
| 表现层 | 3D 战场 / 王国 / 角色预览（Blender 程序化建模 + 卡通描边色阶着色），2D HUD 与菜单 |
| 服务端 | Go 1.25（gateway / api / battle / verifier / migrate） |
| 协议 | HTTP + WebSocket + protobuf（一份 `.proto` 双端生成） |
| 数据 | PostgreSQL 16 + Redis 7 |
| 部署 | 本地：Docker Compose 6 容器；正式服：GCP + Caddy（HTTPS/WSS）+ Firebase Hosting |
| 平台 | Web（正式服）、Android；开发在 Windows |

## 快速开始

```bash
git clone https://github.com/jchensh/godot-clash-pusher.git
cd godot-clash-pusher

# 客户端：跑全部单元测试（逻辑层验收主手段；Windows 下把 godot 换成本机 exe 路径）
godot --headless --path . --script res://tests/test_runner.gd

# 打开编辑器（主场景 view/main_menu.tscn）
godot --path . -e

# 服务端：起 6 容器（postgres / redis / gateway / api / battle / verifier）并迁移数据库
make up && make migrate
```

- 客户端默认连本地服务端，地址在 `config/network.json`。
- 改了 `logic/` 或 `config/` 后要 `docker restart server-verifier-1`（重放验证器挂载工程代码）。
- 环境前置（Go / protoc / Docker / 代理 / MCP）见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

## 仓库结构

单一 monorepo：Godot **客户端在仓库根**（`project.godot` 即工程根），Go **服务端在 `server/`**，配置与协议**双端共享**。

```
logic/          战斗逻辑层（确定性 10Hz tick，不依赖渲染）
view/           表现层：页面 + view/three_d/（3D 战场/王国/特效/画质档）+ view/ui/（设计系统）
ai/ net/        规则 AI；网络层（WS 客户端、protobuf、会话、经济缓存）
assets/ sound/  美术（含 assets/models/ 3D 模型）与音频
tests/          客户端单测 test_*.gd（自写零依赖 runner）
config/ proto/  双端共享：客户端 res:// 读 + 服务端挂载；proto 一份源双生成
server/         Go 服务端（cmd/* + internal/* + migrations/ + docker-compose）
docs/ tools/    文档；配置/平衡/性能/Blender 建模/发布脚本
```

> ⚠️ Godot 的 `res://` 不能跨工程根，所以客户端目录（含 `config/`）必须留在仓库根，只有 `server/` 独立。完整说明见 [`CLAUDE.md`](CLAUDE.md)「目录布局」。

## 文档

| 文档 | 内容 |
|---|---|
| [`docs/README.md`](docs/README.md) | **全仓文档地图**（每份文档一句话 + 状态） |
| [`docs/design/GDD.md`](docs/design/GDD.md) | 游戏策划总案（世界观 / 机制 / 系统 / 数值） |
| [`HISTORY.md`](HISTORY.md) | 进度真相源：总览表 + 决策日志 + 当前阶段逐步 |
| [`PLAN_V5.md`](PLAN_V5.md) | 当前阶段权威规划（含上线工程线 E0~E9） |
| [`PLAN_V5_3D.md`](PLAN_V5_3D.md) | 全 3D 表现迁移施工图 D0~D9 |
| [`PLAN_GRAND.md`](PLAN_GRAND.md) | 全项目 roadmap |
| [`docs/deployment/`](docs/deployment/) | 公网发布手册、上线门禁、Staging 拓扑 |
| [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) | AI agent 操作手册（纪律 / 铁律 / 工作流） |
| [Wiki](https://github.com/jchensh/godot-clash-pusher/wiki) | 2026-06-27 的一次性快照（3D、卡通改版、王国、正式服等之后的内容都没有），以仓库内文档为准 |

## 开发模式

多 AI agent 协作（Claude Code / Codex / Antigravity），开发者人工主导：按施工图一步一确认，每步配单测、更新 HISTORY.md，需要看画面的由真人验收。

- 稳定线 = `master`；大改动走临时 feature 分支 / worktree，验证后合回。
- `release` 跟随 `master`，用于发布正式服和打安卓包：`bash tools/deploy_prod.sh` 默认只演练，加 `--apply` 才真发布。
- 提交前：单测全绿、`gdlint .` 无报错、`python tools/check_docs.py` 通过，改配置还要跑 `tools/build_config.py --check`。
