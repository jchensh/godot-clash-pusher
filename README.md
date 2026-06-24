# Godot Clash Pusher

竖屏「皇室战争式」2D 对推小游戏，使用 **Godot 4.6.3 / GDScript**（客户端）+ **Go**（V4 起服务端）开发。玩家通过圣水和循环卡组在 2D 场地上自由部署单位，单位绕桥过河、推塔决胜。

V1/V2/V3 单机部分已全部完成（机制 → 3-lane 原型 → 2D 战斗 reboot + Roguelite + 精灵美术 + 新手战役 + 引导）。**V4 进行中**：联网升级 + 实时对战 + 服务端架构。

## 当前状态

- ✅ **V1**：机制白膜（单 lane、圣水、循环卡组、三塔胜负、规则 AI、技能积木）。
- ✅ **V2**：3-lane 玩法深度 + 程序化美术换皮 + 动画特效 + 规则 AI 升级（攻防 + 难度分级）+ 内容扩展（14 卡 / 9 单位 / 多关卡 / 自由组卡）+ 数值平衡 pass。
- ✅ **V3**：战斗核心 2D 重构（取代 lane：地形 + 流场绕桥寻路 + 完整仇恨 + 软推挤碰撞 + 塔反击）+ 空军 + 新积木（亡语/治疗）+ Roguelite 主轴（连战链 + draft + relic + boss + meta 解锁 + 存档）+ 交互手感（拖拽部署 + 移动插值 + 受击数字 + 顿帧 + 震屏）+ 像素精灵美术（10 单位 + 塔 + FX + 投射物 + 地形 tile + 卡面）+ 多语言 i18n + 音频骨架 + 难度 5 档 + 像素 UI 设计系统 + 6 屏统一 + 新手战役（6 教学关）+ 数据驱动引导覆盖层。
- 🚧 **V4 进行中**：联网 PvP + 匹配 + 赛季 + 排行榜（玩法验证导向，前期不实现支付/正式登录/云上线）。当前步骤 = **V4-S0**（protobuf schema + Go 项目脚手架 + Docker Compose）。
- 客户端单元测试：**186/186 通过**。

## 玩法概览

- 竖屏，2D 场地（18×32 tile 网格）：河横贯中部 + 左右双桥 + 每方 2 公主 1 王。
- 玩家与 AI 都通过同一套逻辑入口出牌（V4 起：网络玩家走 lockstep，仍对称）。
- 圣水随固定逻辑 tick（10Hz）回涨，出牌消耗圣水。
- 卡组为 8 张循环牌（roguelite 可增长到 ≥9），手牌 4 张，出一张补一张。
- 兵牌部署在己方半场任意点；纯伤害法术不受半场限制。
- 地面兵沿流场距离绕到最近桥过河；空军直线越河、忽略地形。
- 单位接敌后转火打架（CR 式完整仇恨），可拉扯/风筝、可堵路。
- 王塔归零立即判负；时间到按剩余塔血总和判胜负。

## 技术特点

- Godot 4.6.3 stable，标准 GDScript 构建。
- **逻辑层与显示层彻底分离**：真实状态在 `logic/`，画面只读取状态并插值/播放反馈。
- 单位位置用**抽象 2D tile 空间**（不依赖屏幕像素坐标），view 负责映射。
- 游戏推进、圣水和时间使用**固定逻辑 tick (10Hz)**，不绑定渲染帧率。**确定性无随机**（V4 lockstep 联机依赖此前提）。
- 单位碰撞用**自写确定性 2D 软分离**（体积半径 + 固定顺序遍历推开重叠），不使用 Godot 物理引擎。
- 流场寻路（对每塔预算 BFS 距离场，地面兵沿梯度自动绕桥）。
- 卡牌、单位、关卡、roguelite、relic、新手战役、引导、i18n、音频清单全走 `config/` 下的 JSON 配置（`GameConfig.xlsx` 是策划镜像）。
- 自写轻量 headless 测试 runner，无第三方测试依赖。
- V4 起：服务端 Go + WebSocket + protobuf + PostgreSQL + Redis，本地 Docker Compose 起。

