# HISTORY.md — 开发历史与进度记录

> **本文件用途**：给任何接手的人/agent（新开对话也一样）一个**准确、自足**的项目进度与历史。
> 阅读顺序：[PLAN_GRAND.md](PLAN_GRAND.md)（roadmap）→ [PLAN_V3.md](PLAN_V3.md)（**当前阶段权威规划**）→ [CLAUDE.md](CLAUDE.md)（操作手册）→ 本文件（进度总览 + 决策日志 + 当前阶段逐步）。
> **完成阶段（V1/V2）的详细逐步历史已归档**到 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)，通常不必每次读。PLAN_V1/V2 同为存档。
> **维护约定**：每完成一步（或重要决策/踩坑）在此追加，随该步 commit。

---

## 快速上手（新 agent 必看）

- **本机是 macOS**（Godot 4.6.3 stable / Homebrew，`godot` 直接可用）。文档历史里出现的 `F:\godotProject`、PowerShell、`~\bin\godot.cmd` 是早期 Windows 残留，按 macOS 实际走。
- 跑全部单元测试（逻辑层验收主手段，带 `HOME` 隔离避免污染真实 home）：
  ```bash
  HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd
  ```
  退出码 0=全过；非 0=有失败（末尾打印明细）。
- 验证导入 / 生成 .uid：`HOME=/private/tmp/godot-home godot --headless --editor --path . --quit`。
- 测试框架：自写轻量 runner（零依赖）。新测试 `tests/test_*.gd`，`extends "res://tests/test_case.gd"`，方法名 `test_` 开头，自动发现执行。
- push / `brew` / `uv` 等下载走代理：`HTTPS_PROXY=http://127.0.0.1:7897`。

---

## 当前进度总览

| 步骤 | 内容 | 状态 | commit |
|---|---|---|---|
| 0 | 脚手架 + git + 工具链 | ✅ 完成 | `77909c9` |
| 1 | ConfigLoader + 三张 JSON | ✅ 完成 | `a632dcd` |
| 2 | Elixir 圣水系统 + SimClock 固定 tick | ✅ 完成 | `22b75cb` |
| 3 | Deck 循环抽牌 | ✅ 完成 | `1da44e3` |
| 4 | Unit + Lane 推进与碰撞 | ✅ 完成 | `2b5742b` |
| 5 | Tower + Battle 胜负判定 | ✅ 完成 | `b804f67` |
| 6 | SkillSystem 三积木 | ✅ 完成 | `a3cc5e5` |
| 7 | 显示层 MVP（白膜 + UI） | ✅ 完成 | 7a `b33957b` / 7b `304066b` |
| 8 | AIController 规则 AI | ✅ 完成 | `198798f` |
| 9 | 安卓导出 + 触摸 + 竖屏 | ⏸ 缓做（移至 V2 后续阶段） | — |
| V2-1 | 3-lane 逻辑层 + 侧路公主倒转打王塔 | ✅ 完成 | `adf5cfe` |
| V2-2 | 3-lane 接通（Match+显示层+选 lane+AI 中路） | ✅ 完成（GUI 实机验收通过） | `a1af321` |
| V2-3 | 程序化美术换皮（兵种造型/塔/背景） | ✅ 完成 | `190dc04` |
| V2-4 | 动画与特效（攻击/受击/死亡/投射物/AOE爆点/塔摧毁，仅 view 层） | ✅ 完成（视觉验收通过） | `55c2fb7` |
| V2-5a | 主菜单 + 结算面板（场景闭环骨架，仅显示层） | ✅ 完成（视觉验收通过） | `6891f32` |
| V2-5b | 战斗内 HUD 美化（顶部条/圣水分段/卡面/血条变色，仅显示层） | ✅ 完成（视觉验收通过） | `032dd5f` |
| V2-6 | 规则 AI 升级（攻防结合 + 按 lane 选向 + 难度分级，逻辑层 + 单测） | ✅ 完成（单测覆盖） | `e916a00` |
| V2-7a | 扩卡池（+6 卡 / +4 单位 → 14 卡 / 9 单位，纯 JSON + 单测） | ✅ 完成（单测覆盖） | `dd2cbf1` |
| V2-7b | 多关卡（4 关）+ 选关界面（取代难度界面，关卡自带难度） | ✅ 完成（单测 + headless 烟测） | `dd2cbf1` |
| V2-7c | 组卡界面（自由选 8 张，覆盖关卡默认卡组） | ✅ 完成（单测 + headless 烟测） | `dcdb97e` |
| V2-8 | 数值平衡 pass（轻量：arrows→AOE + baby_dragon 提速，纯配置） | ✅ 完成（单测 + harness 测量；难度曲线交真人验收） | `72ff9c9` |
| V3-1 | **2D 战斗核心 reboot**（取代 lane：地形/流场绕桥/仇恨/软分离+攻击/塔反击/AI/显示层，a–h） | ✅ 完成（单测；画面待真人验收） | `ed08c37`/`4f7aaa8`/`816968a` |
| V3-2 | 空军（飞兵越河 + 对空克制 `attack_targets`） | ✅ 完成（单测；画面待真人验收） | `7ad503d` |
| V3-3 | 新技能积木（亡语召唤 `golem` / 治疗术 `heal`）→ 16 卡 / 10 单位 | ✅ 完成（单测） | `73f99c1` |
| V3-4a | Roguelite 骨架：RunState + 节点地图（线性连战链）+ 连战流转（二元永久死亡） | ✅ 完成（单测 + headless 跑通一条 run） | `9a6fc55` |
| V3-4b | 战间 draft 三选一（确定性候选、改写本 run 卡组、卡组可增长） | ✅ 完成（单测） | 待提交 |
| V3-4c | relic 系统（JSON 数值修正器、effective level 不污染 base、起手圣水） | ✅ 完成（单测） | 待提交 |
| V3-4d | boss/精英节点难度修正 + 局间 meta 解锁 + 存档（user:// 往返）+ 最简 run view | ✅ 完成（单测 + headless smoke；引擎内流程交真人验收） | 待提交 |
| V3-6a | 拖拽部署（CR 式）+ 落点 ghost/合法红绿 + 半场高亮 + 落地涟漪 + 入场缩放（仅 view） | ✅ 完成（单测 172/172；**真人实机 7/7 验收通过 2026-06-16**） | `1999797` |
| V3-6b | 战斗 juice：移动插值 + 受击闪白 + 浮动伤害数字 + 命中顿帧 + 震屏 + 命中火花（仅 view） | ✅ 代码完成（单测 172/172 零回归；手感待真人验收） | `8a09953` |
| V3-6c | HUD 反馈：分段圣水条 + 满槽脉动 + 卡面自绘(费用/不可用扫光/选中) + 下一张预览 + 王冠/倒计时强调（仅 view） | ✅ 代码完成（单测 172/172 零回归；外观待真人验收） | `819a713` |
| V3-6d | 胜负演出（调暗/标题 sting/王冠落入/比分滚动/按钮淡入）+ run 奖励·结算揭示动画（仅 view） | 🚧 代码完成（headless smoke + 单测 172/172 零回归；演出待真人验收） | 待提交 |
| V3-7 准备 | 美术素材入库（`assets/` 选用 94 + `testAssets/` 库）+ ART_ASSETS 美术圣经雏形（题材=黑暗中世纪幻想） | ✅ 完成 | `6579207` |
| V3-7 ① | 卡牌黑暗中世纪化改名（`cards.json` name 中英定稿，id 不变） | ✅ 完成（单测 172/172；config check ok） | 待提交 |
| V3-7 ② | 多语言 i18n（中英表 + autoload + 像素中文字体 + 6 场景接入 + 设置内切换/存盘） | ✅ 代码完成（6 场景 smoke + 单测 172/172；中文显示真人认可） | `0cb32f2` |
| V3-7 ③ | 美术垂直切片（骑士精灵 / building 塔贴图 / 火爆炸序列 FX + 像素 nearest filter；架构 A：immediate `_draw`+`draw_texture`，仅 view） | ✅ 完成（**真人 6/6 验收通过 2026-06-20**；单测 172/172） | 待提交 |

> **当前阶段 = V3**（战斗核心 2D 重构 + 买断制单机：短战役 + Roguelite + 2D 卡通精灵）。权威规划见 [PLAN_V3.md](PLAN_V3.md)；方向/取舍见决策日志 36/37。**V3-1（2D reboot）+ V3-2（空军）+ V3-3（新积木）+ V3-4 全 a/b/c/d（Roguelite 主轴：骨架+draft+relic+boss/meta/存档+最简 view）已完成**；**V3-1h/V3-2/V3-3 的战斗画面/手感 + V3-4 的 run 引擎内流程留真人实机验收**。**V3-6（交互与游戏手感）进行中**：V3-6a（拖拽部署 + 落点反馈）**真人 7/7 验收通过**；V3-6b（战斗 juice，仅 view）代码完成、手感待真人验收；V3-6c（圣水/HUD 反馈，仅 view）代码完成、外观待真人验收；V3-6d（胜负演出 + run 奖励/结算揭示动画，仅 view）代码完成、演出待真人验收 → **V3-6（交互与游戏手感）四个 gate 全部代码完成**。**V3-7（精灵美术）进行中**：素材准备 + ① 卡牌改名 + ② 多语言（i18n + 像素中文字体 + 设置内中英切换）已完成（中文显示真人认可）；③ 美术垂直切片（骑士精灵 + building 塔贴图 + 火爆炸序列 FX，架构 A）**真人 6/6 验收通过**，精灵管线打通；下一步 **V3-7b 量产**（按管线全量换精灵：单位→塔→卡面→地形→UI）。V3-5 短战役 + 新手引导按决策 40 推迟到 V3-7 之后执行。V1（机制白膜）与 V2（3-lane+换皮+AI+内容）全部完成，详细逐步见 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)。

