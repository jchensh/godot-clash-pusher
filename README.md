# Godot Clash Pusher

竖屏「皇室战争式」2D 对推小游戏原型，使用 Godot 4.x / GDScript 开发。玩家与规则 AI 通过圣水和循环卡组部署单位，单位沿 lane 推进、交战并推塔决胜。

项目当前处于 V2 开发阶段：V1 单 lane 白膜可玩 demo 已完成，V2 正在把原型扩展为 3-lane、带程序化美术、动画特效、后续 AI 深度与内容扩展的版本。

## 当前状态

- V1 已完成：圣水系统、循环卡组、单位推进与碰撞、三塔胜负、三类技能积木、显示层 MVP、规则 AI。
- V2 A 模块已完成：3 条 lane、6 座塔、侧路公主塔倒后转打王塔、出牌选 lane、己方半场部署校验。
- V2 D 模块进行中：程序化美术换皮已完成；攻击、受击、死亡、投射物、AOE 爆点、塔摧毁等显示层动画与特效已完成并通过视觉验收。
- 下一步：V2-5，UI 美化、音频、主菜单与结算界面闭环。

当前测试状态见 [HISTORY.md](HISTORY.md)。截至最近记录，逻辑单元测试为 110/110 通过。

## 玩法概览

- 竖屏 720x1280，三条 lane 对推。
- 玩家与 AI 都通过同一套逻辑入口出牌，架构上保持对称。
- 圣水随固定逻辑 tick 回涨，出牌消耗圣水。
- 卡组为 8 张循环牌，手牌 4 张，出一张补一张。
- 兵牌部署在己方半场，可选择任意 lane；纯伤害法术不受半场限制。
- 中路直通王塔；左右路先打公主塔，公主塔摧毁后该路转打王塔。
- 王塔归零立即判负；时间到按剩余塔血总和判胜负。

## 技术特点

- Godot 4.6.3 stable，标准 GDScript 构建。
- 逻辑层与显示层分离：真实状态在 `logic/`，画面只读取状态并插值/播放反馈。
- 战斗位置统一使用 lane 进度 `0.0~1.0`，不依赖屏幕像素坐标。
- 游戏推进、圣水和时间使用固定逻辑 tick，不绑定渲染帧率。
- lane 碰撞用纯逻辑的队列关系判断，不使用 Godot 物理引擎处理单位互撞。
- 卡牌、单位、关卡数值均走 `config/` 下的 JSON 配置。
- 自写轻量 headless 测试 runner，无第三方测试依赖。

## 目录结构

```text
ai/       规则 AI
config/   卡牌、单位、关卡 JSON 配置
docs/     环境复现与工具链说明
logic/    核心战斗逻辑，不依赖渲染
scripts/  本地环境辅助脚本
tests/    单元测试与自写测试 runner
view/     Godot 场景与显示层脚本
```

## 运行项目

前置要求：

- Godot 4.6.3 stable，标准 GDScript 版本。
- 建议使用 Godot 编辑器打开工程；Windows 环境细节见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

打开编辑器：

```powershell
godot --path . -e
```

运行主场景：

```powershell
godot --path .
```

验证工程可导入/编译：

```powershell
godot --headless --editor --path . --quit
```

跑全部单元测试：

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

## 开发路线

全局 roadmap 见 [PLAN_GRAND.md](PLAN_GRAND.md)，当前阶段权威规划见 [PLAN_V2.md](PLAN_V2.md)。

V2 的执行顺序为：

1. A：3-lane 玩法深度。
2. D：表现、换皮、动画、音频、UI。
3. B：AI 攻防策略与难度分级。
4. C：扩卡池、组卡、多关卡与数值平衡。

V2 明确不做空中/地面克制、联机、匹配、聊天、防作弊和安卓打包。这些内容保留到后续阶段或需要分发时再处理。

## 接手与协作

- [HISTORY.md](HISTORY.md)：当前进度、关键决策、踩坑与验收记录，是接手项目时最重要的历史来源。
- [AGENTS.md](AGENTS.md)：给 Codex / Claude / 其他编程 agent 的项目入口守则。
- [CLAUDE.md](CLAUDE.md)：历史操作手册与常用命令。
- [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)：Godot、Godot AI MCP、`uv`、代理与本机环境复现说明。

开发纪律：

- 按 `PLAN_V2.md` 的步骤推进，一步一确认。
- 每个开发步骤完成后更新 `HISTORY.md`。
- 逻辑层改动必须补充或更新单元测试。
- 提交前至少跑一次全部测试。

## Godot AI MCP

项目已引入 `godot-ai` 插件（`addons/godot_ai/`），作为表现层开发时的辅助工具，可用于读取场景树、日志、截图、运行状态等。它只在 Godot 编辑器 GUI 打开时启动本地 MCP server；逻辑正确性仍以 headless 单元测试为准，视觉和手感验收仍以人工实机确认为准。

详细配置和排查方式见 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。