## 目录结构

```text
ai/       规则 AI（单机训练营用）
config/   卡牌、单位、关卡、roguelite、relic、新手战役、引导、i18n、音频 JSON 配置 + GameConfig.xlsx 策划镜像
docs/     归档文档（PLAN_V1/V2/V3、HISTORY_ARCHIVE、HISTORY_V3_DETAILED、ART_ASSETS、ENVIRONMENT）
logic/    核心战斗逻辑，不依赖渲染（V4 lockstep 沿用本层确定性 tick）
net/      V4 网络层（WS 客户端 + protobuf 解析 + token 存盘，V4-S1+ 起加）
proto/    V4 共享 protobuf 定义（.proto 源 + 双端生成产物）
server/   V4 Go 服务端（gateway/api/battle/migrate + docker-compose）
sound/    音频文件根目录
scripts/  本地环境辅助脚本
tests/    客户端单元测试与自写测试 runner
tools/    配置生成脚本等项目工具
view/     Godot 场景与显示层脚本
```

## 运行项目

前置要求：

- Godot 4.6.3 stable，标准 GDScript 版本。
- 建议使用 Godot 编辑器打开工程；Windows 环境细节见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

打开编辑器：

```bash
godot --path . -e
```

运行主场景：

```bash
godot --path .
```

跑全部单元测试：

```bash
HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd
```

V4 服务端（V4-S0 后可用）：

```bash
cd server && docker compose up
```

## 开发路线

全局 roadmap 见 [PLAN_GRAND.md](PLAN_GRAND.md)，当前阶段权威规划见 [PLAN_V4.md](PLAN_V4.md)。已完成阶段：[docs/PLAN_V1.md](docs/PLAN_V1.md) / [docs/PLAN_V2.md](docs/PLAN_V2.md) / [docs/PLAN_V3.md](docs/PLAN_V3.md)。

V4 玩法验证阶段（首批）：
1. S0 协议 + Go 脚手架 + docker compose。
2. S1 匿名 device_id 登录 + JWT。
3. S2 玩家档案云存档（schema 预留 F2P 字段但不实现）。
4. S3 **实时对战网络层（头号工程）**：lockstep + 状态哈希校验 + 断线重连。
5. S4 匹配（Redis ZSET + ELO）。
6. S5 赛季 + 排行榜。

V4 产品化（推后）：战绩回放 / 反作弊深化 / 部署上线 / 版本管理 / IAP+养成 / 正式登录+合规 / 聊天好友。

## 接手与协作

- [HISTORY.md](HISTORY.md)：当前进度、关键决策、踩坑与验收记录，接手项目时最重要的历史来源。V1/V2 详细历史见 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)；V3 详细历史见 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。
- [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md)：操作手册（开发纪律、DO-NOT、配置工作流、目录布局、当前进度），分别给 Claude Code / Codex/Antigravity 等编程 agent 看。
- [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)：Godot、Godot AI MCP、`uv`、代理与本机环境复现说明。

开发纪律：

- 按 `PLAN_V4.md` 的步骤推进，一步一确认。
- 每个开发步骤完成后更新 `HISTORY.md`（V3 及更早的详细段写到 `docs/` 归档）。
- 逻辑层改动必须补充或更新单元测试。
- 提交前至少跑一次全部测试。
- **V4 起新增 DO-NOT**：客户端禁止权威化战斗状态——所有指令走服务端转发，状态以双方+服务端三方 hash 对帐为准。

## Godot AI MCP

项目已引入 `godot-ai` 插件（`addons/godot_ai/`），作为表现层开发时的辅助工具，可用于读取场景树、日志、截图、运行状态等。它只在 Godot 编辑器 GUI 打开时启动本地 MCP server；逻辑正确性仍以 headless 单元测试为准，视觉和手感验收仍以人工实机确认为准。

详细配置和排查方式见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。