**测试**：172/172（macOS，`HOME` 隔离）。**分支/远端**：开发在 `develop`、`main` 稳定线、`origin`=github.com/jchensh/godot-clash-pusher ；用户说「提交」才 commit + push（走代理）。**配置工作流**：改 `config/*.json` → `uv run --with openpyxl python tools/build_config.py --from-json` 同步 `GameConfig.xlsx` → `--check`。**godot-ai MCP**：表现层辅助（仅编辑器开着时可用），默认不主动用——细节见 [CLAUDE.md](CLAUDE.md) / [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

---

## 关键决策记录（Decision Log）

1. **语言 = GDScript**：装的是 Godot 标准构建（非 .NET/Mono），且 PLAN 未提 C#。
2. **逻辑 tick = 10Hz（`SimClock.TICK_DELTA = 0.1s`）**：取 PLAN §8 示例值。配置里的速率（如 `elixir_regen_rate`）一律按**每秒**解释，tick 频率改变不影响数值含义，故此值低风险、可后改。**（用户 2026-05-30 确认保持。）**
3. **逻辑层数值用「每秒」单位 + dt 累加**：而非"每 tick 固定量"，保证 tick 频率与数值解耦。
4. **ConfigLoader 输出字典**而非 typed 数据类：遵守"不过度设计"，消费方（Step 4/6）真正需要时再加包装。
5. **测试用自写 headless runner**：零外部依赖（用户选择）。
6. **配置数据存为字典 + 交叉引用校验**：主动校验 deck→card、spawn_unit→unit 的引用完整性，提早抓 id 笔误。
7. **起始圣水 = 0（空槽开局）**：PLAN/配置未定义起手圣水；先按 0 做，将来如需半槽起手再加 `levels.json.elixir_start` 字段（用户 2026-05-30 确认）。
8. **`attack_range` = lane 进度比例**：用户 2026-06-06 确认，范围数值按 `0.0~1.0` 的 lane 进度解释。
9. **`target_type` = 单位自身类型**：2026-06-06 决策，`ground` / `air` 表示单位属于地面/空中，用于命中筛选；攻击能力后续若需要用独立配置字段表达。
10. **`attack_speed` = 攻击间隔（秒/次）**：Step 4 决策，单位初次接敌可立即攻击，攻击后按 `attack_speed` 秒进入冷却。
11. **Lane 目标选择 = 范围内最近敌人**：Step 4 决策，单位只打同 lane 中距离最近且在自身 `attack_range` 内的敌方单位；未接敌时沿 owner 方向推进，接近前方敌人时停在自身攻击范围边界。
12. **三塔制（1 王 + 2 公主）/方**：Step 5 决策（用户 2026-06-07 确认）。塔血取自 `levels.json.tower_hp`（king/princess）。`Tower` 只是血量容器（kind/owner/hp），位置由 Lane/Battle 接线。
13. **王塔归零 = 该方立即负**：Step 5 决策（用户 2026-06-07 确认）。公主塔被摧毁**不**结束对局，只减少该方剩余塔血。三塔才有层次。
14. **超时（match_duration）按剩余塔血总和判胜负**：Step 5 决策。时间到 → 双方在场塔血求和，多者胜、相等判平。
15. **V1 单 lane 两端接双方王塔**：Step 5 决策（用户 2026-06-07 确认）。单位推到尽头直接削敌王塔，使 1-lane 阶段也能按王塔归零正常结束；两座公主塔仍实体化、满血计入超时比拼，扩到 3 lane 时再接公主/中路。
16. **Lane↔Tower 接线方式 = Lane 持两端可空塔引用**：Step 5 决策。`Lane.set_towers(start,end)`；不接塔时为 null，行为与 Step 4 完全一致（旧测试不受影响）。单位攻击优先级：范围内敌方单位 > 尽头敌塔。

> 以下 17–21 为 **Step 6（SkillSystem）开工前提**，用户 2026-06-07 确认。原 PLAN §9 遗留的「多积木结算顺序」「direct_damage 的 target 枚举」在此定稿，并补全 `aoe_damage` 圆心/半径与出牌指令口径。

17. **多积木卡牌结算顺序 = 数组顺序、自上而下、逐个同步结算**：`skills` 数组里多个积木严格按下标先后执行，前一个执行完再下一个；策划用数组次序控制先后，不引入优先级字段。当前 8 张卡均为单积木，本规则面向未来叠积木的卡。
18. **`direct_damage.target` V1 仅实现 `first_enemy_in_lane`**：语义 = 出牌方指定 lane 中**最逼近出牌方自己塔**的敌方单位（玩家塔在 progress 0 → 取 progress 最小的敌方单位；对手塔在 1 → 取最大）。该 lane 无敌方单位则**空放**（无效果）。V1 的 direct_damage 只打单位、不打塔。其余 target 取值（如 nearest_enemy / enemy_tower）后续用 `match` 分支扩展，不改架构。
19. **`aoe_damage` 圆心/半径口径**：`radius` 按 lane 进度比例解释（`0~1`，与 attack_range 同尺度）；V1 为**沿 lane 的一维范围**——命中目标 lane 中 `|progress - center| <= radius` 的敌方单位。圆心 `center` 由出牌指令携带（玩家点哪 / AI 指定）。`config/cards.json` 里 `fireball.radius=1.5` 为可调占位（V1 覆盖整条 lane）。跨 lane 溅射留到多 lane 阶段（需二维坐标）再做。
20. **技能伤害 V1 只打敌方单位**：`aoe_damage` / `direct_damage` 仅作用于出牌方的敌方单位，不误伤己方、不打塔（简化；CR 式友伤后续如需再开）。
21. **出牌指令统一为 `(card_id, owner_id, lane_index, target_progress)`**：`spawn_unit` 在 `(lane_index, target_progress)` 处生成 `count` 个该单位（owner = 出牌方）；`aoe_damage` 用 `target_progress` 作圆心；`direct_damage` 只用 `lane_index`。部署区限制属 Step 7 输入层，逻辑层信任传入位置。**SkillSystem 不校验/扣圣水**（圣水门槛是上层 Player/显示层职责），只负责执行技能效果——对齐 §6 验收「出一张卡能正确触发 生成/直伤/AOE」。

> 22 为 **Step 8（AIController）出牌规则**，用户 2026-06-07 确认（原 PLAN §9「规则 AI 出牌优先级表」在此定稿）。

22. **规则 AI = 简单进攻型 + 中等节奏**：①圣水 `get_int() >= 6` 才考虑出牌；②出「出得起且有用」的**最贵**牌——兵随时有用、伤害法术仅在对面 lane 有敌方单位时才算有用（否则跳过，不空放）；③兵部署在自家塔前 `progress 0.9` 往 0 推，法术落在「最逼近 AI 塔的敌方单位」处；④两次出牌最小间隔 `1.0s`（防一次性倾泻）；⑤**确定性、无随机**（利于测试与复现）。V1 单一难度，`levels.json.ai_difficulty` 暂为占位。AI 一律经对称入口 `opponent.try_play_card` 发指令（与玩家同路径）。

> 23 为 **V1 收官 + V2 范围 + 文档重构**，用户 2026-06-07 确认。

23. **V1 在 Step 8 收官；Step 9（安卓打包）缓做**：当前阶段编辑器内即可体验/继续开发，打包对玩法迭代无帮助，降级到后续阶段（需要分发到手机时再做）。**V2 范围与顺序 = A→D→B→C**：A 玩法深度（核心 = 3-lane，必做）→ D 表现/换皮 → B AI 深度 → C 内容/数值；**V2 不做空中/地面克制**（留后续）。**文档重构**：原 `PLAN.md` → `PLAN_V1.md`（V1 历史规格存档）；新增 `PLAN_V2.md`（V2 分步施工图）与 `PLAN_GRAND.md`（全项目 roadmap，粗粒度）。CLAUDE/AGENTS/HISTORY 的「必读/规格」指针改指 PLAN_GRAND + PLAN_V2。

> 24–25 为 **V2-1（3-lane 逻辑层）开工前提**，用户 2026-06-08 确认（PLAN_V2 §4 两个待细化项至此定稿）。

24. **侧路公主塔被摧毁后，该 lane 单位转打王塔**（皇室战争式「拆侧塔开路、威胁王塔」）：侧路（lane 0/2）主塔为公主塔；公主塔归零后，该 lane 内推到尽头的单位改为攻击该端**王塔**。实现 = `Lane` 持兜底引用 `king_at_start/king_at_end`，`_enemy_tower_for` 改为「主塔活着打主塔，主塔毁则打兜底王塔」。中路（lane 1）主塔本就是王塔，无需兜底。三条 lane 的兜底王塔指向**同一座**王塔对象，故中路 + 已破侧路对王塔的伤害天然累加。
25. **部署规则 = 仅己方半场（progress 0~0.5）、任意 lane 可选**：玩家出兵落点限己方半场，但可自由选 3 条 lane 中任意一条。⚠️ **本规则的强制校验留到 V2-2**（与出牌选 lane 的输入层一并做）；V2-1 仅完成 3-lane 拓扑与转火逻辑，逻辑层暂仍信任传入的 `(lane_index, target_progress)`（沿用决策 21）。

> 26–28 为 **V2-2（3-lane 接通 + 显示层 + 出牌选 lane）开工前提**，用户 2026-06-08 确认。

26. **越界部署 = 拒绝出牌**：含 `spawn_unit` 的兵牌，落点 `target_progress` 必须在出牌方己方半场（玩家 `[0,0.5]`、对手 `[0.5,1.0]`），越界 → `try_play_card` 返回 false、不扣圣水、不抽牌（皇室战争式）。**纯伤害法术**（无 spawn 积木，如 fireball/arrows/zap）**不受半场限制**，可打敌方半场。校验落在对称入口 `Player.try_play_card`（玩家/AI 同受约束）。
27. **AI V2-2 最小适配 = 固定中路（lane 1）**：AI 出兵与感知敌情都只在中路，确保 3-lane 下出牌不报错、保持确定性。完整的「按 lane 选攻防方向 + 难度分级」是 V2-6（B）的事，此处不做。
28. **出牌交互 = 先选卡再点落点（tap-to-place）**：点手牌选中 → 点己方半场某 lane 落点部署；落点的 lane 由点击 x 最近列决定、progress 由点击 y 决定并钳在己方半场。拖拽（drag-drop）留后续表现优化（V2-5/后续）。

> 29 为 **表现层阶段引入 Godot AI MCP**，用户 2026-06-08 确认安装并纳入 git。

29. **Godot AI MCP = 表现层辅助工具，不替代测试/真人验收**：选用 `hi-godot/godot-ai`（https://github.com/hi-godot/godot-ai，MIT，导入版本 `2.6.1`；**2026-06-16 编辑器内自升级到 `2.7.5`**，作为单独 chore 提交入库）。它通过 Godot 编辑器插件启动本地 MCP server（HTTP `127.0.0.1:8000/mcp`、WebSocket `127.0.0.1:9500`），供 Codex / Claude Code 读取场景树、截图、日志、编辑器状态并辅助 UI/动画/特效排查。逻辑正确性仍以 headless test runner 为准；写操作仍遵守一步一确认；主观视觉/手感验收仍交用户确认。

> 30 为 **V2-4（动画与特效）事件源选型**，用户 2026-06-09 确认。

30. **V2-4 动画事件源 = 路线 A（纯显示层、零改逻辑）**：受击/死亡/塔摧毁靠显示层逐帧 diff 血量还原；攻击配对/投射物来源靠显示层复刻 `Lane` 的目标选择（范围内最近敌方单位 + 尽头敌塔）还原；玩家法术按点击点/直伤目标精确出特效，AI 法术（显示层看不到其经 `opponent_controller.tick` 的出牌）按「同帧某 lane ≥2 个玩家单位聚集掉血」推断爆点（近似，带节流 + 聚集窗）。代价：攻击/投射物配对为启发式、AI 法术落点为近似；收益：逻辑层一行不改、不扩大范围、无新单测、契合架构铁律「显示层每帧读逻辑状态画出来」。备选路线 B（逻辑层每 tick 发可测事件缓冲，显示层 drain 精确驱动）记录在案，若将来精确度不足再升级。

> 31 为 **配置体系迁移到 Excel 源表**，用户 2026-06-09 确认。

31. **配置工作流 = JSON / Excel 双入口，agent 默认 JSON 优先**：Godot 运行时仍读 `config/cards.json`、`config/units.json`、`config/levels.json`，避免引入 Excel 运行时解析依赖、也不改战斗逻辑。Codex / Claude 修改配置时优先直接改 JSON（更省上下文、路径更短、贴近运行时），确认没问题后运行 `tools/build_config.py --from-json` 把当前 JSON 覆写同步到 `config/GameConfig.xlsx`。人类策划仍可直接改 Excel，再运行 `tools/build_config.py` 生成 JSON。提交前统一跑 `tools/build_config.py --check` 与 Godot 单测。若 Excel 可能有用户尚未同步到 JSON 的手工改动，agent 不得直接 `--from-json` 覆盖，必须先询问。

> 32 为 **V2-5（D 模块收尾）开工前提**，用户 2026-06-10 确认。

32. **V2-5 拆 3 小步 + 音频缓做 + UI 保持全英文**：V2-5 原打包「UI 美化 + 音频 + 主菜单 + 结算闭环」，按「一步一确认」拆为 **V2-5a 场景闭环骨架（主菜单 + 结算面板 + 菜单→对局→结算→菜单）→ V2-5b 战斗内 UI 美化 → V2-5c 音频**，每小步停下做真人视觉验收。**音频本阶段缓做**（既不引入外部 CC0 音效素材、也不先做程序化合成），留到 a/b 之后单独处理；**UI 保持全英文**（延续 7b 决定，不导入 CJK 字体、零字体依赖）。理由同 V2-3/V2-4 零外部素材路线：先把场景闭环与可玩骨架立起来再逐步美化，避免一步铺太大、便于分段验收。

> 33 为 **V2-6（规则 AI 升级）开工前提**，用户 2026-06-10 确认（PLAN_V2 §4「难度分级差异维度」至此定稿）。

33. **规则 AI = 攻防结合 + 按 lane 选向 + 难度 3 档（easy/normal/hard）4 维度**：难度从 `levels.json.ai_difficulty` 解析（`Match.setup` 存 `ai_difficulty`、`AIController` 读取，构造参数可覆盖便于单测；难度选择界面经 `GameState` 静态变量传入覆盖关卡值）。差异维度：①圣水阈值（easy 8 / normal 6 / hard 4）②出牌间隔（2.0 / 1.2 / 0.6 s）③是否防守（easy 否，normal/hard 是）④进攻选路（easy 固定中路，normal/hard 集火「守军塔血最低」的 lane）。**防守口径**：玩家单位 `progress ≥ 0.55`（越中线逼近 AI 塔）该 lane 受威胁，优先在塔前 `0.9` 空投最贵可用兵 body-block，防守优先于进攻。**进攻口径**：选目标 lane 出最贵可用兵；最贵可用为法术且场上有敌方单位时落在最前敌人处（不空放）。确定性无随机（延续决策 22）、tie-break 取小 index、仍走 `opponent.try_play_card`（玩家/AI 对称）。

> 34 为 **V2-7（C 模块：内容/数值）开工前提**，用户 2026-06-10 确认（PLAN_V2 §4「V2-7 细化」至此定稿）。

34. **V2-7 拆 3 小步 + 卡池适中 + 关卡=独立遭遇战 + 自由组卡 + 会话内持久化**：按「一步一确认」拆 **7a 扩卡池（纯 JSON + 单测）→ 7b 多关卡 + 选关界面 → 7c 组卡界面**。①**卡池适中**：+6 卡 / +4 单位 → 14 卡 / 9 单位，覆盖坦克/群攻/快攻/空军/远程/法术原型，仍只用 `spawn_unit`/`direct_damage`/`aoe_damage` 三积木、**不做空中/地面克制**（V2 范围外），新内容 = 新数值组合 + 法术调参（统一平衡留 V2-8）。②**关卡 = 独立遭遇战，自带难度**：每关携带 AI 卡组 + 塔血 + `ai_difficulty` + 圣水节奏；做「选关」界面，**取代现有难度选择界面**（难度内嵌进每关）。③**组卡 = 自由选任意 8 张唯一卡，不限费用**（原型阶段最简）。④**所选关卡/卡组经 `GameState` 静态变量跨场景传递**（与 `ai_difficulty` 一致、会话内有效、重启重置、不落盘）。最终流程：菜单 → 选关 → 组卡 → 对局 → 结算。

> 35 为 **V2-8（数值平衡 pass）方法与落地**，用户 2026-06-10 确认（PLAN_V2 §3 C「V2-8 数值平衡」至此落地）。

35. **V2-8 = 轻量数值平衡；数据驱动测量、proxy 不可调难度、难度曲线交真人**：用户定**轻量改动**（只治明显废牌/超模牌，不重构费用曲线），优先保**对局节奏 + 关卡难度曲线**。测量用临时 headless harness（`tools/_balance_probe.gd`，AIController 驱动 AI 侧 + 几何镜像控制器驱动玩家侧、同一套 DIFF；多变体扰动出牌相位+卡序取胜率；**验后即删、不入 git**）。三结论：①**对局节奏健康**——带扰动多变体 75–100% 靠拆王塔决胜、时长 40–120s，唯一 0-0 平局仅出现在「完全对称」人造对照组；②**难度曲线无法用 AI-vs-AI proxy 测量**——难度档在 proxy 下倒挂（镜像玩家钻 hard AI「低阈值+反应式防守」浪费圣水的空子；而 easy AI「攒满砸大兵」朴实难缠），**proxy ≠ 真人**（真人打 easy 关慢/单路/不防守会觉得简单，打 hard 关反应快/会防守/多路会觉得难）→ 难度曲线**交真人实机验收**（清单见 V2-8 逐步历史），本步不靠 proxy 调；③**单卡 raw 强度**印证 skeletons/goblins/mini_pekka/giant 为破防引擎（**不削**，否则增平局）、baby_dragon 为明显废兵。据此**仅改两张卡（纯配置）**：**arrows** `direct_damage 150@3`（被 lightning/fireball 双压、无生态位）→ `aoe_damage radius0.5/140@3`（补「中号群清」：log 小→arrows 中→fireball 全场；**意外收益**：经典卡组里 AOE 箭雨清掉防守群兵，对称对局 0-0 僵局消失、全部拆王塔决胜，直接改善节奏）；**baby_dragon_body** 攻速 `1.6→1.3`（DPS 50→62，让 4 费空中远程兵在混合卡组站得住）。swarm/mini_pekka/zap 及各关卡配置（塔血/回速/时长/难度档/AI 卡组）**本轮不动**——各关数值的调整待真人难度反馈后另起一轮。view 层零改动（`battle_scene._play_spell_fx` 按技能类型派发，arrows 改 AOE 自动走爆点 FX）。

> 36 为 **V3（战斗核心 2D 重构 + 买断制单机）方向锁定**，用户 2026-06-10 确认。

36. **V3 = 战斗核心 2D reboot + 混合主轴 + 2D 卡通精灵**：用户判断「3-lane + 无自由地形」的简化丢失了皇室战争「兵自由走位的轻 RTS」核心乐趣，要求向 CR 看齐重构。锁定四大取舍：①**战斗模型 2D 化（取代 lane）**——河 + 左右双桥、每方 2 公主 1 王、**己方半场任意落点**、地面兵流场绕桥、空军越河（**首版先全地面**、空军 V3-2）；②**仇恨 = 完整 CR 式**（默认锁最近敌塔、敌方单位进 `aggro_radius` 转火，可拉扯/风筝）；③**出兵领土 = 固定己方半场**（不做破塔扩张领土，留后续）；④**碰撞 = 软推挤**（体积半径 + 确定性分离，**不用物理引擎**、可单测）。**单机主轴 = 混合**（5–6 关脚本短战役兼新手教学 → Roguelite 终盘：3 act / draft 三选一 / relic=JSON 数值修正器 / 永久死亡 / 局间 meta 解锁，复用 `Match`/`Battle`/`AIController`/JSON 管线）。**美术 = 2D 卡通精灵**（静态精灵 + 现有 tween 鞭 动画、素材包打底）。施工图 + 程序重构设计见 [PLAN_V3.md](PLAN_V3.md)。**改 CLAUDE.md 硬性 DO-NOT**：1D lane 进度 → 抽象 2D 场地坐标（tile 空间）；「不用物理引擎」保留（自写确定性软分离）。**重构策略 = 绞杀式（strangler）**：新 `arena.gd` 与旧 `lane.gd` 并存、逐子步迁移、**单测全程绿**，待 V3-1h 全通后再删 lane.gd 及 lane 单测。（⚠️ 此条 V3-1b 起被决策 37 覆盖为「推倒重来」。）

> 37 为 **V3-1b 重构策略改「推倒重来」+ AI 搁置**，用户 2026-06-10 确认（覆盖决策 36 的绞杀式）。

37. **V3-1b = 推倒重来（rip-out），非绞杀式**：摸查发现 `move_speed`/`attack_range` 量纲在 lane(0~1) 与 2D(tile) 冲突、且共用同一 Unit 字段——保并存需在 units 上挂双份字段（用户否决）。故改**推倒重来**：直接改 tile 量纲、**删 `lane.gd`**。因仅 `battle.gd` preload lane（`view/*`、`ai_controller` 是运行时动态调用、解析不受影响），删 lane 的连带原子 = Unit 2D + arena 移动 + battle 去 lane + **`skill_system` 2D（原 V3-1f 被迫提前并入 V3-1b）** + config/units/cards 量纲 + match/player 2D + 删改相关单测。**AI 暂搁置**（`ai_controller.gd` 留死代码、删 `test_ai_controller`，V3-1g 2D 重写时加回）；**view 暂坏**（解析通过、不运行，V3-1h 接通）。代价：V3-1b~g 期间无可玩画面、只有 headless 单测（用户已接受）。

> 38 为 **V3-4a（Roguelite 骨架）参数与流转口径**，用户 2026-06-15 确认（PLAN_V3 §5「Roguelite 参数：act/战数/map 形态，V3-4 前定」至此为 4a 定稿）。

38. **V3-4a = 线性连战链 + 二元永久死亡 + 3 act × 3 战**：①**节点地图形态 = 线性连战链**（节点按 act 展开成一条扁平链、依次连战、无分叉；节点带 `type(battle/elite/boss)` 与 `act` 标签供 V3-4d 差异化与 view 分组，4a 所有节点同跑普通战斗；分叉/程序化地图留后续，同一 `RunMap` 接口承载、流转不必改）。②**败北模型 = 二元永久死亡**——只有【玩家胜】推进，**对手胜或平局**立即整局失败（draw 视为「未取胜」→ 必须明确取胜才过关；该口径用户已知，可后续否决）；战斗未结束(ONGOING)喂入为防御性 no-op。③**run 规模 = 3 act × 3 战 = 9 节点**（act 数沿用决策 36 锁定的 3；每 act 末节点标记为 boss；战数全走 `run.json` 可调）。④**遭遇来源 = run 节点引用现有 `levels.json` 的 level_id**（复用 `Match.setup(level_id, player_deck_override)` 现成逻辑：用该关 AI 侧/塔/时长，玩家卡组用 run 卡组覆盖；零额外接口；当前仅 4 关先复用，富遭遇池留内容步）。⑤**起始 run 卡组 = 玩家在 deck_builder 选的卡组**，空则用 `run.json` 的 `starter_deck`（与 V2-7c 的 `player_deck_override` 同口径）。⑥**确定性**：`RunState` 带 `seed` 字段但 4a 地图按 config 确定性展开、不实际跑随机（保单测可复现，seed 留后续程序化）；`relics` 字段空置留 V3-4c。⑦**`run.json` 为结构性配置、不进 Excel 镜像**（比照 `arena.json`，`build_config.py`/`--check` 不涉及）。⑧**view 接入（菜单→run→对局→下一节点）不在 4a**——4a 仅 logic+config+单测（对齐 PLAN_V3 §3 「4a 验收 = 单测 + headless 跑通一条 run」），最简 view 留后续小步。

> 39 为 **V3-4b/c/d 一批做完 + 配最简可玩 view**，用户 2026-06-15 确认（要求一口气开发完并在 V3-4 全完成后给「人工引擎内验收清单」）。

39. **V3-4b/c/d 一批做完 + 配最简可玩 view**：本批含让 run 引擎内可玩的最简 view（否则无可人工验收的东西）。各子步口径——**4b draft**：每场胜后三选一，候选 = 卡池中**不在 run 卡组**的卡、**确定性 seeded 洗牌**取 3（`RunRewards`，同 seed 同结果）；选中 → **追加**进 run 卡组（卡组可增长、不替换、去重），故 **`Deck` 放宽**为 ≥HAND_SIZE+1（不再硬限 8）；可 SKIP。**平局/对手胜不给 draft**（沿用决策 38 永久死亡）。**4c relic**：relic = JSON 数值修正器（`relics.json`，结构性、不进 Excel），经 `RunModifiers.effective_level` 作用于 level 的**深拷贝 effective 副本**（圣水回速/上限/**起手圣水**、对局时长、王/公主塔血），**绝不污染 ConfigLoader 基础配置**；多源**顺序叠加** `val=val*mult+add`；relic 奖励在 **elite/boss 胜**后给（普通节点给卡 draft）；**单位级 relic（兵伤/血）留后续**（需注入 SkillSystem 生成路径，本批不做）。`Match.setup` +`modifiers` 形参（空=行为同前、起手圣水仍 0），起手圣水经 `Elixir` 第三参注入。**4d boss/精英 + meta + 存档**：boss/elite 节点经 `run.json.node_modifiers` 用同一修正器引擎**抬塔血**（elite ×1.25 / boss 王×1.5·公主×1.4）实现差异化（AI 难度仍随所引用关卡，不另调）；**meta = 局间持久统计**（runs_started/won、bosses_defeated）驱动**解锁**——relic 上挂 `unlock:{stat:阈值}` 门控，满足才进可用池（`MetaProgress.available_relics`）；**存档落 `user://`**（`SaveSystem`：meta 持久 + run 可续跑，run 地图不存盘由 config 重建后 `load_dict` 恢复进度）。**view = 最简**：`run_scene` 节点链中枢（打节点→回来推进→给奖励→结算）+ `battle_scene` run 模式（读 `GameState.run` 建场、CONTINUE 回中枢）+ 主菜单 ROGUELITE 入口；run 真正可玩，但**引擎内流程/手感交真人验收**。**踩坑**：①新类的 `static from_dict` 引用自身 `class_name` 在 .uid/全局注册前会被 test runner 预检判失败 → 改为**实例方法 `load_dict`、不引用自身 class_name**（合 HISTORY「不依赖 class_name 全局注册」）；②`--script` 的 `_initialize` 期 `add_child` **不触发 `_ready`** → headless smoke 须显式调 `_ready()`（非代码 bug）；③杀进程留下的 `user://` 半档会污染下次 smoke → smoke 前清档。

> 40 为 **V3 后半段施工顺序调整**，用户 2026-06-16 确认。

40. **V3-5（短战役 + 新手引导）推迟到 V3-6（手感）+ V3-7（美术）之后**：原 PLAN_V3 §3 顺序为 5→6→7。用户判断脚本化战役与新手引导应建立在**已成形的交互手感 + 精灵美术**之上——否则对着白膜画面 + 粗糙控制写教学覆盖层与关卡脚本，等手感/美术落地后必返工。**步骤 ID 不重编号**（V3-5/6/7 标签不变，避免跨文档引用错位），仅改执行先后：**执行顺序 = V3-6 → V3-7 → V3-5 → V3-8 → V3-9**。PLAN_V3 §3 表格已按新序重排并加注；下一步由 V3-5 改为 **V3-6（交互与游戏手感）**。

> 41 为 **V3-6（交互与游戏手感）范围与拆步**，用户 2026-06-16 确认。参考业界 UI/UX 范例：皇室战争（拖拽部署/卡片抬起/落点提示/分段圣水/胜利演出）、Vlambeer《The Art of Screenshake》+《Juice it or Lose it》（顿帧/震屏/缓动）、Brawl Stars（受击数字）、Slay the Spire（奖励/relic 揭示）、Apple HIG（≥44pt 触控/拇指区）。

41. **V3-6 = 纯显示层（零逻辑改，沿用决策 30 路线 A）+ 拆 4 个真人验收 gate**：所有手感经显示层逐帧 diff 逻辑状态实现（hp 降→受击数字、新兵→入场、塔 hp→0→爆破），**不动逻辑、无新单测、全交真人验收**。**部署交互 = 拖拽（CR 式）**（用户选定，取代原两段式 tap）：按手牌→拖到场上(落点抬到手指上方避免遮挡)→松手落子；拖拽中画落点 ghost + 合法绿/非法红 + 己方半场高亮。**拆步（执行序 6a→6b→6c→6d，每步一 gate）**：**6a** 部署交互 + 落点 ghost/红绿 + 半场高亮 + 落地涟漪 + 入场缩放；**6b** 战斗 juice（10Hz→60fps 移动插值、受击闪白 + 浮动伤害数字、命中顿帧、震屏、攻击命中 stub FX）；**6c** 圣水/HUD 反馈（分段圣水条 + 满槽脉动、卡牌冷却扫光 + 下一张预览、可用/不可用态、王冠/倒计时强调）；**6d** 胜负与 run 总结演出（王冠落入、胜负 sting、塔爆破序列、结算面板动画；roguelite 奖励/relic 揭示）。**白膜上做**：6a–6d 装的是「手感系统」（插值/伤害数字生成器/震屏/ghost），V3-7 再贴精灵/粒子皮，**近零返工**。

> 42 为 **V3-7 题材 + 美术主风格 + 素材方案**，用户 2026-06-16 确认。

42. **题材 = 黑暗中世纪幻想；主美术 = itch Pixel Grit 精细像素**：骑士/法师/亡灵/兽人/吸血鬼，无机甲/火器（→ 非中世纪卡改名换概念，见 ①）。`testAssets/` 原始库（Pixel Grit 角色/特效/boss bundle + Lonesome/Grand Forests/World Map 三套 **No-Attribution** 地形 + .aseprite 源）；`assets/` 选用集 94 文件（units/towers/terrain/map/fx/bosses）。地形三套分工：Lonesome **Summer** 全色版=战场地面/河/桥、Grand Forests=树木、World Map=run 节点地图（弃 pixelCrawler top-down + PICO-8）。映射/缺口（golem/真龙/真巨人缺→换皮）/许可见 [docs/ART_ASSETS.md](docs/ART_ASSETS.md)。⚠️ Pixel Grit 付费 bundle 授权用户已确认（license 文件待补拷）；仓库公开、用户确认全量入库。

> 43 为 **② 多语言（i18n）方案 + ① 卡牌改名**，用户 2026-06-16 确认（顺序 ①→②→③ 切片）。

43. **i18n = JSON 翻译表 + autoload 运行时构建 Translation（headless 友好）+ 像素中文字体 + 设置内中英切换**：弃 CSV 编辑器导入，用 `config/i18n.json`(en/zh ~80 key) 经 `I18n` autoload 建 `Translation` 注入 `TranslationServer`；locale 存 `user://settings.cfg`、**默认中文**。字体 = Fusion Pixel 12px proportional zh_hans（OFL，Godot 自动禁 subpixel），`project.godot` [gui] 默认主题字体（中英共用）。6 场景全 `tr()`（卡名/relic/难度/数值模板/HUD/结算/奖励）；新增设置页（主菜单入口）切换即时(reload 本页)+存盘。**① 卡牌改名**：13 张改 `cards.json` name（食人魔/狂战士/女巫/怨灵/余烬火颅/亡灵巨像/滚石 + 火球术/箭雨/电火花/闪电术/骷髅兵/治愈术），id 不变、英文名入 i18n。**view 层零逻辑改、无新单测**（表现层）。

---

## V3 — 战斗核心 2D 重构 + 买断制单机（进行中）

> 方向见决策日志 36，权威规划见 [PLAN_V3.md](PLAN_V3.md)。头号工程 **V3-1 = 2D 战斗 reboot**（取代 lane），拆 8 小步（a 场地地形 / b 移动寻路 / c 仇恨 / d 软分离+攻击 / e 塔反击 / f 技能 2D[已并入 b] / g AI 2D / h 显示层 2D）。**策略=推倒重来（决策 37，弃绞杀）**：V3-1b 即删 lane（量纲 1D→2D），AI/view 暂搁置到 V3-1g/h；其余子步仍逐步推进、单测护栏。坐标改抽象 2D tile 空间（CLAUDE.md 硬性 DO-NOT 已相应修订）。

### V3-1a — 场地与地形（新 Arena + Battle.build_arena + 落点合法性，逻辑+单测）  （本次提交）
**前置决策**：见决策日志 36（2D 场地、河+双桥、每方 2 公主 1 王、固定己方半场落点）。本步只做**地形 + 塔占位 + 落点合法性（纯查询）**；单位移动/寻路/tick 见 V3-1b+。

**新增 / 修改**
- `config/arena.json`（新）：场地几何 `default`——网格 `18×32`、河 `y[15,17)`、左右双桥 `x{3,4}&{13,14}`、落点边界（玩家 `y>=17` / 对手 `y<=15`）、双方 6 塔位与占位（王 4×4、公主 3×3；公主 x=4.5/13.5 关于中线 x=9 对称、与桥对齐）。**结构性配置，不进 Excel 镜像**。
- `logic/arena.gd`（新）：2D 场地。tile 类型 `GROUND/WATER/TOWER/OOB`、`tile_type(_at)`、`is_ground_walkable(_at)`、`add_tower_footprint`、`can_deploy(owner,pos)`（地面 + 己方半场）。纯查询、确定性、不用物理引擎。
- `logic/battle.gd`：+`ArenaScript` preload、+`arena` 字段、+`build_arena(level, arena_cfg)`（建 2D 地形 + 6 塔、注册占位，胜负规则沿用）、+`_build_side_towers`。**保留 `build_v2_three_lanes`（与 arena 并存，游戏当前仍跑 lane）**。
- `logic/tower.gd`：+`pos:Vector2`/`fw`/`fh`（加性，lane 阶段不用）。
- `logic/config_loader.gd`：load_all 纳入 `arena.json`、轻校验（default 含 grid/river/deploy/towers）、+`get_arena(id)`。
- `tests/test_arena.gd`（新，10 测）：网格尺寸、河水阻挡、双桥可走、空地可走、越界、塔占位阻挡、6 塔构建、玩家/对手落点半场校验、塔占位拒绝部署。
- `tests/test_config_loader.gd`：+1 测 `test_v3_arena_config_loaded`（arena.json 已加载、default 含必需字段）。

**范围边界**：纯逻辑层 + 配置 + 单测；`view/*`、`ai/*`、`skill_system`、`lane.gd`、`unit.gd` 零改动。游戏运行仍走旧 lane 路径（Match 调 `build_v2_three_lanes`），arena 为新增并存模块、暂未接入对局主流程。

**决策**：见决策日志 36。补充：arena 几何走独立 `arena.json`（结构性、非平衡数值，不进 `build_config.py`/Excel 镜像）；塔占位用 floor 取整 + 半整数公主中心保证左右对称且与桥对齐；`can_deploy` 只管「地面 + 己方半场」，纯法术不受限属上层 `Player` 职责（V3-1f/g 接）。

**踩坑与修复**
- 无。`attack_range` 在 config_loader 仍校验 `0~1`（lane 量纲）——V3-1a 不动 units，故不受影响；2D 量纲转换留 V3-1b/d。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **132/132 全过**（+10 arena +1 config_loader，旧 121 零回归）✅
- `godot --headless --editor --path . --quit` → exit 0、`Arena` 类注册、新 `.uid` 生成、零解析/编译错误 ✅
- 纯逻辑层步骤，正确性由单测覆盖（按纪律无需肉眼验收）✅
- **GUI 视觉验收**：组卡界面外观/交互（点选/移除/满 8 开战）属表现层，留用户实机过目（逻辑+接线已验证，不阻塞）。

### V3-1b — 2D 单位移动 + 流场绕桥寻路（推倒重来：删 lane，逻辑+单测）  （本次提交）
**前置决策**：见决策日志 37（推倒重来、删 lane、`skill_system` 2D 提前、AI 搁置）。

**新增 / 修改（逻辑）**
- `logic/unit.gd`：1D → 2D。移除 `progress/lane_index/get_direction/move_to`，改 `pos:Vector2`；`move_speed`=tile/秒、`attack_range`=tile 距离（量纲改）；+`is_enemy/distance_to`。
- `logic/arena.gd`：+`units`/`towers`/`_flow`；`add_tower`(存引用+占位)、`add_unit`/`get_units`；**流场寻路** `build_flow_fields`/`_bfs_to_tower`（对每塔 BFS 距离场，4 邻、地面可走）；`tick(dt)`=逐单位选最近敌塔(流场距离)→沿梯度走、自动绕到最近桥过河→到 `attack_range+塔半径` 停（攻击留 V3-1d）；安全网不踏水/出界。
- `logic/battle.gd`：删 `lane.gd` preload / `lanes` / `add_lane`/`get_lane` / `build_v1_single_lane` / `build_v2_three_lanes`；`build_arena` 改 `arena.add_tower` + `arena.build_flow_fields`；`step`→`arena.tick`。
- `logic/skill_system.gd`：2D 化（原 V3-1f 提前）。`play_card(card_id, owner, pos:Vector2)`；spawn 在 pos（count>1 确定性散布避免完全重叠）；`direct_damage`=最逼近 pos 的敌方单位；`aoe_damage`=pos 圆心、tile 欧氏半径。
- `logic/player.gd`：`try_play_card(hand_index, pos)`；`_deploy_allowed` 委托 `arena.can_deploy`（地面 + 己方半场）。
- `logic/match.gd`：`setup` 改 `build_arena(level, config.get_arena("default"))`。
- `logic/config_loader.gd`：`attack_range` 校验 `0~1` → `≥0`（tile 量纲、无上限）。

**配置**
- `config/units.json`：`move_speed`(tile/秒)/`attack_range`(tile) 全改 tile 量纲（近战 ~1.0–1.2、archer 4.5、musketeer 5.5；giant 1.1 / goblin 2.6 tile/秒等）。
- `config/cards.json`：3 个 AOE `radius` 改 tile（fireball 1.5→3.0、arrows 0.5→2.5、log 0.4→2.0）。
- `tools/build_config.py`：Excel 列 `move_speed_lane_per_s`→`move_speed_tiles_per_s`、`attack_range_lane_ratio`→`attack_range_tiles`，去 0~1 校验（改 ≥0、attack_range 用 float）。`GameConfig.xlsx` 经 `--from-json` 重建、`--check` 通过。

**删除**
- `logic/lane.gd`（+uid）；`tests/test_lane.gd`、`tests/test_battle_v2.gd`（lane 拓扑）、`tests/test_ai_controller.gd`（AI 搁置，V3-1g 加回）（+uids）。

**测试（重写 + 新增）**
- 重写 `test_unit`（2D 位置/血量/冷却）、`test_battle`（arena 胜负——直接削塔验规则，单位攻击塔留 V3-1d）、`test_skill_system`（2D spawn/aoe/direct）、`test_match`（出牌→arena 单位 y 减小推进）、`test_player`（2D 落点半场/地面校验）。
- `test_arena` +3 移动测试：地面兵绕桥过河**全程不踏水**、到敌塔停下、对手兵对称反向过河。

**范围边界 / 现状**：游戏**暂无可玩画面**——`view/*` 与 `ai/ai_controller.gd` 仍引用旧 API（运行时坏、解析通过），分别留 V3-1h（显示层 2D）/ V3-1g（AI 2D）重写。本步正确性由 headless 单测覆盖。

**踩坑与修复**
- GDScript 类型推断：遍历无类型 const `_NEIGHBORS`（Vector2i）与无类型 `unit` 参数 → `:=` 推断失败；给循环变量标 `for off: Vector2i`、距离/坐标用显式 `var d: float`/`var min_y: float` 等。
- `build_config.py` 自带 `attack_range 0~1` 校验阻断 `--check` → 同步去除 + 列改 tile 语义。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **101/101 全过**（删 3 测试文件共 33 测；重写若干 + 新增 arena 移动测；预检 res://logic 编译通过）✅
- `godot --headless --editor --path . --quit` → exit 0：`view/*`、`ai_controller` 解析通过（仅运行时坏，符合预期）、`.uid` 重生 ✅
- `build_config.py --from-json` + `--check` → `config check ok`（量纲列改名后往返一致）✅
- 流场寻路（单测断言）：地面兵从 (4,20) 自动绕左桥过河、全程不踏水、停在敌方左公主塔攻击距离内；对手兵对称反向过河 ✅
- 逻辑层步骤，正确性由单测覆盖（按纪律无需肉眼验收；2D 画面验收在 V3-1h）。

### V3-1c — 目标获取 + 完整 CR 仇恨/分心（逻辑+单测）  （本次提交）
**前置决策**：见决策日志 36（仇恨=完整 CR 式：默认锁最近敌塔、敌方单位进 `aggro_radius` 转火、可拉扯/风筝、目标死/离开回锁）。

**新增 / 修改**
- `logic/unit.gd`：+`aggro_radius`（tile，配置读）+ `current_target`（运行时索敌目标，Unit 或 Tower；攻击/显示用）。
- `logic/arena.gd`：`tick` 加索敌层——`_nearest_enemy_unit_in_aggro`（aggro_radius 内最近存活敌兵）；有则 `current_target`=该兵 + 直线趋向（`_step_toward_point`，到 attack_range 停）；否则默认锁最近敌塔（流场绕桥，沿用 V3-1b）。**每 tick 重选** → 目标死/离开自动回锁。确定性 tie-break = units 顺序。
- `config/units.json`：每单位 +`aggro_radius`（近战 5.0 / 远程·空军 5.5）。
- `tools/build_config.py`：`UNIT_HEADERS` + 读/写 +`aggro_radius_tiles` 列；`GameConfig.xlsx` 经 `--from-json` 重建、`--check` 通过。
- `tests/test_arena.gd`：+6 仇恨测试（默认锁塔 / 进半径分心 / 半径外忽略 / 目标死回锁 / 侧边拉扯追击 / 选最近敌兵）。

**范围边界**：仅 logic + config + 单测。**索敌只决定「打谁/走向谁」，单位还不会真正掉血**（接敌攻击 = V3-1d）。分心目标的「只攻建筑」型单位（巨人式 `targets_only_buildings`）按 PLAN_V3 §5 待细化**暂不引入**（当前所有兵都会被分心；该行为在 d/e 接入攻击/塔火前不可观测，故推迟到 V3-1d/e 或 V3-3 再定）。AI/view 仍搁置（V3-1g/h）。

**踩坑与修复**
- 无新坑。沿用 V3-1b 类型标注经验（无类型 `unit` 参数 → `var r/d: float`、`unit.pos as Vector2`）。新增 unit 字段 `aggro_radius` 必须同步进 Excel 管线（否则 `--check` 失败）。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **107/107 全过**（+6 aggro，旧 101 零回归）✅
- `build_config.py --from-json` + `--check` → `config check ok`（+aggro 列往返一致）✅
- 仇恨行为由单测覆盖：默认锁塔 / 进 aggro 转火 / 半径外忽略 / 目标死回锁 / 侧边拉扯追击(距离缩小) / 选最近敌兵 ✅

### V3-1d — 软推挤碰撞 + 接敌攻击（逻辑+单测）  （与 V3-1c 同批待提交）
**前置决策**：见决策日志 36（碰撞=软推挤：体积半径 + 确定性分离，不用物理引擎）。

**新增 / 修改**
- `logic/unit.gd`：+`body_radius`（tile，配置读）。
- `logic/arena.gd`：`tick` 重构为 5 段——①冷却 ②索敌+移动(到射程停) ③**软推挤分离** `_separate`（固定 i<j 序、2 趟、沿连心线各推半个重叠、完全重叠确定性兜底、推后不进水/塔/出界）④**攻击结算** `_in_attack_range` + 收集后统一 `take_damage`（首击免费沿用 `can_attack`；目标可为 Unit 或 Tower——**单位现在能削塔**，王塔归零经 `Battle._check_victory` 判胜负）⑤清死。统一 `_acquire_target`/`_move_toward`/`_in_attack_range`（`target is Tower` 区分流场 vs 直线、塔目标加塔半径）。删旧 `_reached_tower`。
- `config/units.json`：每单位 +`body_radius`（群兵 0.35 / 普通 0.45–0.55 / 巨人 0.8 / 小龙 0.7）。
- `tools/build_config.py`：+`body_radius_tiles` 列（读/写）；Excel `--from-json` + `--check` 通过。
- `tests/test_arena.gd`：+4 测（重叠被推开≈体积和、攻击敌兵首击 -50、攻击敌塔总塔血下降、双方同 tick 互伤）。

**范围边界**：仅 logic + config + 单测。**塔本身还不会主动反击**（=V3-1e）；塔被单位摧毁后**流场暂不重算**（`rebuild_flow_fields` 已备、V3-1e 接通；当前死塔退出索敌、单位改打活塔、路径绕过死塔占位，正确但非最优）。巨人「只攻建筑」仍按 §5 暂缓。AI/view 仍搁置（V3-1g/h）。

**踩坑与修复**
- 无新坑。`target is Tower`（全局 class_name）区分塔/兵目标、免类型耦合；分离与攻击均确定性（固定序、收集后统一应用）。新增 `body_radius` 同步进 Excel 管线（否则 `--check` 失败）。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **111/111 全过**（+4，旧 107 零回归）✅
- `build_config.py --from-json` + `--check` → `config check ok` ✅
- 战斗链路由单测覆盖：重叠被推开 / 接敌首击掉血 / 单位削塔 / 双方同 tick 互伤 ✅

### V3-1e — 塔会反击 + 塔毁流场重算（逻辑+单测）  （本批待提交）
**前置决策**：见决策日志 36（塔反击是 CR 防御核心）。
**新增 / 修改**
- `logic/tower.gd`：+`damage`/`attack_range`/`attack_speed` + 冷却（`tick_cooldown`/`can_attack`/`mark_attacked`，与 Unit 同口径）。
- `logic/arena.gd`：`tick` +塔冷却推进 + **塔攻击**（射程内最近敌方单位、收集后统一结算）；塔被摧毁 → `_rebuild_tower_rects`（死塔占位释放为地面）+ `build_flow_fields`（跳死塔，一次性触发）。+`_nearest_enemy_unit_to_tower`。
- `config/arena.json`：+`tower_combat`（king/princess 各 damage/attack_range/attack_speed；结构性、不进 Excel）。
- `logic/battle.gd`：`build_arena` 读 `tower_combat` 设塔战斗数值（`_build_side_towers` 加 combat 参）。
- `tests/test_arena.gd`：+3（塔打射程内敌兵 / 不打己方·射程外 / 塔毁占位释放重算）；移动测试改高血量（扛塔火走完全程）、两单位互攻测试移到中场无塔火区（y17）。
**验收**：单测 **114/114**；`config check ok`。塔反击/塔毁重算由单测覆盖。

### V3-1f — SkillSystem 2D 化  （已于 V3-1b 完成）
推倒重来删 lane 时 `skill_system` 被迫一并 2D 化（决策 37），本槽空出，无独立改动。

### V3-1g — AIController 2D 重写（逻辑+单测）  （本批待提交）
**前置决策**：见决策日志 33（攻防结合 + 按向选 + 难度分级）2D 化。
**新增 / 修改**
- `ai/ai_controller.gd`：从死代码重写为 2D。难度表 `DIFF`(threshold/cooldown/defends/smart) 沿用；`_decide` 防守优先（`_most_threatening_player_unit`：玩家单位 `y<=THREAT_LINE` 越河威胁 → 在其 x 处 `clampf(y,10,14)` 空投最贵兵）→ 否则 `_attack`（最贵可用兵 → `_attack_pos`：智能档集火 `_weakest_player_tower` 的 x 侧、easy 固定中路 x=9；法术落 `_lead_player_unit_pos`）。经 `opponent.try_play_card(idx, pos)`，确定性无随机。
- `tests/test_ai_controller.gd`（重新加回，7 测）：难度解析(关卡/覆盖)、阈值门控、出最贵兵入场、冷却、easy 阈值高于 hard、受威胁防守空投(投在威胁 x 附近)、集火最弱塔侧(x≈最弱塔)。
**验收**：单测 **121/121**（+7）。

### V3-1h — 显示层 2D 接通（仅 view，真人实机验收）  （本批待提交）
**前置决策**：见决策日志 36/37（2D 场地、tap 落点）。
**新增 / 修改**
- `view/battle_scene.gd`：**整体重写为 2D**。tile↔屏幕映射（`_t2s`/`_s2t`/`_field_rect`）；`_draw` 画地形（地面/河/双桥 + 己方半场部署区提示）+ 6 塔（按 owner 色/血条变色/王塔标记/摧毁灰块）+ 自由移动单位（队伍色圆 + 空军白环 + 血条）+ 顶栏（王冠/倒计时）+ 圣水条；手牌 `Button`×4（费用/置灰/选中高亮）；结算面板（WIN/LOSE/DRAW + 比分 + REMATCH/MENU）。两段式出牌：点卡选中 → 点己方半场落点 `player.try_play_card(_s2t(click))`；对手由 `AIController` 自驱（`set_opponent_controller`）。读 `GameState.level_id`/`player_deck`。
**范围边界**：仅 view（+本批其它子步的逻辑）。lane 时代 FX（投射物/受击闪白/爆点/塔碎块等）**未移植**，留 V3-4/V3-7 随美术重做。
**验收**
- `godot --headless --editor --path . --quit` → exit 0，`battle_scene.gd` 无解析错误、`.uid` 重生 ✅
- `timeout 6 godot --headless --path . res://view/battle_scene.tscn` → 6s 实跑（`_ready`→`_process`(match.update→AI→arena.tick)→`_draw`）**零运行期错误** ✅
- 单测仍 **121/121**（逻辑零回归）✅
- **画面/手感留真人实机验收**：这是 2D 重构后**首次可玩**——菜单→选关→组卡→对局，应能在己方半场任意点出兵、看兵绕桥推进/转火/挤压/塔互射、拆塔分胜负。验收清单见下。

> **V3-1（2D 战斗核心 reboot）收官**：a 场地 → b 移动寻路 → c 仇恨/分心 → d 软分离+攻击 → e 塔反击 → f(并入 b) → g AI 2D → h 显示层 2D。lane 模型已彻底移除。单测 **121/121**。下一步 **V3-2 空军（飞兵越河 + 对空克制）**。

**V3-1h 真人实机验收清单（交用户）**：在编辑器运行（主场景 main_menu）→ 选关 → 组卡(默认即可) → 对局，确认：① 场地能看出河 + 左右双桥 + 双方各 3 塔；② 己方半场任意点能出兵、越界/水/塔上不能出；③ 地面兵自动**绕到桥**过河、不走水；④ 兵接敌会**转火打架**、能互相**挤开/堵路**；⑤ 兵靠近敌塔时**塔会开火**反击；⑥ 拆掉王塔/超时比塔血能正常**分胜负**并弹结算（REMATCH/MENU 可用）。回报「通过/哪条不对」。

---

## V3-2 — 空军：飞兵越河 + 对空克制（逻辑+config+view+单测）  （待提交）
**前置决策**：见决策日志 36（首版先全地面、空军作为 V3-2 紧随）。

**新增 / 修改**
- `logic/unit.gd`：+`attack_targets`(ground/air/both) + `is_flying()`(派生自 `target_type=="air"`，不加冗余字段) + `can_hit_type(t)`。
- `logic/arena.gd`：①索敌按 `can_hit_type` 过滤——纯地面兵**不锁/不打**空军（也不被其分心）；②飞行单位 `_step_fly` **直线越河、忽略地形**（只挡出界）；③软分离**仅同层**（空/地不同层互不挤）、`_apply_push` 飞行可越水/塔。**塔不按类型过滤**（towers 命中空地皆可 = 对空安全网，CR 口径）。
- `config/units.json`：每单位 +`attack_targets`（近战/giant=ground；archer/musketeer/minion/baby_dragon=both）。
- `tools/build_config.py`：+`attack_targets` 列（`ATTACK_TARGETS` 枚举 + 校验 + Units 表下拉）；`GameConfig.xlsx` 同步。
- `view/battle_scene.gd`：飞兵画在上层（单位上浮 + 地面投影），辨识空/地。
- `tests/test_arena.gd`：+5（飞兵直线越水过河 / 纯地面打不到空军 / 对空兵(both)命中空军 / 塔对空 / 空地不互挤）。

**范围边界**：仅 logic + config + view + 单测。巨人「只攻建筑」(`targets_only_buildings`) 仍按 §5 暂缓。`is_flying` 由 `target_type` 派生（不引入冗余配置）。飞兵「按 ground 流场距离选目标」是小近似（飞行移动已直线，目标选择沿用流场最近，足够；如需精确改欧氏留后续）。

**踩坑与修复**
- 无逻辑坑。两处 GDScript 类型推断（`var flying: bool`、测试里塔火干扰）按既有经验处理；对空测试单位需放「双方塔火射程外」的中场(y17 一带)纯测单位互攻。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **126/126 全过**（+5）✅
- `godot --headless --editor --path . --quit` → exit 0、无解析错误 ✅
- `timeout 6 godot --headless --path . res://view/battle_scene.tscn` → 6s 实跑零运行期错误 ✅
- `build_config.py --from-json` + `--check` → `config check ok`（+attack_targets 列往返一致）✅
- 对空克制由单测覆盖：飞兵越水 / 地面无法对空 / 对空兵与塔可打空 / 空地不互挤。表现层（飞兵上浮显示）留真人验收。

---

## V3-3 — 新技能积木：亡语召唤 + 治疗术（逻辑+config+单测）  （待提交）
**前置决策**：PLAN_V3 §3/§5（2–3 个新积木择优）。选**接入最干净、价值最高**的两个；slow/stun（需状态系统）、knockback（需新列）、建筑（需生成计时）留后续。

**新增 / 修改**
- **亡语召唤 `on_death_spawn`**（单位行为）：`unit` +`death_spawn_id`/`death_spawn_count`/`death_spawn_config`（config 模板由 `SkillSystem` 生成时注入 → `Arena` 死亡处理无需依赖 ConfigLoader）；`arena._remove_dead` 死亡时在原地裂出 N 个（确定性散布、append 后下 tick 生效）。新单位 `golem_body`（坦克 hp3000，死后裂 2× `goblin_body`）+ 卡 `golem`(费7)。
- **治疗术 `aoe_heal`**（法术块）：`unit` +`heal()`（仅活体、不超 max）；`skill_system` +`_aoe_heal`（治范围内**友军**，复用 `damage` 字段为治疗量）；卡 `heal`(费3, r3/150)。
- `logic/config_loader.gd`：+`death_spawn_unit` 交叉引用校验。
- `tools/build_config.py`：`SKILL_TYPES` +`aoe_heal`（复用 radius/damage 列，写侧通用无需改）；`UNIT_HEADERS` +`death_spawn_unit`/`death_spawn_count`（可选列，仅填了才写入 JSON）；Excel 同步。
- `config/units.json` +`golem_body`；`config/cards.json` +`golem`/+`heal` → **16 卡 / 10 单位**。
- `tests`：`test_skill_system` +2（治友不治敌 / 治疗封顶）；`test_arena` +1（石头人亡语死裂 2 哥布林，经真 `golem` 卡 + skill_system 端到端）。

**范围边界**：仍走数据驱动积木、与现有积木可叠。巨人「只攻建筑」仍按 §5 暂缓。view 未为 `golem`/`heal` 专门换形（golem 用默认圆，heal 无专属 FX）——美术/FX 留 V3-4/V3-7。`is_flying`/`death_spawn` 量纲与列均经 Excel 往返校验。

**踩坑与修复**
- 无逻辑坑。`aoe_heal` 复用 `damage` 列（=治疗量），写侧 CardSkills 是通用列映射故零改；`death_spawn` 用「仅非空才写 JSON」保 Excel↔JSON 往返一致（多数单位无此键）。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **129/129 全过**（+3）✅
- `build_config.py --from-json` + `--check` → `config check ok`（+aoe_heal / +death_spawn 两列往返一致）✅
- 新积木由单测覆盖：亡语裂兵 / 治友不治敌 / 治疗封顶。

---

## V3-4 — Roguelite 主轴（进行中）

> 方向见决策日志 36，权威规划见 [PLAN_V3.md](PLAN_V3.md) §3。拆 4 小步：a run 状态+节点地图+连战链 / b draft 三选一 / c relic / d boss+meta+存档。逻辑+单测为主、配最简 view。

### V3-4a — Roguelite 骨架：RunState + 节点地图 + 连战流转（逻辑+config+单测）  （待提交）
**前置决策**：见决策日志 38（线性连战链 / 二元永久死亡 / 3 act × 3 战；遭遇引用现有 level；起始卡组用 deck_builder 选的卡组）。

**新增**
- `config/run.json`（新，结构性、**不进 Excel 镜像**——比照 `arena.json`）：`default` run = `starter_deck`(8) + `acts`(3)×`nodes`(3)；每节点 `{type: battle/elite/boss, level_id}`，引用现有 `levels.json` 关卡（act 末为 boss；当前仅 4 关复用，富遭遇池留内容步）。
- `logic/run_map.gd`（`RunMap`）：把 `run.json` 的 acts 结构**展开成扁平节点链** `nodes`（每项 `{type, level_id, act, index_in_act}`）；`size()`/`node_at(i)`（越界返空）。纯数据、确定性。
- `logic/run_state.gd`（`RunState`）：run 可变状态——`deck`(run 工作卡组，draft V3-4b 改写) / `map`(RunMap) / `cursor` / `status`(ONGOING/WON/LOST) / `wins` / `seed`(预留) / `relics`(预留 V3-4c)。`advance(battle_result)` 流转：仅 `RESULT_PLAYER_WIN` 推进（走完末节点 → WON），`OPPONENT_WIN`/`DRAW` → LOST（永久死亡），`ONGOING` → no-op。`current_node()`/`is_over()`。`_init` 对传入卡组 `duplicate()`（不回写配置）。

**修改**
- `logic/config_loader.gd`：`load_all` 纳入 `run.json` → `run` 字段；`_validate` 加 run 校验（default 含非空 acts；节点 `type` 合法、`level_id` 必须在 levels 中；`starter_deck` 卡必须在 cards 中）；+`get_run(id="default")`。
- `tests/test_config_loader.gd`：+1（`test_v3_run_config_loaded`：run 已加载、default 含 starter_deck(8)+acts(3)、交叉引用无错）。

**测试（新增）**
- `tests/test_run_map.gd`（4）：acts 展开成 9 节点链 / 节点带 type+act 标签(act 末为 boss) / 越界返空 / 所有节点 level 存在。
- `tests/test_run_state.gd`（10）：初态 / 卡组是独立副本 / 胜推进 / 9 连胜→通关(且通关后 advance 无副作用) / 对手胜→永久死亡 / **平局→永久死亡** / ONGOING→no-op / 中途败北止步保留胜场 / **headless 全胜跑通一条 run（真 `Match` 逐节点建场跑 tick + 强制结果喂回 advance → RUN_WON）** / headless 首战败北→RUN_LOST 不推进。

**范围边界 / 现状**：仅 logic + config + 单测。**菜单→run→对局→下一节点的 view 接入不在 4a**（4a 验收 = 单测 + headless 跑通；最简 view 留后续小步）。draft（改写 run 卡组）= V3-4b；relic = V3-4c；boss/精英差异化 + meta + 存档 = V3-4d（4a 仅给节点打 `type` 标签备用）。

**踩坑与修复**
- 无逻辑坑。`config_loader.gd` 内 `_validate` 缩进为 Tab，编辑时按既有 Tab 缩进对齐。run.json 结构性、不入 Excel，故 `build_config.py` 零改、`--check` 不涉及。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **144/144 全过**（+15：RunMap 4 + RunState 10 + ConfigLoader 1；旧 129 零回归），exit 0 ✅
- `godot --headless --editor --path . --quit` → `RunMap`/`RunState` 类注册、`.uid` 生成、零解析错误 ✅
- `build_config.py --check` → `config check ok`（未动 units/cards/levels，Excel 无漂移）✅
- run 推进 / 胜负流转 / 连战链 / headless 跑通一条 run（全胜→通关、首败→失败）均由单测覆盖。纯逻辑步骤，按纪律无需肉眼验收。

### V3-4b — 战间 draft 三选一（逻辑+单测）  （本批待提交）
**前置决策**：见决策日志 39（确定性候选、追加进 run 卡组、卡组可增长、可 SKIP）。
**新增 / 修改**
- `logic/run_rewards.gd`（`RunRewards`，新）：`offer_cards`/`offer_relics`——从池中剔除已持有、seeded Fisher-Yates 确定性取 N（同 seed 同结果，零随机副作用）。
- `logic/run_state.gd`：+`add_card`（追加进 run 卡组、去重）/`add_relic`（去重）。
- `logic/deck.gd`：放宽 `setup` 为 ≥`HAND_SIZE`+1（不再硬限 8），支持 draft 后卡组增长；标准对局仍 8。
- `tests`：`test_run_rewards`(6)、`test_deck`+1（10 张增长卡组循环不变量）、`test_run_state`+3（加卡增长去重 / 加 relic 去重 / **draft 卡带入下一场 Match**）。

### V3-4c — relic 系统：JSON 数值修正器（逻辑+config+单测）  （本批待提交）
**前置决策**：见决策日志 39（effective level 深拷贝、不污染 base、起手圣水、单位级 relic 留后续）。
**新增 / 修改**
- `logic/run_modifiers.gd`（`RunModifiers`，新）：`effective_level(base, mod_sources)`——深拷贝后顺序叠加 `val=val*mult+add`（圣水回速/上限/起手、时长、王/公主塔血），**base 不变**；`relic_mods`（relic id→mods 数组）；`node_mod`（节点难度修正查表）。
- `config/relics.json`（新，结构性、不进 Excel）：7 个 relic（含 2 个 `unlock` 门控）。
- `logic/match.gd`：`setup` +`modifiers` 形参（经 `effective_level` 作用，空=行为同前）；起手圣水 `elixir_start` 经 `Elixir` 第三参注入（`_make_player` +`estart`）。
- `logic/config_loader.gd`：载入 `relics.json` + 校验（每 relic 含 mods 对象）+ `get_relic`。
- `tests`：`test_run_modifiers`(7)、`test_match`+1（修正器抬塔血/起手圣水且不污染 base）、`test_config_loader`+1（relics 加载）。

### V3-4d — boss/精英 + 局间 meta 解锁 + 存档 + 最简 run view（逻辑+config+view+单测）  （本批待提交）
**前置决策**：见决策日志 39（节点难度走同一修正器引擎、meta 门控解锁 relic、user:// 往返、view 最简）。
**新增 / 修改（逻辑+config）**
- `logic/meta_progress.gd`（`MetaProgress`，新）：局间统计（runs_started/won、bosses_defeated）+ `available_relics`/`unlocked_ids`（按 relic 的 `unlock:{stat:阈值}` 解算）+ `load_dict`/`to_dict`。
- `logic/save_system.gd`（`SaveSystem`，新）：`user://` 存读 meta（持久）+ run（可续跑，地图由 config 重建后 `load_dict` 恢复进度）；路径可注入（单测用临时档）。
- `logic/run_state.gd`：+`to_dict`/`load_dict`（序列化，不引用自身 class_name）。
- `config/run.json`：+`node_modifiers`（elite/boss 抬塔血）。
- `tests`：`test_meta_progress`(5)、`test_save_system`(4)、`test_run_modifiers`+1（node_mod）、`test_run_state`+1（to/load_dict 往返）。
**新增 / 修改（view，最简可玩）**
- `view/run_scene.gd`+`.tscn`（新）：run 节点链中枢——画连战链(完成/当前/boss 标记)+run 卡组/relic 摘要；处理回传战斗结果(推进/记 boss/给奖励/结算+存盘)；FIGHT→battle、奖励三选一覆盖层(卡/relic)、结算覆盖层(通关/败北+解锁展示)、NEW RUN/MENU。
- `view/battle_scene.gd`：run 模式——读 `GameState.run` 当前节点 level_id+run 卡组+relic/节点修正建场；结算改 CONTINUE 回 run 中枢（写 `run_last_result`）。
- `view/game_state.gd`：+`run`/`run_last_result`/`meta` 静态变量（run 模式握手）。
- `view/main_menu.gd`：+ROGUELITE 入口（→ run_scene，续档/新开）。

**范围边界 / 现状**：4b/c/d 一批完成。单位级 relic、分叉地图、富遭遇池、deck-builder 选 run 起始卡组、UI 美术/FX 均留后续。view 为白膜最简，**run 引擎内流程/手感交真人验收**。

**踩坑与修复**
- 新类 `static from_dict` 引用自身 `class_name`：.uid/全局注册前被 test runner 预检判失败 → 改实例方法 `load_dict`（不引用自身 class_name）。
- headless smoke：`--script` 的 `_initialize` 期 `add_child` 不触发 `_ready` → 须显式调 `_ready()`（非代码 bug）；杀进程残留 `user://` 半档会污染下次 smoke → smoke 前清档。

**验收**
- `HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd` → **172/172 全过**（+28：rewards 6 + modifiers 8 + meta 5 + save 4 + deck 1 + run_state 4 + config 1 + match 1；旧 144 零回归），exit 0 ✅
- `godot --headless --editor --path . --quit` → exit 0、新类注册、`.uid` 生成、零解析错误 ✅
- `build_config.py --check` → `config check ok`（relics.json/run.json 结构性、未动 Excel 镜像）✅
- headless smoke（显式 `_ready()`）：run 中枢建 9 节点/8 卡 run；battle run 模式用节点 level+run 卡组建场（boss 节点王塔 2600×1.5=3900 ✓）；胜后回中枢推进+给奖励（普通→卡 draft 3 选 1；boss→记 boss+relic 奖励，含解锁的 giants_blood）✓。
- **run 引擎内完整流程/手感留真人实机验收**（清单见下）。

**V3-4 真人实机验收清单（交用户）**：编辑器运行主场景 → 主菜单点 **ROGUELITE**，确认：
1. 进入 run 中枢，看到 **9 个节点的连战链**（Act 1/2/3，每 act 末 BOSS 红标）、当前节点高亮、底部显示 **run 卡组(8)** 与 **RELICS (none)**；
2. 点 **FIGHT** 进战斗，确认用的是 run 卡组、能正常打（绕桥/转火/塔互射/拆塔）；
3. 战斗结束点 **CONTINUE** 回中枢：**胜** → 普通节点弹 **DRAFT A CARD 三选一**，选 1 张后回中枢、卡组 +1、当前节点推进；**败/平** → 弹 **RUN OVER** 结算 → BACK TO MENU；
4. 打到 **BOSS/ELITE 节点**：该战更硬（塔血更高），**胜后弹 CHOOSE A RELIC 三选一**，选 1 个后中枢 RELICS 出现该 relic，且后续战斗能感到 relic 生效（如起手圣水/塔更肉/回速更快）；
5. 连胜通关最后 BOSS → 弹 **RUN CLEARED** + 统计（Runs won / Bosses beaten）+ 若达成则显示 **Unlocked: …**；
6. 中途点 **MENU** 离开再进 ROGUELITE → 能**续上同一条 run**（存档）；点 **NEW RUN** → 重开一条新 run；通关/败北后回菜单再进 → 开新 run（旧档已清）。
回报「通过/哪条不对」。

---

## V3-6 — 交互与游戏手感（进行中）

> 方向见 PLAN_V3 §3，范围/拆步见决策日志 41。纯显示层（零逻辑改，决策 30 路线 A），拆 4 个真人验收 gate：6a 部署交互 → 6b 战斗 juice → 6c 圣水/HUD → 6d 胜负/run 总结。全部在白膜上装「手感系统」，V3-7 再贴精灵皮。

### V3-6a — 拖拽部署 + 落点反馈（仅 view）  （待提交）
**前置决策**：见决策日志 41（拖拽部署 CR 式、纯显示层）。

**修改（仅 `view/battle_scene.gd`，零逻辑改）**
- **拖拽部署**取代两段式 tap：手牌 `Button` 由 `pressed` 改 `button_down`(开始拖)/`button_up`(松手落子)；拖拽中每帧读 `get_viewport().get_mouse_position()`。落点经 `_drop_tile_from` **抬到手指上方** `DROP_LIFT_TILES=1.6` tile（拇指不遮挡）。松手在 HUD/顶栏 → 取消；在场上 → `player.try_play_card(sc, drop_tile)`（出牌路径不变、玩家/AI 仍对称）。出不起的牌 `disabled` → `button_down` 不触发，**拖不动**。
- **落点 ghost**（`_draw_drag_ghost`，仅拖拽中）：`_card_info` 解析卡 `skills` 判类型——spawn→画 `count` 个兵剪影（半径取 `UNIT_VIS`、确定性环形散布）；`aoe_damage/aoe_heal`→画 AOE 半径圈；`direct_damage`→画准星。**合法绿/非法红**：spawn 用 `arena.can_deploy(0, drop_tile)`（与逻辑同一校验，所见即所得）、法术恒绿（不受半场限，沿用决策 26）。
- **己方半场高亮**（`_draw_deploy_hint`）：仅拖兵牌时，部署区叠加绿色脉动（`sin(_elapsed*6)`）。
- **落地涟漪**（`_fx` 列表 + `_draw_fx`/`_cull_fx`）：成功落子在落点压一条扩散淡出环（`POOF_DUR=0.40s`）。
- **入场缩放**（`_seen: instance_id→首见时刻` + `_pop_scale`）：新单位半径从 0.35 ease-out 弹到 1.0（`POP_DUR=0.22s`），AI 兵同享；每帧剔除已死 id。
- **卡牌抬起**：拖拽中源卡上移 14px + 金色高亮（`_card_base_pos` 存基位）。
- 顺带补 `UNIT_VIS["golem_body"]`（V3-3 遗漏，原为默认 0.5 圈）。

**范围边界**：仅 view，逻辑/config/单测零改。受击数字/插值/顿帧/震屏在 6b；分段圣水/冷却扫光在 6c；胜负演出在 6d。FX 全程序化白膜（无外部素材），V3-7 贴皮。

**踩坑与修复**
- `var id := u.get_instance_id()`：无类型 `u`（遍历无类型数组）→ 类型推断失败（沿用既有 GDScript 坑）。改 `var id: int = ...`。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn --quit-after 300` → 改后零脚本/运行期错误（退出期 ObjectDB/resource leak 警告为 `--quit-after` 强退的善性 teardown，非本步代码）✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **真人实机验收：7/7 全过（2026-06-16）** ——拖拽落子 + ghost 数量/抬起 + 红绿合法性 + 半场脉动 + 法术 AOE 圈/准星(敌方半场也可) + 置灰拖不动/卡抬起 + HUD/非法取消 + 涟漪/入场缩放 + 胜负结算，均通过。✅

**V3-6a 真人实机验收清单（已通过，留作回归基线）**：F5 运行（编辑器已开，Play 读盘最新脚本）→ ROGUELITE/任意关进战斗，确认：① 按兵牌拖到场上有**兵剪影 ghost**（数量正确、抬在手指上方），松手落子；② ghost/落点环 **己方半场地面=绿、敌方半场/水/塔=红**，拖兵牌时己方半场**脉动高亮**；③ 法术：火球/箭/滚木拖出 **AOE 圈**、电击/闪电出**准星**，且**敌方半场也绿**（可放）；④ 出不起的牌**置灰拖不动**，拖动的卡**抬起高亮**；⑤ 松手在 HUD/非法处=**取消**（不扣圣水不出兵）；⑥ 成功落子有**涟漪**、新兵（含 AI 兵）**弹入**；⑦ 胜负结算/CONTINUE 仍正常。回报「通过/哪条不对」。

### V3-6b — 战斗 juice：插值 + 受击反馈 + 顿帧 + 震屏（仅 view）  （待提交）
**前置决策**：见决策日志 41（纯显示层、逐帧 diff 逻辑状态派生反馈 = 决策 30 路线 A）。

**修改（仅 `view/battle_scene.gd`，零逻辑改）**
- **移动插值（10Hz→60fps）**：`_disp: id→显示位`，每帧 `lerp(u.pos, 1-exp(-SMOOTH_K·dt))` 指数平滑（`SMOOTH_K=18`），单位按 `_disp_pos` 作画 → 10Hz 逻辑步进显示层丝滑（合架构铁律「显示层做插值」）。新兵首见以逻辑位初始化（仍配 6a 入场缩放）。
- **逐帧 diff 事件**（`_detect_events`）：比对单位/塔 `hp` 与上帧（`_uhp`/`_thp`）——降→受击（数字+闪白+火花，按阈值触发顿帧/震屏）、升→治疗（绿 `+N`，复用治疗术效果）、塔从存活→摧毁→塔毁演出。不读逻辑内部事件、纯状态差分。
- **受击闪白**（`_flash: id→结束时刻`）：命中后 `FLASH_DUR=0.12s` 内单位/塔填充色向白 lerp（≤0.85）。
- **浮动伤害数字**（`_dmgnums`）：命中处上浮淡出（`DMGNUM_DUR=0.75s`、升 34px）；普通白、≥`HITSTOP_DMG` 金色大号、治疗绿 `+`。坐标用 tile（经 `_t2s` 随场抖动）。
- **命中顿帧**（`_hitstop_t`）：单次伤害 ≥`HITSTOP_DMG=200`（法术/重击/塔毁）→ 冻结 sim `HITSTOP_DUR=0.06s`（`_process` 跳过 `match.update`、画面继续；累加器自然追帧、不丢 tick）。
- **震屏**（`_shake`/`_shake_mag`）：经 `_t2s` 加 `_shake` 偏移 → **只抖场内（地形/塔/兵/FX），HUD 不抖**（顶栏/圣水绝对坐标、卡牌/结算为 Control 子节点）；`_s2t` 不含抖动 → 落点输入不受影响。幅度分级（命中 3 / 大伤 6 / 塔毁 12，上限 14），`SHAKE_DECAY=42/s` 衰减。
- **命中火花**（`_sparks`）：命中处径向短线爆裂淡出（`SPARK_DUR=0.18s`，白膜占位）。
- 瞬时表（`_fx`/`_dmgnums`/`_sparks`）统一 `_cull_transients`/`_cull_list` 按时长回收；单位级 `_disp`/`_uhp`/`_seen` 随死亡剔除；`_flash` 按时回收。

**范围边界**：仅 view，逻辑/config/单测零改。攻击命中 FX 为白膜径向线（V3-7 贴粒子）。圣水/HUD 反馈（分段/扫光）在 6c；胜负/run 总结演出在 6d。**伤害数字是逐帧状态差分的近似**：同帧多次掉血合并为一个数（10Hz 下每数帧才一跳，足够；精确逐次留 6d/后续若需）。

**踩坑与修复**
- 无新坑。沿用 6a：无类型 `u` 的 `get_instance_id()` 用 `var id: int =`；Dictionary 一律 `d["k"]` 取值（GDScript 无点取字典）。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn --quit-after 360` → 零脚本/运行期错误（退出期 leak 警告为强退善性 teardown）✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **战斗手感留真人实机验收**（清单见下）。

**V3-6b 真人实机验收清单（交用户）**：F5 运行 → 任意战斗，确认：① 兵移动**丝滑**不再 10Hz 跳格（尤其过桥/转向）；② 被打的兵/塔**闪白**、冒**伤害数字**（数值合理、上浮淡出）；③ 治疗术给友军冒**绿 +数字**；④ 法术（火球/闪电）等大伤害命中有**顿帧**（极短卡顿）+ **震屏**，且**只有战场抖、顶栏/圣水/手牌不抖**；⑤ **塔被摧毁**时明显**震屏 + 大涟漪**；⑥ 震屏时**落点仍准**（拖拽出兵不偏）；⑦ 帧率正常、无报错。回报「通过/哪条不对」。

### V3-6c — 圣水/HUD 反馈（仅 view）  （待提交）
**前置决策**：见决策日志 41（纯显示层 HUD：分段圣水/满槽脉动/卡牌可用态扫光/下一张预览/王冠倒计时强调）。

**修改（仅 `view/battle_scene.gd`，零逻辑改）**
- **分段圣水条**（`_draw_elixir` 重写）：按 `elixir.maximum`（relic 可改，四舍五入取整）画 N 段 pip，满格逐段填、当前段按小数部分部分填；`is_full()` → 满槽紫色**脉动**（`sin(_elapsed*8)`）。左侧留位给「下一张」chip。
- **下一张预览**（`_draw_next_chip`）：读 `deck.peek_next()`，圣水条右侧画 NEXT chip（卡名截断 + 费用珠）。
- **卡面自绘**（`_draw_cards` + 透明 Button）：手牌 Button 改为**纯输入热区**（`StyleBoxEmpty` 覆盖 normal/hover/pressed/disabled/focus、`focus_mode=NONE`、清空 text），卡面由父 `_draw` 自绘（底板 + 卡名 + 费用珠 + 选中金框/拖拽抬起）→ 便于 V3-7 贴皮。**不可用「扫光」**：出不起的牌压暗罩，暗罩高度随 `圣水/费用` 进度从底部回落（CR 式蓄费提示）。`_sync_cards` 简化为只设 `disabled`（出不起/空格不可拖，沿用 6a）。
- **王冠 + 倒计时强调**（`_draw_topbar` 重写）：左右各画 **3 个王冠**（`_draw_crown` 多边形剪影，按拆塔数填实/描边）取代纯数字；倒计时 ≤30s **红色脉动 + 放大**。
- 底部新增 HUD 底板矩形。

**范围边界**：仅 view，逻辑/config/单测零改。卡面/王冠/圣水珠均程序化白膜（V3-7 贴精灵/UI kit）。胜负与 run 总结演出在 6d。

**踩坑与修复**
- `var cost := match_obj.player.card_cost(nx)`：`match_obj` 无类型 → 方法返回值为 Variant、`:=` 推断失败。改 `var cost: int =`（沿用既有坑）。
- 卡面在父 `_draw` 画、Button 为透明子节点覆于其上：故 Button 必须 `StyleBoxEmpty` 全覆盖（含 hover/pressed/focus）+ 清 text，否则默认样式遮住自绘卡面。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn --quit-after 360` → 零脚本/运行期错误 ✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **HUD 外观/反馈留真人实机验收**（清单见下）。

**V3-6c 真人实机验收清单（交用户）**：F5 运行 → 任意战斗，确认：① 圣水条是**分段 pip**、随回涨逐格填、**满 10 格时脉动**；② 圣水条旁有 **NEXT** 预览（下一张卡名 + 费用珠）且随出牌更新；③ 手牌为**自绘卡面**（卡名 + 费用珠 + 选中金框 + 拖拽抬起）；④ 出不起的牌有**暗罩扫光**、随圣水接近费用**从底部回落**到点亮，且**仍拖不动**直到够费；⑤ 顶栏左右各 **3 王冠**、按拆塔**点亮**；⑥ 倒计时 **≤30s 变红脉动放大**；⑦ 帧率正常、无报错、出牌/拖拽仍正常。回报「通过/哪条不对」。

### V3-6d — 胜负演出 + run 奖励/结算揭示（仅 view）  （待提交）
**前置决策**：见决策日志 41（纯显示层；本 gate 跨 `battle_scene`(结算) 与 `run_scene`(奖励/结算) 两场景）。

**修改（`view/battle_scene.gd`，零逻辑改）**
- **结算改演出**：去掉旧「一结束即建 Label/Button 静态面板」，改单一 `_end_t` 计时的 `_draw_end_screen`（全 `_draw` 绘制）——调暗淡入 → **标题 sting**（透明淡入 + 字号 `_ease_back` 回弹）→ **王冠逐个落入**（你拆塔数，错峰 + 回弹下落，复用 `_draw_crown`）→ **比分滚动**（count-up）；`END_BTN_DELAY=0.85s` 后按钮（CONTINUE / REMATCH+MENU）淡入。`_result_layer` 一结束即 `visible`（透明全屏 STOP）**拦截点击 → 演出期不能再出牌**。新增 `_ease_back`（back-out 缓动）。
- `_start_ending`（捕获 result + 双方塔血快照）/`_add_result_buttons`（延迟建按钮 + tween 淡入）取代 `_show_result`。

**修改（`view/run_scene.gd`，零逻辑改）**
- **奖励揭示**：`_build_reward` 的标题/候选卡/SKIP 经 `_anim_pop`（从下方淡入 + `TRANS_BACK` 回弹归位）**逐张错峰**揭示。
- **选中 flourish**：`_on_pick` 选中的卡**放大 + 金色**(`create_tween`)再回中枢；`_picking` 守卫挡二次点击/SKIP；`_offer_nodes` 记 id→卡节点。
- **结算揭示**：`_build_summary` 的 RUN CLEARED/OVER 标题、战绩、解锁、按钮逐条 `_anim_pop` 错峰入场。
- 新增 `_anim_pop` 通用入场动画助手。

**范围边界**：仅 view，逻辑/config/单测零改。塔被摧毁的「爆破序列」沿用 6b（震屏 + 大涟漪），本步不再加碎块粒子（留 V3-7 美术）。所有演出为白膜程序化（字号/多边形/tween），V3-7 贴精灵不改时序。

**踩坑与修复**
- 无新坑。`battle_scene` 演出走 `_draw`（与 6b/6c 同源、单 `_end_t` 计时）；`run_scene` 走 Control `create_tween`（节点 UI 友好）。Tween 绑定的节点被 `_clear` free 时 Godot 自动杀 tween，无悬挂。

**验收**
- `Godot_..._console.exe --headless --path . res://view/battle_scene.tscn|run_scene.tscn --quit-after 200` → 两场景零脚本/运行期错误（演出/奖励覆盖层 200 帧 smoke 内未触发，靠解析校验 + 真人验收）✅
- `... --script res://tests/test_runner.gd` → **172/172 全过**（仅改 view，逻辑零回归）✅
- **演出留真人实机验收**（清单见下）。

**V3-6d 真人实机验收清单（交用户）**：① 普通对局结束：屏幕**渐暗** → **YOU WIN/LOSE/DRAW** 标题**弹入放大**(sting) → 你的**王冠逐个落下**(回弹) → **比分滚动**计数 → 稍后 **REMATCH/MENU**(或 run 模式 **CONTINUE**) 按钮**淡入**；演出期间**点不动手牌**；② ROGUELITE 胜后：奖励覆盖层 **DRAFT A CARD / CHOOSE A RELIC** 标题 + 候选**逐张错峰弹入**，**选中**的卡**放大金光**再回中枢（卡组/relic 已加）；③ run 通关/败北：**RUN CLEARED / RUN OVER** + 战绩 + 解锁**逐条错峰入场**，BACK TO MENU 可用；④ 全程无报错、帧率正常、REMATCH/CONTINUE/MENU/NEW RUN 流转仍对。回报「通过/哪条不对」。

---

## V3-7 — 精灵美术（准备 + 卡牌改名 + 多语言；进行中）

> 方向见 PLAN_V3 §3 + 决策 42/43。执行顺序：素材准备 → ① 卡牌改名 → ② 多语言 → ③ 美术垂直切片（未开工）。

### V3-7 准备 — 美术素材入库 + ART_ASSETS（已提交 `6579207`）
题材敲定黑暗中世纪幻想、主风格 Pixel Grit（决策 42）。`testAssets/` 原始库 + `assets/` 选用 94 文件 + `docs/ART_ASSETS.md` 美术圣经雏形。

### V3-7 ① — 卡牌黑暗中世纪化改名（仅 config）  （待提交）
`config/cards.json` 13 张 `name` 改中文定稿（id 不变、英文名入 i18n）；knight/archers/goblins 原名保留。Excel `--from-json` 同步、`--check` ok。**验收**：单测 172/172；config check ok ✅。映射见 [docs/ART_ASSETS.md §6](docs/ART_ASSETS.md)。

### V3-7 ② — 多语言 i18n + 像素中文字体 + 设置切换（仅 view/config）  （待提交）
**前置决策**：43。
**新增/修改**
- `config/i18n.json`（中英 ~80 key：UI/卡名/relic 名+描述/难度/数值模板）。
- `view/i18n.gd`（autoload `I18n`）：运行时读 i18n.json 建 en/zh `Translation` 注入 `TranslationServer`；locale 存 `user://settings.cfg`、默认中文；`set_language`/`current_locale`。`project.godot` 注册 autoload。
- `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf`（OFL，自动禁 subpixel）+ `OFL.txt`；`project.godot` [gui]theme/custom_font 设为它；`battle_scene._font` 改 load 该 ttf（draw_string 中文）。
- 6 场景接入 `tr()`：main_menu/level_select/deck_builder/battle_scene/run_scene（卡名/relic/难度/数值/HUD/结算/奖励全中英）。
- `view/settings.gd`+`.tscn`（新）：中/英切换（即时 reload 本页 + 存盘）；main_menu 加「设置」入口。
**范围边界**：仅 view + config，逻辑/单测零改（i18n 表现层、无单测）。
**踩坑**：`gh` 不走代理 → 用 `curl --proxy` 取 GitHub release；Windows python 不认 git-bash `/tmp` → 下载放工程相对路径；CSV 编辑器导入 headless 不友好 → 改 JSON + autoload 运行时构建。
**验收**
- 6 场景 headless smoke 零脚本错误（tr key / `%` 格式化全对）；单测 **172/172**。✅
- **中文像素字体显示真人认可**（主菜单/组卡截图，2026-06-16）✅；中英切换 + 其余场景全中文细节留真人继续验收。
- 既有良性 warning（`size` 遮蔽基类 / int-as-enum / 整除）非本步引入、不影响运行，暂忽略（将来统一清一轮）。
**下一步**：③ 美术垂直切片（已完成，见下）。

### V3-7 ③ — 美术垂直切片（仅 view + 1 渲染设置）  （待提交）
**前置决策**：用户 2026-06-20 选定 **架构 A = immediate `_draw` + `draw_texture`**（契合 6a–6d 的 `_draw` 体系，单位动态增减天然支持，逻辑零改）+ 切片范围 = 骑士 + building 塔 + 火爆炸 FX。
**修改（仅 `view/battle_scene.gd` + `project.godot`）**
- 顶部 `preload` 三纹理（Heavy_Knight Non-Combat / building1 / Fire_Explosion）+ 帧常量；新增 `_draw_sheet`（从 sheet 取 (col,row) 帧 `draw_texture_rect_region`，`modulate` 染色）。
- `_draw_units`：`knight_body` 用精灵帧（32×32、walk 行循环 6fps），`modulate=fill`（染队伍色区分敌我 + 复用受击闪白）；其余兵仍白膜圆。
- `_draw_towers`：塔主体改 `draw_texture_rect(building1, modulate=fill)`，保留血条/王冠标记/摧毁。
- `_draw_fx`（落地涟漪）：改 `Fire_Explosion` 28×28×12 序列帧。
- `project.godot`：`rendering/textures/canvas_textures/default_texture_filter=0`（最近邻，像素锐利，像素美术前提）。
**范围边界**：仅 view + 1 渲染设置，逻辑/config/单测零改。切片验证**管线**（精灵导入→帧动画→替白膜→逻辑零改）；精确动画状态/朝向（现取 sheet 一行循环、不分上下）/全单位·塔·卡面·地形换皮留 **V3-7b 量产**。
**验收**
- battle_scene headless smoke 零脚本错误（preload 纹理 + 塔贴图绘制 OK）；单测 **172/172**。✅
- **真人 6/6 验收通过（2026-06-20）**：骑士精灵(染色/闪白) + building 塔贴图 + 火爆炸序列 + 像素锐利 + 其余白膜 + 流程不变，全通过。✅
**下一步**：**V3-7b 量产** —— 按此管线给全部单位（含朝向/idle/walk/attack/death 状态）、塔（王/公主区分）、卡面、地形 tile、FX 批量换精灵 + 美术圣经定稿（决策 42 升级）。
