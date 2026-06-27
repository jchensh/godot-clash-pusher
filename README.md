# Godot Clash Pusher

竖屏「皇室战争式」2D 对推手游 —— **Godot 4.6.3 / GDScript**(客户端)+ **Go**(服务端)。圣水 + 循环卡组,在 2D 场地上自由部署单位,绕桥过河、推塔决胜。

> **当前定位(决策 48,2026-06-26)= 实时在线 F2P 商业手游,服务器权威**:进游戏强制登录 + 持久连接、服务器唯一权威(账号/钱包/养成/进度/配置全在服务器 + PostgreSQL)、客户端为瘦表现层、断线即不可玩。PvE 在线闯关养成为主轴(100+ 关 + 货币经济 + 卡牌升级/升阶 + 挂机);PvP lockstep 联网对战为支线。早期 V1~V3「单机原型」与决策 47「单机本地」**已被取代**。

## 当前状态

- ✅ **V1**:机制白膜(单 lane、圣水、循环卡组、三塔胜负、规则 AI、技能积木)。
- ✅ **V2**:3-lane 玩法深度 + 程序化美术换皮 + 动画特效 + 规则 AI 升级(攻防 + 难度分级)+ 内容扩展(14 卡 / 9 单位 + 自由组卡)+ 数值平衡 pass。
- ✅ **V3**:战斗核心 2D 重构(河 + 双桥 + 流场绕桥寻路 + 完整仇恨 + 软推挤碰撞 + 塔反击)+ 空军 + 新积木(亡语/治疗)+ Roguelite 主轴(连战链 + draft + relic + boss + meta 解锁)+ 交互手感(拖拽部署 / 移动插值 / 受击反馈 / 顿帧 / 震屏)+ 像素精灵美术 + 多语言 i18n + 音频骨架 + 像素 UI 设计系统 + 新手战役(6 教学关)+ 引导覆盖层。
- ✅ **V4**:联网地基 S0~S4 全部完成(KAN-36~40)——协议脚手架 + 匿名 device_id 登录 + 玩家档案云存档 + **lockstep 实时对战**(头号工程,两台 Windows 真机对战验收过)+ 匹配(ELO + Redis ZSET,真机验收过)。S5 赛季/榜暂缓。
- 🚧 **V5(进行中)**:实时在线 F2P 闯关养成(服务器权威)。
  - **本地原型 S0~S6 完成**(养成/经济/闯关逻辑)。
  - **在线化 N1~N7 整线收官**:持久 WS 会话 + 登录门 → 配置服务器化下发 → 服务器权威经济状态 + DB → 升级/升阶/解锁服务器结算 → 通关发奖 + sanity 校验 → 挂机服务器时钟结算(改本地时钟无效)→ 瘦客户端化(`EconomyStateCache` 持服务器权威缓存,本地存档降为非权威镜像)。
  - **S7 UI 整合 a~e 完成**(KAN-58 Done):基地 Hub + 闯关地图 + 领奖开箱 + 养成 collection/detail + deck builder 接已解锁卡;真人全流程验收过。
  - **下一站 = S8 内容铺量**(100 关 + ~15 遭遇模板 + 平衡 pass)。
- 客户端单元测试:**290/290 通过**。

## 玩法概览

- 竖屏 2D 场地(18×32 tile 网格):河横贯中部 + 左右双桥 + 每方 2 公主 1 王。
- 玩家 / AI / 网络对手都通过同一套逻辑入口出牌(V4 起:网络玩家走 lockstep,仍对称)。
- 圣水随固定逻辑 tick(10Hz)回涨,出牌消耗圣水;卡组 8 张循环,手牌 4 张。
- 兵牌部署在己方半场任意点;纯伤害法术不受半场限制。
- 地面兵沿流场距离绕到最近桥过河;空军直线越河、忽略地形。
- 完整 CR 式仇恨(可拉扯/风筝/堵路);王塔归零立即判负,超时按剩余塔血总和判胜负。

**V5 养成主轴**:推关 → 掉金币 + 卡牌碎片 → 升级(提数值)/升阶(数值跳变 + 解锁新技能积木)→ 战力↑ → 攻克更高难度系数的关 → 循环;挂机离线产出平滑节奏。

## 技术架构(服务器权威)

```
客户端 (Godot 4.6.3 / GDScript)              服务端 (Go)
┌─────────────────────────────────┐         ┌──────────────────────────────┐
│ view/   显示层(场景/UI/动画/FX) │         │ gateway  WebSocket 接入 + 会话 │
│ logic/  战斗确定性 sim(10Hz,lockstep)│◄────►│ battle   对战 room + 哈希对帐   │
│ net/    WS客户端 + protobuf + token │  WS+pb │ api      HTTP(经济/养成/发奖) │
│ config/ 配置(服务器下发,薄缓存)   │         │ store    PostgreSQL(pgx)      │
│ EconomyStateCache 服务器权威养成缓存│         │ Redis    匹配队列 / 限流       │
└─────────────────────────────────┘         └──────────────────────────────┘
  瘦表现层 + 非权威缓存                        唯一权威(账号/钱包/养成/进度/配置)
```

