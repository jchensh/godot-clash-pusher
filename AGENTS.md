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

截至 2026-06-07：

- Step 0：完成。
- Step 1：完成。
- Step 2：完成。
- Step 3：完成。
- Step 4：完成。
- Step 5：完成。
- Step 6：完成。
- Step 7：完成（7a Player/Match 逻辑 + 7b Godot 白膜画面，单 lane MVP，对手被动）。
- Step 8：完成（AIController 简单进攻型规则 AI，经 Match.opponent_controller 注入；对手自驱出牌、一局正常分胜负）。
- **V1 收官（2026-06-07）**：Step 0–8 即 V1 全部玩法范围，已完成；**Step 9（安卓导出）缓做**，降级到后续阶段（编辑器内即可体验/开发，需要分发时再做）。
- **下一步：进入 V2**，权威规划见 `PLAN_V2.md`，顺序 A→D→B→C，**首个步骤 V2-1 = 多 lane 逻辑层（3-lane）**。开工前先与用户确认 V2-1 待细化项（公主塔被毁后行为、部署/河道规则）。

Step 8 已确认决策（详见 HISTORY 决策日志 22）：

- 规则 AI = 简单进攻型 + 中等节奏：圣水 ≥6 才出、出最贵的可用兵、伤害法术仅在对面有敌方单位时才放、兵部署自家塔前 progress 0.9、出牌间隔 1s、确定性无随机。
- AI 经对称入口 `opponent.try_play_card` 出牌；控制器注入 `Match.set_opponent_controller()`，逻辑层不依赖 AI 层。

Step 4 前置语义已确认：

- `attack_range`：lane 进度 `0~1` 的比例。
- `target_type`：单位自身的地面 / 空中类型（`ground` / `air`），不是攻击能力。
- `attack_speed`：攻击间隔（秒/次）。

Step 5 已确认决策：

- 三塔制：每方 1 王塔 + 2 公主塔（血量取自 `levels.json.tower_hp`）。
- 王塔归零 → 该方立即负；公主塔毁不结束对局，只计入剩余塔血。
- 超时（`match_duration`）→ 比双方剩余塔血总和，多者胜、相等判平。
- V1 单 lane 两端接双方王塔，单位推到底直接削王塔。

Step 6 已确认决策（原 PLAN_V1 §9 遗留项至此定稿，详见 HISTORY 决策日志 17–21）：

- 多积木卡牌按 `skills` 数组顺序自上而下逐个同步结算。
- `direct_damage.target` V1 仅 `first_enemy_in_lane` = 最逼近出牌方塔的敌方单位；无则空放；只打单位不打塔。
- `aoe_damage` 的 `radius` 按 lane 进度比例（0~1），沿 lane 一维命中；圆心由出牌指令携带。
- 技能伤害 V1 只打敌方单位；出牌指令统一为 `(card_id, owner_id, lane_index, target_progress)`；SkillSystem 不校验/扣圣水。

实际进度以 `HISTORY.md` 为准；如果本节过期，先更新 `HISTORY.md`，再更新本节。
