# CLAUDE.md

竖屏「皇室战争式对推小游戏」，**Godot 4.x / GDScript**。玩家 vs 规则 AI，圣水 + 循环卡组部署单位，沿 lane 互推、推塔决胜。V1 纯 2D 白膜，先 Windows 跑通再导出安卓。

> **编码前必读**：[PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）→ [PLAN_V2.md](PLAN_V2.md)（**当前阶段权威规划**）；[PLAN_V1.md](PLAN_V1.md) 是已完成的 V1 规格（存档备查）。本文件只是操作手册，当前阶段规格以 PLAN_V2.md 为准。

## 开发纪律（最高优先级）
- **一步一确认**：严格按 PLAN_V2.md 的施工图步骤顺序；**每完成一步停下等用户确认**，再进下一步，不要一次做多步。
- **每步一次 git commit**，message 描述本步内容（如 `step2: elixir system + unit tests`）。
- **每步同时更新 [HISTORY.md](HISTORY.md)**：记录新增/修改文件、决策、踩坑与修复、验收结果，随该步一起 commit。它是跨对话的进度与历史真相源。
- **第 0~6 步是纯逻辑层，必须配单元测试，测试通过才算完成。**
- **遇配置含义/接口不清，先提问，不要猜着往下跑。**
- 给成功标准而非实现细节；不自行扩大范围。

## 硬性 DO-NOT
- ❌ 不用物理引擎（`RigidBody2D`/`Area2D`）做 lane 碰撞——用「队列前后关系」纯逻辑判断。
- ❌ 逻辑层禁用屏幕像素坐标——单位位置一律 `0.0~1.0` 的 lane 进度（**0=己方塔，1=敌方塔**）。
- ❌ 游戏速度禁绑渲染帧率——圣水/时间/推进用**固定逻辑 tick** 结算，显示层做插值。
- ❌ 不过度设计，不写用不到的「未来扩展」代码。
- ❌ 不擅自删改与当前任务无关的代码/注释。

## 架构铁律
- **逻辑层 / 显示层彻底分离**：逻辑层持有真实状态（位置/血量/圣水），不关心画面；显示层每帧读逻辑状态画出来。
- 玩家与 AI **完全对称**：两者都只是「向逻辑层发指令」。
- 数值/卡牌**全走 JSON 配置**（`config/cards.json`、`units.json`、`levels.json`），改数值不改代码。

## 目录布局
```
/logic   逻辑层（不依赖 Godot 渲染）
/view    显示层脚本与场景
/ai      AIController
/config  cards.json / units.json / levels.json
/tests   单元测试（test_*.gd） + test_runner.gd + test_case.gd
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
- Step 9 ⏸ 安卓导出（缓做，移至 V2 后续；编辑器内即可体验/开发）
- **V1 收官**。现进入 **V2**（顺序 A→D→B→C，权威规划见 PLAN_V2.md）：
  - V2-1 ✅ 3-lane 逻辑层：`Battle.build_v2_three_lanes` + `Lane` 侧路公主倒后转打王塔（决策日志 24–25）；`Match`/显示层/AI 仍单 lane。
  - **Now：V2-2** 多 lane 显示层 + 出牌选 lane（接通 `Match` 到 3 lane、画 6 塔布局、部署半场校验、AI 最小适配）。开工前定 HISTORY「仍待定」两项。