- **服务器唯一权威**:钱包/货币/卡养成/关卡进度/挂机全在服务器 + PG(服务器时钟结算,改本地存档/改时钟均无效);战斗仍客户端 lockstep(服务器下发权威输入,客户端确定性算数值)。
- **逻辑层 / 显示层彻底分离**:真实状态在 `logic/`,画面只读状态并插值。
- **确定性**:单位位置用抽象 2D tile 空间(不用屏幕像素);10Hz 固定 tick 结算、不绑渲染帧;**无随机**(lockstep 依赖)。
- **自写确定性 2D 软分离**做单位碰撞(体积半径 + 固定顺序推开重叠),不用物理引擎。
- **流场寻路**:对每塔预算 BFS 距离场,地面兵沿梯度自动绕桥。
- **配置全走 JSON**(`config/cards.json` / `units.json` / `levels.json` / `stages.json` / `economy.json` / `card_progression.json` …;`GameConfig.xlsx` 是策划镜像工作簿)。
- 客户端自写轻量 headless 测试 runner(零依赖);服务端 Go 标准测试(unit + integration,跨包串行需 PG+Redis)。

## 开发模式:多 AI Agent 协作

本项目由开发者主导,使用**多个 AI coding agent 协作**完成代码与文档:

| Agent | 模型 | 角色 |
|---|---|---|
| Claude Code | Opus 4.8 | 主力 agent(逻辑层 / 服务端 / 规划文档) |
| Codex | GPT 5.5 | 客户端 / 配置 / 测试 |
| Antigravity | Gemini 3.5 Flash | 安卓打包(`release` 分支)等 |
| ZCode | GLM 5.2 | 文档 / 辅助开发 |

> ⚠️ 这**不是**多 agent 自动协作系统——各 agent 之间没有自动调度或互联,所有工作分配、任务拆分、推进节奏都由**开发者人工主导**;agent 只是执行者,按「一步一确认」纪律逐步交付。每个 agent 读同一套 `AGENTS.md` / `CLAUDE.md` 操作手册保持口径一致(分别给不同 agent 看的对等副本)。

## 目录结构

```text
logic/    核心战斗逻辑(不依赖渲染;V4 lockstep 沿用本层确定性 tick)
view/     Godot 场景与显示层脚本
ai/       规则 AI(单机训练营用;V4 联机模式不调用)
net/      网络层(WS 客户端 + protobuf 解析 + token 存盘 + EconomyStateCache)
proto/    共享 protobuf 定义(.proto 源 + 双端生成产物)
server/   Go 服务端(cmd/{gateway,api,battle,migrate} + internal/* + migrations/ + Dockerfile + go.mod + Makefile)
config/   运行时配置 JSON + GameConfig.xlsx / AudioConfig.xlsx 策划镜像
sound/    音频文件根目录
assets/   美术素材;testAssets/ 原始素材库
tools/    配置生成 / 音频配置生成等项目工具
tests/    客户端单元测试 + 自写测试 runner
scripts/  本地环境辅助脚本
addons/   第三方插件(godobuf / godot-ai)
docs/     归档文档(PLAN_V1/V2/V3、HISTORY_ARCHIVE、HISTORY_V3_DETAILED、ART_ASSETS、ENVIRONMENT)
```

## 运行项目

前置:Godot 4.6.3 stable(GDScript 标准构建);Go(服务端);Docker(起 PG + Redis + 三个服务)。Windows 环境细节见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

```bash
# 客户端:打开编辑器
godot --path . -e
# 运行主场景
godot --path .
# 跑全部单元测试(逻辑层验收主手段)
godot --headless --path . --script res://tests/test_runner.gd

# 服务端:起 5 容器(pg / redis / gateway / api / battle)
cd server && docker compose up
# 跑 DB 迁移
make migrate
```

## 开发路线

全局 roadmap 见 [PLAN_GRAND.md](PLAN_GRAND.md),当前阶段权威规划见 [PLAN_V5.md](PLAN_V5.md)。已完成阶段规格:[docs/PLAN_V1.md](docs/PLAN_V1.md) / [docs/PLAN_V2.md](docs/PLAN_V2.md) / [docs/PLAN_V3.md](docs/PLAN_V3.md) / [PLAN_V4.md](PLAN_V4.md)。

- **V5(当前)**:在线闯关养成。S0~S6 本地原型(养成/经济/闯关)→ N1~N7 服务器权威在线化(已收官)→ S7 UI(已完成)→ **S8 100 关内容铺量 + 平衡**(进行中)。
- **V6+(远期,上线化)**:IAP 支付 + 正式登录/合规(SMS/邮箱/Apple/Google + 实名/防沉迷/版号)+ 云部署(K8s/HA/监控)+ 赛季/排行榜/社交/反作弊深化。

## 接手与协作

- [HISTORY.md](HISTORY.md):当前进度、关键决策、踩坑与验收记录(接手项目时最重要的历史来源)。
  - 进入 V4 时 HISTORY.md 已过长,做过一次**缩写 + 历史归档**:V1/V2 详细历史 → [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md),V3 → [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md),主文件只保留进度总览 + 决策日志 + 当前阶段。
- **Jira 看板(project `KAN`)**:Story / Task 的结构化进度真相源,与 HISTORY.md(叙事/决策/踩坑)并列。各 agent 通过 **Atlas(Atlassian)MCP 连接器**自动更新需求/任务状态(Idea → To Do → In Progress → Done 的生命周期维护);**但 Done 与 git commit 一样需开发者拍板**,agent 不擅自标完成。
- [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md):agent 操作手册(开发纪律、DO-NOT、配置工作流、目录布局、当前进度)。
- [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md):Godot、Go、Docker、godot-ai MCP、Atlas MCP、`uv`、代理与本机环境复现。

**开发纪律**:按 `PLAN_V5.md` 步骤顺序、一步一确认;每步 commit + 同步 HISTORY.md + Jira 看板;逻辑层步骤必配单元测试;表现/手感步骤交真人实机验收。**V4 起 DO-NOT**:客户端禁止权威化战斗状态;**决策 48 起 DO-NOT**:客户端禁止权威化任何经济/养成/进度/配置。
