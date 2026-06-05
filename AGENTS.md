# AGENTS.md

本文件是给 Codex / Claude / 其他编程 agent 的项目入口守则。开始任何编码、重构、测试、提交前，先读本文件，再按下方顺序读取项目资料。

## 必读顺序

1. 先读 [PLAN.md](PLAN.md)：项目唯一权威规划，规格、步骤、验收标准以它为准。
2. 再读 [HISTORY.md](HISTORY.md)：当前进度、已完成步骤、历史决策、踩坑记录。
3. 必要时读 [CLAUDE.md](CLAUDE.md)：原 Claude Code 操作手册；其中 Windows 工具链命令仅作历史参考，Mac 命令以本文件为准。

## 开发纪律

- 严格按 `PLAN.md` 第六节开发步骤推进。
- 一步一确认：完成一个步骤后停下，等待用户确认，再进入下一步。
- 每步完成后更新 `HISTORY.md`，记录新增/修改文件、关键决策、踩坑、验收结果。
- 每步一次 git commit，commit message 描述本步内容，例如 `step3: deck cycle system + unit tests`。
- 第 0~6 步是纯逻辑层，必须配单元测试；测试通过才算完成。
- 遇到配置含义、接口语义、战斗规则不清楚时，先问用户，不要猜。
- 不自行扩大范围，不写当前步骤用不到的未来扩展代码。
- 不擅自删改与当前任务无关的代码、注释、配置或历史记录。

## 硬性禁止

- 不用 Godot 物理引擎处理 lane 碰撞；不要用 `RigidBody2D` / `Area2D` 做单位互撞。
- 逻辑层不依赖屏幕像素坐标；单位位置统一使用 `0.0~1.0` 的 lane 进度，`0=己方塔`，`1=敌方塔`。
- 游戏速度不绑定渲染帧率；圣水、时间、推进用固定逻辑 tick，显示层只做读取和插值。
- 不绕过 JSON 配置硬编码数值；卡牌、单位、关卡数值走 `config/`。

## 当前工程环境

- 项目根目录：`/Users/jeffchen/godot-develop`
- 引擎：Godot `4.6.3 stable`，标准 GDScript 构建。
- 仓库：`https://github.com/jchensh/godot-clash-pusher`
- 稳定分支：`main`
- 当前开发分支：`develop`
- GitHub CLI：`gh` 已安装，已登录为 `jchensh`。
- 命令行访问 GitHub 需要走本机代理：`127.0.0.1:7897`。

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

截至 2026-06-06：

- Step 0：完成。
- Step 1：完成。
- Step 2：完成。
- Step 3：完成。
- Step 4：完成。
- 下一步：Step 5，`Tower` + `Battle` 胜负判定。

Step 4 前置语义已确认：

- `attack_range`：lane 进度 `0~1` 的比例。
- `target_type`：单位自身的地面 / 空中类型（`ground` / `air`），不是攻击能力。
- `attack_speed`：攻击间隔（秒/次）。

实际进度以 `HISTORY.md` 为准；如果本节过期，先更新 `HISTORY.md`，再更新本节。
