# AGENTS.md

本文件是给 Codex / Claude / 其他编程 agent 的项目入口守则。开始任何编码、重构、测试、提交前，先读本文件，再按下方顺序读取项目资料。

## 必读顺序

1. 先读 [PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）与 [PLAN_V2.md](PLAN_V2.md)（**当前阶段权威规划**，规格、步骤、验收标准以它为准）；[PLAN_V1.md](PLAN_V1.md) 为已完成的 V1 规格（存档备查）。
2. 再读 [HISTORY.md](HISTORY.md)：当前进度、已完成步骤、历史决策、踩坑记录。
3. 必要时读 [CLAUDE.md](CLAUDE.md)：原 Claude Code 操作手册；其中 Windows 工具链命令仅作历史参考，Mac 命令以本文件为准。

## 开发纪律

- 严格按 `PLAN_V2.md` 的施工图步骤推进（V1 已完成，见 `PLAN_V1.md`）。
- 一步一确认：完成一个步骤后停下，等待用户确认，再进入下一步。
- 每步完成后更新 `HISTORY.md`，记录新增/修改文件、关键决策、踩坑、验收结果。
- 每步一次 git commit，commit message 描述本步内容，例如 `step3: deck cycle system + unit tests`。
- 第 0~6 步是纯逻辑层，必须配单元测试；测试通过才算完成。
- 遇到配置含义、接口语义、战斗规则不清楚时，先问用户，不要猜。
- 不自行扩大范围，不写当前步骤用不到的未来扩展代码。
- 不擅自删改与当前任务无关的代码、注释、配置或历史记录。
- 需实机操作验证的（点界面、看画面/动画/手感等表现层行为），优先让真人验收：不要自己驱动鼠标点引擎窗口跑（低效易错）。正确做法 = 写好可执行的测试用例（开什么场景、点哪、预期看到什么、判定标准），用户在 Godot 编辑器执行后回报 通过/不通过，再据反馈修。能 headless 单测覆盖的逻辑仍走单测；只有真正要肉眼看画面的才交给真人。表现层（D 模块起）此类验收会很多。

## 硬性禁止

- 不用 Godot 物理引擎处理 lane 碰撞；不要用 `RigidBody2D` / `Area2D` 做单位互撞。
- 逻辑层不依赖屏幕像素坐标；单位位置统一使用 `0.0~1.0` 的 lane 进度，`0=己方塔`，`1=敌方塔`。
- 游戏速度不绑定渲染帧率；圣水、时间、推进用固定逻辑 tick，显示层只做读取和插值。
- 不绕过 JSON 配置硬编码数值；卡牌、单位、关卡数值走 `config/`。

## 当前工程环境

- 项目根目录：`F:\godotProject`（历史 Mac 路径 `/Users/jeffchen/godot-develop` 仅作旧记录参考）
- 引擎：Godot `4.6.3 stable`，标准 GDScript 构建。
- 仓库：`https://github.com/jchensh/godot-clash-pusher`
- 稳定分支：`main`
- 当前开发分支：`develop`
- GitHub CLI：`gh` 已安装，已登录为 `jchensh`。
- 命令行访问 GitHub 需要走本机代理：`127.0.0.1:7897`。
- Godot AI MCP 插件：`addons/godot_ai/`，来源 `https://github.com/hi-godot/godot-ai`，当前导入版本 `2.6.1`。

## godot-ai MCP（表现层辅助工具）

项目已导入并启用 `godot-ai` 插件。它在 **Godot 编辑器 GUI 打开时**启动本地 MCP server：

```text
Codex / Claude Code
  -> http://127.0.0.1:8000/mcp
  -> Godot AI Python server
  -> WebSocket 127.0.0.1:9500
  -> Godot Editor Plugin
  -> EditorInterface / SceneTree
```

用途：表现层开发时辅助 agent 读取场景树、查看编辑器状态、运行场景/测试、读取日志、截图、定位 UI/动画/特效问题。它**不替代**现有 headless 单元测试，也**不替代**用户的肉眼/手感验收。

使用前提：

- 先打开 Godot 编辑器：`godot --path F:\godotProject -e`。
- 插件只在编辑器 GUI 模式启动 server；`--headless` 下不会启动 MCP server。
- 端口正常时：`127.0.0.1:8000`（MCP HTTP）和 `127.0.0.1:9500`（Godot WebSocket）应监听。
- Codex 用户配置：`C:\Users\user\.codex\config.toml` 里有 `[mcp_servers."godot-ai"] url = "http://127.0.0.1:8000/mcp"`。
- Claude Code 用户配置：`claude mcp list` 应显示 `godot-ai ... ✓ Connected`。
- `uv` 是 Python server 运行器；若当前 shell 找不到，先确认用户 PATH 含 `C:\Users\user\AppData\Local\Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe`。
- 遥测已用用户环境变量关闭：`GODOT_AI_DISABLE_TELEMETRY=true` / `DISABLE_TELEMETRY=true`。

使用守则：

- MCP 是**辅助工具**。逻辑正确性仍以 `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` 为准。
- 读操作（看场景树、截图、读日志、查编辑器状态）可用于表现层排查。
- 写操作（创建/删除节点、改属性、改脚本、改场景）必须遵守“一步一确认”，且不得绕过 `PLAN_V2.md` 当前步骤范围。
- 需要主观判断的视觉、动画、手感验收仍优先交给用户在编辑器里确认；agent 可提供明确测试步骤和预期结果。
- 不同时安装/启用多个 Godot MCP 工具，避免端口和工具语义冲突。

## Mac 常用命令

确认 Godot：

```bash
godot --version
```

跑全部单元测试：

```bash
godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd
```

如果 Codex/沙箱环境无法写入 `~/Library/Application Support/Godot`，用临时 HOME 跑：

```bash
HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd
```

打开 Godot 编辑器：

```bash
godot --path /Users/jeffchen/godot-develop -e
```

## Git 和 GitHub 规则

日常本地开发优先使用 `git`：

```bash
git status --short --branch
git diff
git add <files>
git commit -m "stepN: concise description"
git push origin develop
```

GitHub 远端查询、PR、issue、仓库信息优先使用 `gh`：

```bash
gh auth status
gh repo view jchensh/godot-clash-pusher
gh pr list
gh issue list
```

因为当前网络环境下 CLI 访问 GitHub 需要代理，执行远端 `git` / `gh` 命令时优先带上：

```bash
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 gh auth status
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 gh repo view jchensh/godot-clash-pusher
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 git fetch origin
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 git push origin develop
```

不要通过 GitHub Desktop 做 agent 自动化日常开发流；它只作为用户图形化检查或手动操作的备用方式。

## 测试与验收

- 新逻辑代码必须有 `tests/test_*.gd` 覆盖。
- 新测试文件继承 `res://tests/test_case.gd`。
- 测试方法名以 `test_` 开头。
- `tests/test_runner.gd` 会自动发现并执行测试。
- 提交前至少跑一次全部测试，并把结果写入 `HISTORY.md` 对应步骤记录。

## 当前开发指针

截至 2026-06-08：

- **V1 已收官**：Step 0–8 完成；原 Step 9（安卓导出）缓做，移至后续需要分发时再做。
- **V2 进行中**，权威规划见 `PLAN_V2.md`，顺序 **A → D → B → C**。
- **V2 A 模块（3-lane）已完成**：
  - V2-1：3-lane 逻辑层 + 侧路公主塔倒后转打王塔。
  - V2-2：Match / 显示层 / 出牌选 lane / 部署半场校验 / AI 固定中路接通。
- **V2 D 模块进行中**：
  - V2-3：程序化美术换皮完成（单位/塔/背景造型，逻辑零改动）。
  - **Now：V2-4 动画与特效**（攻击/受击/死亡、远程投射物、AOE 爆点、塔摧毁）。
- Godot AI MCP 已引入，作为表现层辅助工具；使用前先开 Godot 编辑器并确认 `godot-ai` MCP 已连接。

实际进度以 `HISTORY.md` 为准；如果本节过期，先更新 `HISTORY.md`，再更新本节。
