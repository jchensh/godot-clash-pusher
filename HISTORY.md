# HISTORY.md — 开发历史与进度记录

> **本文件用途**：给任何接手的人/agent（新开对话也一样）一个**准确、自足**的项目进度与历史。
> 阅读顺序建议：先 [PLAN_GRAND.md](PLAN_GRAND.md)（全项目 roadmap）与 [PLAN_V2.md](PLAN_V2.md)（当前阶段权威规划）→ [CLAUDE.md](CLAUDE.md)（操作手册）→ 本文件（已发生了什么、为什么这么做、踩过什么坑）。[PLAN_V1.md](PLAN_V1.md) 为已完成的 V1 规格。
> **维护约定**：每完成一个步骤（或做出重要决策/踩坑修复），都要在此**追加记录**，再随该步 commit。
> **改名说明（2026-06-07）**：原 `PLAN.md` 已改名为 `PLAN_V1.md`（V1 完成）。本文档中历史出现的「PLAN.md / PLAN §X」一律指 `PLAN_V1`。

---

## 快速上手（新 agent 必看）

- 引擎：**Godot 4.6.3 stable（标准 GDScript 构建）**，已通过 `~\bin\godot.cmd` shim 加入用户 PATH。新终端里 `godot` 直接可用；同一会话内若 PATH 未刷新，先 `$env:PATH = "$env:USERPROFILE\bin;$env:PATH"`。
- 跑全部单元测试（逻辑层验收的主手段）：
  ```powershell
  godot --headless --path F:\godotProject --script res://tests/test_runner.gd
  ```
  退出码 0 = 全过；非 0 = 有失败（末尾打印失败明细）。
- 验证工程能打开 / 重新导入（生成 .uid、刷新资源）：
  ```powershell
  godot --headless --editor --path F:\godotProject --quit
  ```
  > 注意：空工程阶段**不能**用 `--headless --quit`（会因"无主场景"报错），要用上面的 `--editor --quit`。
- 测试框架：**自写轻量 runner**（零依赖）。新测试文件放 `tests/test_*.gd`，`extends "res://tests/test_case.gd"`，方法名以 `test_` 开头。`tests/test_runner.gd` 自动发现并执行，汇总 + exit 0/1。

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
| V2-5a | 主菜单 + 结算面板（场景闭环骨架，仅显示层） | ✅ 完成（视觉验收通过） | 本次提交 |

> **阶段进度（2026-06-10）**：V1 已收官（Step 0–8）。**V2 进行中**，顺序 **A（3-lane）→ D（换皮）→ B（AI 深度）→ C（内容/数值）**，权威规划见 [PLAN_V2.md](PLAN_V2.md)。**A 模块（3-lane）已完成**（V2-1+V2-2）。**D 模块进行中**：V2-3 程序化换皮 + V2-4 动画与特效（攻击/受击/死亡/投射物/AOE爆点/塔摧毁，均仅 view 层、逻辑零改动）已完成并通过视觉验收。配置体系已迁移为 JSON 运行时配置 + `GameConfig.xlsx` 人类策划工作簿镜像；agent 默认改 JSON，确认后同步 Excel。**V2-5（D 模块收尾）进行中**：按一步一确认拆 3 小步（5a 场景闭环骨架 / 5b 战斗内 UI 美化 / 5c 音频，**音频缓做、UI 保持全英文**，决策日志 32）；**V2-5a 主菜单 + 结算面板 + 菜单→对局→结算→菜单 闭环已完成并通过视觉验收**，下一步 V2-5b。**V2 不做**空中/地面克制。全局 roadmap 见 [PLAN_GRAND.md](PLAN_GRAND.md)。

**测试现状**：111 个测试全部通过（config_loader 8 + elixir 10 + sim_clock 6 + deck 9 + unit 6 + lane 8 + tower 6 + battle 10 + battle_v2 12 + skill_system 11 + **player 10** + match 6 + ai_controller 6 + smoke 3）。配置源表存在性已纳入 `test_config_loader.gd`；V2-3/V2-4/V2-5a 为纯 view/场景层（换皮/动画特效/主菜单+结算闭环），逻辑零改动。

**分支 / 远端**：开发在 **`develop`** 分支；`main` 为稳定线。远端 `origin` = https://github.com/jchensh/godot-clash-pusher （Public）。约定：用户说"提交"时才 commit + push。

**Godot AI MCP（表现层辅助工具）**：项目已导入 `godot-ai` 插件（`addons/godot_ai/`），来源 https://github.com/hi-godot/godot-ai ，当前版本 `2.6.1`。Godot 编辑器 GUI 打开并启用插件时，会启动 MCP server `http://127.0.0.1:8000/mcp`（WebSocket `127.0.0.1:9500`）供 Codex / Claude Code 连接。插件目录与 `project.godot` 启用配置随项目进 git；Codex/Claude 的用户级 MCP 配置在项目外，不进 git。

---

## Step 4 前置语义（已确认，可开做）

> **给接手的人 / agent**：`Unit` + `Lane`（Step 4）涉及战斗结算，依赖下面两个语义。PLAN §9 未定。
> 用户已于 2026-06-06 确认，可按下列结论开始 Step 4。

1. **`attack_range` 的单位**：lane 进度 `0~1` 的比例；例如 `0.5` 表示半条 lane。
2. **`target_type` 的含义**：单位自身的地面 / 空中类型（即该单位属于 `ground` 还是 `air`），用于后续命中/筛选判断；不要把它解释为“该单位能攻击什么”。如后续需要表达攻击能力，再另加字段（如 `attack_targets`）并走配置。

> 次要（可在 Step 4 过程中细化，不卡开工）：单位攻击目标规则（同 lane 最前敌人 / 优先塔）、`direct_damage` 的 `target` 枚举、多积木结算顺序。

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

29. **Godot AI MCP = 表现层辅助工具，不替代测试/真人验收**：选用 `hi-godot/godot-ai`（https://github.com/hi-godot/godot-ai，MIT，导入版本 `2.6.1`）。它通过 Godot 编辑器插件启动本地 MCP server（HTTP `127.0.0.1:8000/mcp`、WebSocket `127.0.0.1:9500`），供 Codex / Claude Code 读取场景树、截图、日志、编辑器状态并辅助 UI/动画/特效排查。逻辑正确性仍以 headless test runner 为准；写操作仍遵守一步一确认；主观视觉/手感验收仍交用户确认。

> 30 为 **V2-4（动画与特效）事件源选型**，用户 2026-06-09 确认。

30. **V2-4 动画事件源 = 路线 A（纯显示层、零改逻辑）**：受击/死亡/塔摧毁靠显示层逐帧 diff 血量还原；攻击配对/投射物来源靠显示层复刻 `Lane` 的目标选择（范围内最近敌方单位 + 尽头敌塔）还原；玩家法术按点击点/直伤目标精确出特效，AI 法术（显示层看不到其经 `opponent_controller.tick` 的出牌）按「同帧某 lane ≥2 个玩家单位聚集掉血」推断爆点（近似，带节流 + 聚集窗）。代价：攻击/投射物配对为启发式、AI 法术落点为近似；收益：逻辑层一行不改、不扩大范围、无新单测、契合架构铁律「显示层每帧读逻辑状态画出来」。备选路线 B（逻辑层每 tick 发可测事件缓冲，显示层 drain 精确驱动）记录在案，若将来精确度不足再升级。

> 31 为 **配置体系迁移到 Excel 源表**，用户 2026-06-09 确认。

31. **配置工作流 = JSON / Excel 双入口，agent 默认 JSON 优先**：Godot 运行时仍读 `config/cards.json`、`config/units.json`、`config/levels.json`，避免引入 Excel 运行时解析依赖、也不改战斗逻辑。Codex / Claude 修改配置时优先直接改 JSON（更省上下文、路径更短、贴近运行时），确认没问题后运行 `tools/build_config.py --from-json` 把当前 JSON 覆写同步到 `config/GameConfig.xlsx`。人类策划仍可直接改 Excel，再运行 `tools/build_config.py` 生成 JSON。提交前统一跑 `tools/build_config.py --check` 与 Godot 单测。若 Excel 可能有用户尚未同步到 JSON 的手工改动，agent 不得直接 `--from-json` 覆盖，必须先询问。

> 32 为 **V2-5（D 模块收尾）开工前提**，用户 2026-06-10 确认。

32. **V2-5 拆 3 小步 + 音频缓做 + UI 保持全英文**：V2-5 原打包「UI 美化 + 音频 + 主菜单 + 结算闭环」，按「一步一确认」拆为 **V2-5a 场景闭环骨架（主菜单 + 结算面板 + 菜单→对局→结算→菜单）→ V2-5b 战斗内 UI 美化 → V2-5c 音频**，每小步停下做真人视觉验收。**音频本阶段缓做**（既不引入外部 CC0 音效素材、也不先做程序化合成），留到 a/b 之后单独处理；**UI 保持全英文**（延续 7b 决定，不导入 CJK 字体、零字体依赖）。理由同 V2-3/V2-4 零外部素材路线：先把场景闭环与可玩骨架立起来再逐步美化，避免一步铺太大、便于分段验收。

---

## 与原计划（PLAN_V1.md）的出入

- **新增 `SimClock` 模块**：PLAN §4 模块表未列时钟模块；因 §8 要求"第 2 步定下固定 tick 机制"而新增。Battle（Step 5）将用它驱动逻辑步进。
- **配置规模扩充**：PLAN §5 仅给 3 卡/1 单位示例；实际做了 8 卡/5 单位/1 关卡（Step 3 抽牌需要完整牌组）。数值均为可调占位。
- **ConfigLoader 不建 typed 类**：PLAN 说"转为游戏内数据"，按最小化解读为字典。
- **额外的交叉引用校验**：超出"读入并打印"的验收，属主动加固。
- **Step 4 补充单位字段校验**：`ConfigLoader` 现在校验 `attack_speed` / `attack_range` / `target_type` 等 Step 4 必用字段，其中 `attack_range` 必须在 `0.0~1.0`。
- **验证命令调整**：PLAN 设想 `--headless --quit`，实际须用 `--headless --editor --quit`（空工程无主场景）。
- **godot.cmd shim 实现返工**：见下方 Step 0 踩坑。

> 以上出入均未超出 V1 锁定范围，仅为实现层面的合理细化/加固。

---

## 待你（用户）决策 / 未决事项

**已确认（2026-05-30）**
- ✅ **逻辑 tick 频率 = 10Hz**：保持。
- ✅ **起始圣水 = 0**（空槽开局）：先按此做；将来如需半槽起手再加 `levels.json.elixir_start` 字段。

**已确认（2026-06-06）**
- ✅ **`attack_range` 语义**：lane 进度 `0~1` 的比例。
- ✅ **`target_type` 语义**：单位自身类型（ground/air），不是攻击能力。

**已确认（2026-06-07）**
- ✅ **三塔制 + 胜负规则**：见决策日志 12–16（王塔归零判负、超时比塔血、单 lane 接王塔）。
- ✅ **Step 6 技能结算口径**：见决策日志 17–21（多积木数组顺序、`direct_damage.target=first_enemy_in_lane`、`aoe_damage` 一维圆心/半径、伤害只打敌方单位、出牌指令 `(card_id, owner_id, lane_index, target_progress)`）。原 PLAN §9 遗留项至此全部定稿。

**已确认（2026-06-08）**
- ✅ **V2-1 拓扑/转火/部署**：见决策日志 24–25（侧路公主毁后转打王塔；部署仅己方半场/任意 lane，强制校验留 V2-2）。

**仍待定（V2-2 开工前定）**
- [ ] **部署半场校验落点**：在 `Player.try_play_card` 拒绝越界出兵，还是在 `SkillSystem._spawn_unit` 钳制到己方半场？（仅约束 spawn，伤害法术 direct/aoe 不受限）
- [ ] **跨 lane 河道规则**：单位是否绑定生成 lane 不可换道（决策 25 已定「任意 lane 可选」，但生成后是否锁 lane 待 V2-2 确认）。

---

## 逐步历史

### Step 0 — 项目脚手架 + git + 工具链  （commit `77909c9`）
**新增**
- `project.godot`：Godot 4.6，竖屏 720×1280、`portrait`、GL Compatibility 渲染（利于安卓）。
- 目录：`logic/ view/ ai/ config/ tests/`（空目录用 `.gitkeep` 占位）。
- `icon.svg`：占位几何图标。
- `tests/test_runner.gd`（自写 headless runner）+ `tests/test_case.gd`（断言基类）+ `tests/test_smoke.gd`（冒烟）。
- `.gitignore`（忽略 `.godot/`、`/android/`、导出产物）、`.gitattributes`（统一 LF + 二进制标记）。
- `CLAUDE.md`（操作手册）。
- `.vscode/`：`extensions.json`（推荐 `geequlim.godot-tools`）、`settings.json`（LSP + GDScript 用 Tab）、`launch.json`（F5 调试）。
- `C:\Users\user\bin\godot.cmd` shim（项目外），并把 `~\bin` 追加到用户 PATH。

**决策**
- VS Code 完整 godot-tools 集成；Godot 加入 PATH（均为用户选择）。

**踩坑与修复**
1. **godot.cmd 被 cmd 解析失败**：首版用 `Write` 写出，是 **LF 换行 + UTF-8 中文注释**，`cmd.exe` 需要 CRLF 且对非 ASCII 注释敏感 → 报一堆 `'xxx' is not recognized`。
   修复：改用 PowerShell 以 **ASCII + CRLF** 重写，注释改英文。
2. **shim 找不到 exe**：原 `dir /s` 模式把通配符放在**中间目录**（`...\GodotEngine.GodotEngine_*\Godot_v*_console.exe`），`/s` 要求起始目录是**字面路径**，匹配失败。
   修复：改为字面 base + `/s` 递归文件名：`...\Packages\Godot_v*_console.exe`。
3. **`--headless --quit` 验证失败**：报"no main scene defined"。空工程没有主场景。
   修复：用 `--headless --editor --quit` 做导入式验证。

**验收**：`godot --version`→4.6.3.stable ✅；`--editor --quit` 导入 exit 0 ✅；测试 3/3 通过 ✅；git 仓库初始化于 `main` ✅。

---

### Step 1 — ConfigLoader + 三张 JSON 配置  （commit `a632dcd`）
**新增**
- `config/cards.json`：8 张卡（knight/archers/giant/goblins/minions/fireball/arrows/zap），仅用 3 种技能积木 `spawn_unit` / `aoe_damage` / `direct_damage`。
- `config/units.json`：5 个单位（字段按 PLAN §5.2：hp/damage/attack_speed/move_speed/attack_range/target_type）。
- `config/levels.json`：`level_01`（圣水回速/上限、对局时长、双方 8 张牌组、塔血量）。
- `logic/config_loader.gd`：`ConfigLoader`，`load_all()` 读三张 JSON → 字典；结构校验 + **交叉引用校验**；错误进 `errors`，全过返回 true。
- `tests/test_config_loader.gd`：6 断言 + 1 打印验证。

**决策**
- 配置存字典、不建 typed 类。
- 扩到 8 卡/5 单位以备 Step 3。
- `attack_range`/`target_type` 等语义暂不解释（PLAN §9）。

**踩坑**：无（一次通过）。注意 Godot 4 JSON 数字可能解析为 float，但 GDScript `3.0 == 3` 为真，断言不受影响。

**验收**：测试 7/7（含打印 `cards=8, units=5, levels=1`）✅。

---

### Step 2 — Elixir 圣水系统 + SimClock 固定 tick  （本次提交）
**新增**
- `logic/sim_clock.gd`：`SimClock` 固定时间步长累加器。`TICK_DELTA=0.1s`（10Hz）、`advance(real_dt)` 把可变帧 dt 转成离散 tick 数；含 `MAX_TICKS_PER_ADVANCE=100` 追帧风暴保护、`get_interpolation_fraction()` 供显示插值。
- `logic/elixir.gd`：`Elixir` 圣水系统。按 `regen_rate`（圣水/秒）线性回涨并 `minf` 封顶；`spend()` 扣除（不足/负数拒绝且不改状态）；`get_amount()`（float，平滑显示）/ `get_int()`（floor，判可出牌）/ `is_full()`。
- `tests/test_elixir.gd`：10 测试。
- `tests/test_sim_clock.gd`：6 测试，含**帧率无关性**集成测试（同 1.0s、10帧 vs 40帧 → 同样 10 tick、同样 1.0 圣水）。

**修改**
- `CLAUDE.md`：更新"当前进度"指针。

**决策**
- 逻辑 tick = 10Hz（PLAN §8 要求第 2 步定下）。
- `elixir_regen_rate` 解释为"每秒回涨量"。
- 起始圣水默认 0（构造可传 `start_`）。

**踩坑与修复**
- **固定步长累加器的浮点漂移**：`advance(0.35)` 后余量为 `0.04999…`（二进制浮点），再 `+0.05` 落在 `0.0999…` 略小于 `0.1` → 偶发**漏 tick**（长对局会抖动）。
  修复：阈值加 `_EPSILON=1e-9` 容差（`>= TICK_DELTA - _EPSILON`），固定步长循环的标准做法。

**验收**：测试 26/26 全过（含帧率无关性证明）✅。

---

### Step 3 — Deck 循环卡组  （本次提交）
**新增**
- `logic/deck.gd`：`Deck` 循环卡组（玩家与 AI 共用）。一副 8 张：4 张在手（格位固定）、4 张在队列。`play(hand_index)` 打出某格 → 队首补入该格 → 打出的牌回队尾，返回打出的 card id。另有 `get_hand()`（返回副本）、`peek_next()`（队首预览）、`total()`。非法下标/空队列返回 null 不改状态。
- `tests/test_deck.gd`：9 测试，含「集合不变量」（任意多次出牌无丢失/重复）、精确状态追踪、与 ConfigLoader 的真实牌组集成测试。

**决策**
- **手牌格位置固定**（打出哪格补哪格），对齐皇室战争视觉/手感（Model 1）。
- **V1 不洗牌**：确定性循环，利于测试；如需开局随机化再加可选 seeded shuffle（记为后续可加项）。
- **一副 = 8 张总数**（4 手 + 4 队列），对齐 `levels.json` 的 8 张 `player_deck` 与皇室战争规则；澄清了 PLAN「8 库 + 4 手」措辞的歧义。

**踩坑**：无（一次通过）。

**验收**：测试 35/35 全过（+9 deck）✅。

---

### Step 4 — Unit + Lane 推进与碰撞  （本次提交）
**新增**
- `logic/unit.gd` + `.uid`：单位运行时状态。包含 `unit_id`、`owner_id`、`lane_index`、`progress`、血量、伤害、攻击间隔、移动速度、攻击范围、单位自身类型；支持扣血、死亡判断、攻击冷却、方向判断。
- `logic/lane.gd` + `.uid`：单 lane 纯逻辑推进与碰撞/攻击结算。每 tick 推进冷却、判断范围内最近敌人、停下攻击、未接敌则按 owner 方向推进，并在结算后移除死亡单位。
- `tests/test_unit.gd` + `.uid`：6 个测试，覆盖配置初始化、进度钳制、owner 推进方向、扣血死亡、攻击冷却、真实配置 unit。
- `tests/test_lane.gd` + `.uid`：8 个测试，覆盖加入 lane、双方方向推进、相遇互伤、攻击冷却、死亡移除、接近后战斗、最近目标选择、真实配置 lane 结算。

**修改**
- `config/units.json`：按已确认语义把所有 `attack_range` 调整为 `0.0~1.0` 的 lane 比例（例如骑士/巨人近战 `0.05`，弓箭手 `0.25`）。
- `logic/config_loader.gd`：单位配置校验补齐 Step 4 必用字段，并校验 `attack_range` 范围与 `target_type` 枚举。
- `tests/test_runner.gd`：测试脚本加载失败时计入失败，避免坏测试文件被静默跳过。
- `AGENTS.md`：同步当前 worktree、开发分支、Step 4/5 指针与 Step 4 语义。

**决策**
- 逻辑坐标采用全局 lane 进度：`OWNER_PLAYER` 从 `0` 向 `1` 推进，`OWNER_OPPONENT` 从 `1` 向 `0` 推进。
- `move_speed` 解释为 lane 进度/秒；`attack_range` 解释为 lane 进度比例；`attack_speed` 解释为攻击间隔（秒/次）。
- Lane 中攻击目标为自身攻击范围内最近敌方单位；双方同 tick 中已排定的攻击统一结算，因此相遇时可以互相掉血。

**踩坑与修复**
1. **GDScript 跨脚本类型标注/推断不稳定**：新脚本尚未注册 `.uid` 时，`Unit` 类型标注和 `:=` 推断会导致测试脚本解析失败。
   修复：`Lane` 内部保持动态参数风格，关键局部变量显式转 `int/float`；随后用 `--headless --editor --quit` 让 Godot 注册 `Unit` / `Lane` 全局类并生成 `.uid`。
2. **测试 runner 漏报坏测试文件**：脚本加载失败原先只 `push_error`，未计入失败。
   修复：加载失败时增加总数和失败数，并记录失败信息。
3. **攻击范围边界浮点误差**：距离理论上等于 `attack_range` 时可能因二进制浮点略大，导致一侧未出手。
   修复：Lane 范围判断加入 `_EPSILON=1e-6` 容差。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 49/49 全过 ✅
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`Unit` / `Lane` 注册成功 ✅

---

### Step 5 — Tower + Battle 胜负判定  （本次提交）
**前置语义（用户 2026-06-07 确认）**
- 三塔制：每方 1 王塔 + 2 公主塔。
- 王塔归零 → 该方立即负；公主塔毁不结束对局，只计入剩余塔血。
- 超时（match_duration）→ 比双方剩余塔血总和，多者胜、相等判平。
- V1 单 lane 两端接双方王塔，单位推到底直接削王塔。

**新增**
- `logic/tower.gd` + `.uid`：`Tower` 纯血量容器。`kind`（king/princess）、`owner_id`、`max_hp/hp`；`is_king()` / `is_alive()` / `is_destroyed()` / `take_damage()`（钳零、非正伤害与已毁后 no-op）。不含像素/位置。
- `logic/battle.gd` + `.uid`：`Battle` 战斗总控。持双方塔列表 + 王塔引用 + lane 列表 + `match_duration`/`elapsed`/`result`。`step(dt)` 先结算各 lane 再计时与判负（对局结束后 no-op）；`build_v1_single_lane(level)` 按配置搭「双方各 3 塔 + 单 lane 接双王塔」并返回 lane；`total_tower_hp()` / `remaining_time()` / `is_over()`。胜负枚举 `RESULT_ONGOING/PLAYER_WIN/OPPONENT_WIN/DRAW`。跨脚本一律 `preload` 加载，不依赖 class_name 全局注册。
- `tests/test_tower.gd` + `.uid`：6 测试（建塔、公主非王、扣血、钳零摧毁、非正伤害 no-op、已毁后 no-op）。
- `tests/test_battle.gd` + `.uid`：10 测试（建三塔、削敌王塔、王塔归零判玩家胜、对手镜像胜、公主毁不结束、超时比塔血胜、超时平、结束后不再推进、停在塔攻击范围边界不穿塔、真实配置 level_01+骑士集成）。

**修改**
- `logic/lane.gd`：**加性扩展**。新增可空两端塔引用 `tower_at_start`（守 progress 0）/ `tower_at_end`（守 progress 1）+ `set_towers()`；`tick()` 在无敌方单位可打时改打尽头敌塔；`_move_unit()` 增加「停在敌塔攻击范围边界」夹取；新增 `_find_enemy_tower_in_range()` / `_enemy_tower_for()`（按方向取尽头敌塔且需异阵营）/ `_tower_position()`。不接塔时全部 null → 与 Step 4 行为完全一致。
- `HISTORY.md` / `CLAUDE.md` / `AGENTS.md`：进度指针与决策同步。

**决策**：见上方决策日志 12–16。

**踩坑与修复**
- 无（一次通过）。沿用 Step 4 经验提前规避：① 跨脚本统一 `preload`，不靠 class_name 全局名，先 `--editor --quit` 注册 `Tower`/`Battle` 并生成 `.uid`；② 攻击范围边界判断复用 `_EPSILON` 容差；③ Lane 改动保持加性，旧 8 个 lane 测试零回归。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`Tower` / `Battle` 注册成功 ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 65/65 全过（+6 tower +10 battle，旧 49 零回归）✅

---

### Step 6 — SkillSystem 三积木  （本次提交）
**前置语义（用户 2026-06-07 确认）**：见决策日志 17–21（多积木数组顺序、`direct_damage.target=first_enemy_in_lane`、`aoe_damage` 一维圆心/半径、伤害只打敌方单位、出牌指令 `(card_id, owner_id, lane_index, target_progress)`）。

**新增**
- `logic/skill_system.gd` + `.uid`：`SkillSystem` 解析卡牌 `skills` 数组并执行。`play_card(card_id, owner_id, lane_index, target_progress)` 按数组顺序逐个结算（卡不存在返回 false）；`_spawn_unit`（在出牌位置生成 `count` 个该单位，owner=出牌方）、`_direct_damage`（命中 `_first_enemy_in_lane` = 最逼近出牌方塔的敌方单位，无则空放）、`_aoe_damage`（沿 lane 命中 `|progress-center|<=radius` 的敌方单位）。伤害类只打敌方、不打塔；**不校验/扣圣水**。跨脚本一律 `preload`。
- `tests/test_skill_system.gd` + `.uid`：11 测试（生成数量/owner/位置、未知单位 no-op、直伤选玩家/对手各自最前敌、无敌空放、AOE 半径边界命中、AOE 不误伤己方、多积木全执行、未知卡 false、真实卡入对局并随 tick 推进）。

**修改**
- `logic/battle.gd`：新增 `get_lane(lane_index)`（按 `lane_index` 查 lane），供 SkillSystem 定位 lane。加性，无回归。
- `HISTORY.md` / `CLAUDE.md` / `AGENTS.md`：进度指针与决策同步。

**决策**：见决策日志 17–21。补充实现细节：`SkillSystem` 依赖注入 `(ConfigLoader, Battle)`，自身不持有圣水/卡组逻辑；AOE/直伤通过 `lane.get_units()` 读单位、`take_damage` 改血，死亡单位由后续 `lane.tick` 统一移除（直伤目标选择已过滤 `is_alive`）。

**踩坑与修复**
- 无（一次通过）。AOE 边界沿用 `_EPSILON` 容差；多积木/自定义半径测试用「向已加载的 `loader.cards` 注入内存卡」实现，不污染 `config/*.json`。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`SkillSystem` 注册成功 ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 76/76 全过（+11 skill_system，旧 65 零回归）✅

---

### Step 7 — 显示层 MVP（白膜 + UI）
> 第一步带画面。按「逻辑/显示分离」拆成两段：**7a** 先补可测的逻辑编排层，**7b** 再搭 Godot 画面并真跑验证。
> 用户 2026-06-07 确认的 MVP 口径：①对手被动（只有静止三塔、不出牌，AI 留到 Step 8）②单 lane ③出牌两段式（先点卡再点落点，落点限己方半场 progress 0~0.5）④竖屏白膜：己方在下、敌方在上，近战方块/远程圆/建筑三角，蓝=己方红=对手。

#### 7a — 对局编排层 Player + Match（本次提交）
**新增**
- `logic/player.gd` + `.uid`：`Player` 一方对局状态（owner + 注入 Elixir/Deck/ConfigLoader/SkillSystem）。`try_play_card(hand_index, lane_index, target_progress)` 串起「圣水门槛 → 扣圣水 → 循环卡组 → 触发技能」（不足/下标非法则 false 且不改状态）；`can_play()` 供 UI 置灰；`regen(dt)`、`card_cost()`。**玩家与 AI 共用此出牌入口**（对称性落点）。
- `logic/match.gd` + `.uid`：`Match` 一局总驱动。组合 Battle + 两个对称 Player + SkillSystem + SimClock；`setup(level_id)` 按配置搭好（双方各 3 塔 + 单 lane、起始圣水 0）；`update(real_dt)` 把可变帧 dt 经 SimClock 折成固定 10Hz tick，逐 tick 双方圣水回涨 + `battle.step`，对局结束即停；`is_over()`/`get_result()`/`get_interpolation_fraction()`（供显示插值）。
- `tests/test_player.gd` + `.uid`：6 测试（圣水不足拒绝、出牌扣费+生成+落点、卡组循环、can_play 反映圣水、回涨、非法下标 no-op）。
- `tests/test_match.gd` + `.uid`：6 测试（搭双方 Player+battle、起始圣水 0、双方对称回涨、**帧率无关性**一大帧 vs 多小帧一致、update 驱动战斗使单位前进、结束后 update 不再推进）。

**决策**：`Battle` 保持只管塔/lane/胜负不膨胀；圣水门槛与对局循环放新的 `Player`/`Match`（PLAN §4 列了 Player；Match 是 §3 数据流「逻辑层」侧的总驱动）。SkillSystem 仍不碰圣水。起始圣水 0（决策日志 7）。

**踩坑与修复**
1. **`match.gd` 的 `var n := clock.advance(dt)` 解析失败**：`clock` 是无类型 var，跨脚本方法返回类型推断不出 → `Cannot infer the type of "n"`（同 Step 4 的 `:=` 不稳定）。修复：显式 `var n: int = ...`。
2. **test_runner 汇总会「假绿」**：当 `match.gd` 解析失败时，`test_match.gd` 预载到的是坏 GDScript，`MatchScript.new()` 返回 null、后续 `m.player` 等抛**运行时** SCRIPT ERROR，但这些错误不会写入 `_failures`，runner 仍把用例计为 PASS、汇总显示 88/88。**教训：逻辑层验收不能只看汇总，必须 grep stderr 的 `SCRIPT ERROR`/`Parse Error`/`Compilation failed`**。已据此确认修复后 0 错误行。（**已跟进加固**，见下方「测试基建加固 — test_runner 防『假绿』」。）

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → 无解析错误，`Player`/`Match` 注册并生成 `.uid` ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → **SCRIPT ERROR 行数=0**，88/88 全过（+6 player +6 match，旧 76 零回归）✅

#### 7b — Godot 显示层（白膜 + UI）（本次提交）
**新增**
- `view/battle_scene.gd` + `.uid` + `view/battle_scene.tscn`：主场景。`_ready` 建 `Match` 并程序化搭白膜；`_process(delta)` → `match.update(delta)` 后每帧只读逻辑状态作画。三塔=三角（红=对手在上 / 蓝=己方在下）+ 绿血条；单位近战=方块、远程=圆（按 `attack_range` 粗分），按 `progress` 映射屏幕 y、视图侧 `lerp` 平滑；圣水条 + 4 手牌按钮（显示卡 id+费用、`can_play` 置灰）；胜负横幅读 `battle.result`。两段式出牌：点卡选中 → 点己方半场（progress 0~0.5）→ `player.try_play_card`。坐标 `0~1`→像素映射只活在本层。
- `project.godot`：设 `run/main_scene=res://view/battle_scene.tscn`。

**决策 / 范围**
- 对手被动（不出牌，AI 留 Step 8）、单 lane、落点限己方半场——均按 2026-06-07 确认口径。
- 视图侧用「`lerp` 趋近目标」做平滑（够顺够简），未用 SimClock 子 tick 严格插值；`get_interpolation_fraction()` 已就绪，需要再升级。
- **UI 全英文（决定，用户 2026-06-07 确认）**：手牌显示卡 id（knight/fireball…）而非中文 name，胜负横幅与数字也全英文，整个显示层不出现中文。故 V1 **不引入中文字体**——既规避 PLAN §7 的「中文豆腐块」问题，又零字体资源依赖。将来若要显示中文 name，再导入一个 CJK `.ttf` 即可（届时仅改显示层，逻辑不动）。

**踩坑与修复**
1. `battle_scene.gd` 的 `var r := match_obj.get_result()` 解析失败（同 `:=` 跨脚本推断坑）→ 显式 `var r: int = ...`。
2. 全屏背景/装饰 `ColorRect` 默认拦截鼠标 → 统一 `mouse_filter=IGNORE`，让点击穿透到 `_unhandled_input` 做部署；按钮保持默认 STOP。

**验收（真跑 Godot 渲染，非仅 headless）**
- `--headless --quit-after` 跑主场景：`battle_scene` 0 脚本错误 ✅
- 渲染截图（临时 runner 出牌后存 PNG，验后删）：白膜场地 / 三塔+血条 / 单位 / 圣水条 / 手牌——出两张牌后手牌正确轮换为 `minions·fireball·giant·goblins` 且 `giant[5]` 因圣水不足置灰，确认「部署→推进→卡组循环→圣水扣费」闭环 ✅
- 强制残血王塔 + 部署骑士截图：王塔归零变灰、空血条、显示 **YOU WIN** 横幅，确认「推塔→出胜负」✅
- 全量单元测试仍 88/88（显示层无单测，逻辑零回归）✅

#### 测试基建加固 — test_runner 防「假绿」（2026-06-07，跟进 7a 踩坑 #2）
> 把"逻辑脚本编译失败时 runner 仍全绿"的隐患，从"靠人工 grep stderr"升级为"runner 自动判失败、非 0 退出"。只改 `tests/test_runner.gd`，零新依赖（守住"逻辑层必测、零外部依赖"纪律）。

**根因**：坏逻辑脚本（解析/编译失败）被测试 `preload` 后，`Script.new()` 返回 null；其后对 null 的调用抛的是**运行时** SCRIPT ERROR——GDScript 无 try/catch、运行时错误只静默中止当前方法、进程 exit 仍 0——这些错误不写入 `_failures`。实测两种"假绿"表现：① **soft 编译错误**（如 `Cannot infer the type`）→ 预载方测试文件仍能加载、用例被计为 PASS；② **hard 语法错误** → 预载方测试文件解析失败、`load()` 后非 null 但无可见 `test_*` 方法 → 整文件被静默跳过、根本不计数。两者汇总都「全绿」。

**方案（调研 4 个候选后择优）**
- ✅ **启动预检 `res://logic`（核心修复）**：runner 跑测试前遍历 `logic/*.gd`，`load()` 后判 `can_instantiate()`；为 false（或 load 返回 null）即坏脚本 → 打印点名 + **整体非 0 退出、不放行**。`can_instantiate()==false` 恰好等价于"被 preload 后 `.new()` 返回 null"，与根因一一对应。
- ✅ **测试脚本 `can_instantiate()` 校验**：发现/加载测试文件时原仅判 `== null`，现加判 `can_instantiate()`，堵住表现 ② 的静默跳过。
- ✅ **每个测试 `script.new()` 加 null 守卫**：实例化失败即计失败，避免后续访问 `_failures` 再抛运行时错误被吞。
- ❌ **放弃"读引擎 SCRIPT ERROR 计数"**：Godot 4 无公开的运行时错误计数 API，GDScript 也无 try/catch；实测坏脚本 `.new()` 触发的 SCRIPT ERROR 静默中止、exit 仍 0 → 此路不通。
- 选 `can_instantiate()` 而非 `GDScript.reload()`：两者实测都能判坏（reload 坏脚本返回 `ERR_PARSE_ERROR=43`、好脚本 `OK=0`；can_instantiate 坏=false、好=true），但 reload 会重新编译有副作用，can_instantiate 只读首次 load 的编译结果、无副作用且语义更贴合。实测全部 11 个真实 logic 脚本两法均判「好」，零误报。

**自验（临时坏脚本 + 对应测试，验后即删）**
- 造 `logic/_selftest_broken.gd`（分别试 hard 语法错误、soft `var n := <untyped>.method()` 类型推断错误）+ `tests/test_selftest_broken.gd`（复刻 `test_match` 的"preload 后直接 `.new()` 用、不先 null 断言"）。
- **旧 runner**：EXIT=0、汇总 88/88（坏用例被静默跳过）→ 复现假绿。
- **新 runner**：预检捕获、点名 `_selftest_broken.gd`、EXIT=1（hard 与 soft 两种错误均被拦下，soft 即本节根因里的 `Cannot infer the type of "n"`）。
- 删除临时文件后跑全量回归。

**验收**：`HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → **EXIT=0、88/88 全过、SCRIPT ERROR 行数=0、预检零噪声**（健康时预检不打印）✅

#### 7 过程备忘 — 后台任务与本会话共用 worktree（2026-06-07，忠实记录）
> Step 7 期间用户启动了上面的「test_runner 加固」后台任务，它与本会话**共用同一个 git worktree**（并非独立 worktree）。如实记下，免得以后人/agent 困惑。
- **探针文件一度混入 7a 提交**：任务为自验加固效果，在 `logic/` 放了临时坏脚本 `_probe_broken.gd`、根目录放了 `zzz_probe.gd`。本会话提交 7a 时 `git add -A` 把这两个文件一并卷入；随即 `git rm --cached` + `git commit --amend` 把它们从 7a 提交剔除（文件留在磁盘供任务继续用，后由任务自行清理删除）。
- **改动混在同一工作区**：任务完成后，其 `tests/test_runner.gd` 加固与 HISTORY 记录，和本会话 7b 的 `view/*`、`project.godot`、HISTORY 改动同处一个未提交工作区，提交时按文件归属分开（runner 加固代码 → 独立提交；view/项目配置/HISTORY → 7b 提交）。
- **教训**：后台任务可能与主会话共用同一 worktree；`git add -A` 前务必先 `git status` 看清每个文件归属，分别提交，别把对方的活卷进自己的提交。

---

### Step 8 — AIController 规则 AI（本次提交）
**前置规则（用户 2026-06-07 确认）**：见决策日志 22（简单进攻型、阈值 6、最贵可用兵、法术不空放、自家塔前部署、出牌间隔 1s、确定性无随机）。

**新增**
- `ai/ai_controller.gd` + `.uid`：`AIController(match, config)`。`tick(dt)` 由 Match 固定 tick 循环驱动：冷却中跳过，否则 `_decide()`——圣水 `<6` 则等；否则在手牌里选「出得起且有用」的最贵牌（兵随时可出、法术仅在对面有敌方单位时可出，避免空放），兵部署 `progress 0.9`、法术落最前敌人处，经 `opponent.try_play_card` 出牌；出牌后进 `1.0s` 冷却。`_has_spawn()`/`_lead_enemy_progress()` 辅助。无随机。
- `tests/test_ai_controller.gd` + `.uid`：6 测试（圣水不足等待、出最贵可用兵+部署位+扣费、冷却拦截再出、无敌跳过法术改出兵、有敌则放法术削敌、**整局 AI 自驱跑到分胜负且削到玩家王塔**）。

**修改**
- `logic/match.gd`：加 `opponent_controller`（可空、鸭子类型）+ `set_opponent_controller()`；`update()` 的每 tick 循环里在 `opponent.regen` 后、`battle.step` 前调用 `opponent_controller.tick(TICK_DELTA)`。Match 不 import AIController（保持逻辑层不依赖 ai 层，控制器注入）。不注入则对手被动（= Step 7 行为）。
- `view/battle_scene.gd`：`_ready` 里 `set_opponent_controller(AIControllerScript.new(match_obj, loader))` 接入 AI——MVP 画面现在有会出牌的对手。

**决策**：见决策日志 22。补充：AI 驱动放在 Match 的固定 tick 内（保证与圣水/战斗同频、帧率无关），而非显示层每帧——否则 AI 决策会绑渲染帧率。控制器用注入而非 Match 直接 new，守住「逻辑层不依赖 AI 层」与「玩家 AI 对称」。

**踩坑与修复**：无（一次通过）。

**验收**：
- `HOME=/private/tmp/godot-home godot --headless --editor --path /Users/jeffchen/godot-develop --quit` → exit 0，`AIController` 注册 ✅
- `HOME=/private/tmp/godot-home godot --headless --path /Users/jeffchen/godot-develop --script res://tests/test_runner.gd` → 94/94 全过、SCRIPT ERROR 行=0（+6 ai_controller，旧 88 零回归）✅
- 真跑渲染截图：AI 自驱部署红方单位、与玩家蓝方单位在 lane 内对推 ✅

---

## V2 阶段

> 环境切换说明：自此阶段起开发机为 **Windows**（工程根 `F:\godotProject`，PowerShell，godot 4.6.3 经 `~\bin\godot.cmd` shim 在 PATH）。HISTORY/PLAN 中 Mac 路径(`/Users/jeffchen/...`)与 bash 命令为历史记录，Windows 下命令一律翻译为 PowerShell。GitHub 远端 git/gh 走本机代理 `127.0.0.1:7897`。

### V2-1 — 3-lane 逻辑层 + 侧路公主倒后转打王塔（纯逻辑）  （本次提交）
**前置语义（用户 2026-06-08 确认）**：见决策日志 24–25（侧路公主毁后转打王塔；部署仅己方半场/任意 lane，强制校验留 V2-2）。

**范围边界**：仅做 3-lane 的 `Battle`/`Lane` 拓扑与转火逻辑 + 单测；**不动** `Match.setup`（仍单 lane）、显示层、AI——「Match 接通 3 lane + 出牌选 lane + AI 最小适配 + 部署半场校验」整体留 **V2-2**（对齐 PLAN_V2 验收划分：V2-1=单测、V2-2=编辑器可玩）。

**新增/修改**
- `logic/lane.gd`：加兜底王塔 `king_at_start/king_at_end` + `set_king_fallback()`；`_enemy_tower_for` 改为「主塔活着打主塔，主塔（侧路公主）毁则转打该端兜底王塔」；塔位置改 `_enemy_tower_end(unit)` 按单位方向取（替换原 `_tower_position(tower)` 的对象身份判断——否则兜底王塔会被误算到错误端，是必修 bug）。
- `logic/battle.gd`：加 `build_v2_three_lanes(level)`——lane 0 左公主↔公主、lane 1 中王↔王、lane 2 右公主↔公主；侧路挂同一对王塔兜底；6 塔全计入 `player/opponent_towers`，胜负与超时比塔血规则不变。
- `tests/test_battle_v2.gd`：新增 12 个测试（拓扑/中路打王/侧路打公主/**公主毁转打王**/共享王塔双重承伤/三 lane 独立推进/跨 lane 不交战/破王取胜/超时比 6 塔血/平局/真实配置烟雾）。

**决策**：见决策日志 24–25。补充：兜底王塔与主塔同处 lane 端点（progress 1.0/0.0），公主一倒，原本停在 `端点∓attack_range` 攻击公主的单位下一 tick 即对同位置王塔在射程内、自动转火；王塔的「物理靠后」由显示层（V2-2+）做视觉偏移，逻辑层用一维端点足矣。

**踩坑与修复**
1. `var before := battle.opponent_king.hp` 解析失败：`opponent_king` 是 Variant，`:=` 无法从其成员推断类型 → 改 `var before: float = ...`。
2. 独立性测试初版 10 tick（move 0.5 仅走到 0.5，未达 0.9 射程）误判「公主未被削」→ 增到 30 tick 让单位走到边界并出手。

**验收**：
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **106/106 全过**、exit 0（+12 battle_v2，旧 94 零回归）✅
- `godot --headless --quit --path F:\godotProject` 工程加载 exit 0 ✅

### V2-2 — 3-lane 接通（Match + 显示层 + 出牌选 lane + AI 最小适配）  （本次提交）
**前置语义（用户 2026-06-08 确认）**：见决策日志 26–28（越界部署拒绝、AI 固定中路、tap-to-place 选 lane）。

**新增/修改**
- `logic/match.gd`：`setup()` 由 `build_v1_single_lane` 改 `build_v2_three_lanes`——实际对局变 3 lane。
- `logic/player.gd`：`try_play_card` 加部署半场校验（决策 26）——含 `spawn_unit` 的兵牌落点须在出牌方己方半场（玩家 `[0,0.5]`、对手 `[0.5,1.0]`），越界返回 false、不扣圣水/不抽牌；纯法术不受限。新增 `_spawns_troops()` / `_deploy_allowed()`，preload `UnitScript` 取 owner 常量。
- `ai/ai_controller.gd`：`LANE_INDEX 0→1`（固定中路，决策 27），出兵与感知敌情都在中路。
- `view/battle_scene.gd`：单 lane → 3 lane。`LANE_X` 标量改 `LANE_XS=[160,360,560]` 三列；`_build_field` 画 3 道 + 各自己方半场/中线；`_build_towers` 把 6 塔按 `[king中, 左公主, 右公主]` 摆 3 列；`_sync_units` 遍历 3 lane 定位；输入加 `_lane_from_x()` 按点击 x 归属最近列，`_unhandled_input` 改为出到选中 lane。
- `tests/test_ai_controller.gd`：`_opponent_units` 与放敌人 lane 由 0 改 1（跟随 AI 中路）。
- `tests/test_player.gd`：+4 部署校验测试（越界拒绝/边界 0.5 允许/纯法术可打敌方半场/对手越界拒绝）。
- `view/battle_scene.gd`：**运行期事件日志**（`LOG_EVENTS` 开关，仅显示层）——MATCH START / SELECT / PLAY(含圣水增减、被拒原因) / SPAWN / DEATH / TOWER HIT / TOWER DOWN / RESULT，带对局时间戳，打到 Output 面板。白膜阶段肉眼分不清兵种/战况，靠日志观测；**逻辑层零改动、headless 单测不受影响**（view 不进测试）。用户反馈（决策见下）：实机/画面验收以后优先真人执行。

**范围边界**：表现仍白膜（贴图/动画/音频是 D 模块 V2-3+）；AI 仍单一难度、只打中路（完整 lane 攻防是 V2-6）。

**决策**：见决策日志 26–28。补充：半场校验放对称入口 `Player.try_play_card`，玩家与 AI 同受约束（AI 在 0.9 出兵属对手半场 `[0.5,1.0]`，合法）；显示层落点已 `minf(_, DEPLOY_MAX)` 钳在 0.5，正常点击不会触发拒绝，逻辑层校验是兜底。

**踩坑与修复**：无（test_match 因 lane 0 仍在、玩家在己方半场 0.1 出牌而零回归；仅 AI/player 测试随中路与新规则相应更新）。

**验收**：
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过**、exit 0（+4 player 部署校验，旧 106 零回归；含 `test_full_match_with_ai_resolves` 在 3-lane 下 AI 自驱正常分胜负）✅
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，`battle_scene.gd` 无 parse/编译错误 ✅
- `godot --headless --path F:\godotProject` 实跑游戏循环数秒 → 无 SCRIPT ERROR（3-lane 场景 + AI 自驱运行期干净）✅
- **GUI 实机验收（截图核验）**：3 lane + 6 塔（中王大/两侧公主小）布局正确；点选左/右 lane 出 goblins，蓝方单位分别落到左/右路并推进、攻击对手对应公主塔；AI 红方走中路；破王出 YOU/LOSE 横幅 ✅
- **平衡观察（留 V2-8）**：headless 量得「人类挂机、AI 自驱」一局 AI 6.1s 首出兵、王塔 7.6s 首次受伤、19.8s 破王。因中路 lane 直通王塔无公主保护，单路直推威胁很大；非 bug（决策 24 拓扑使然），数值/河道平衡到 V2-8 统一处理。

### V2-3 — 程序化美术换皮（仅显示层）  （本次提交）
**前置决策（用户 2026-06-08 确认）**：美术来源选「**程序化区分**」——不引外部素材，view 层按兵种给不同形状/大小/朝向，塔与背景程序化美化。理由：零依赖、零导入/授权、最快让兵种可辨；逻辑层零改动正好验证「逻辑/显示分离 → 换皮零成本」。

**修改（全部在 `view/battle_scene.gd`）**
- **单位按兵种造型**：新增 `UNIT_VIS` 表——巨人=大八边形(24)+内圈铠甲、骑士=盾形(16)、弓箭手=小圆(12)+远程白点、哥布林=小尖三角(12)、亡灵=菱形(13)+两翼+**地面阴影且机体抬高**(空中一眼可辨)。队伍色作主体填充辨敌我；形状/大小辨兵种；**朝向按推进方向翻转**（我方朝上/对手朝下）。新增 `_unit_shape` / `_flip_y` / `_scale_pts` 辅助，`_make_unit_node` 返回 `Node2D`（多部件）。
- **塔造型**：方形塔身 + 描边；**王塔顶城垛、公主塔尖顶**；摧毁置灰由 `body.color` 改 `body.modulate`（body 现为 Node2D）。
- **背景**：草绿底 + 敌(淡红)/我(淡蓝)半场分区 + 三 lane 通道描边 + **横贯河道 + 每 lane 木桥**（把部署分界线可视化）。

**范围边界**：动画/投射物/AOE 特效/攻击受击反馈是 **V2-4**；音频/主菜单/结算是 **V2-5**；本步只换静态造型。仍无外部素材文件、无 `.import`、无授权负担。

**验收**
- 逻辑层零改动；`godot --headless ... test_runner.gd` → **110/110**（视觉换皮，无新单测，旧测零回归）✅
- `godot --headless --path F:\godotProject` 实跑 → `_ready` 跑通、无 SCRIPT ERROR ✅
- **GUI 视觉验收交用户**（按新纪律：实机/画面验收由真人在编辑器执行；见决策日志「人工验收原则」）。

### 工具链 — 引入 Godot AI MCP（表现层辅助）
**背景**
- 进入 V2 D 模块后，后续 V2-4 / V2-5 会集中处理动画、特效、UI、截图、运行时日志与编辑器场景状态。纯逻辑阶段的 CLI + 单测仍足够，但表现层排查需要更直接的编辑器联动。
- 调研 `godot-mcp-pro`、`tomyud1/godot-mcp`、`hi-godot/godot-ai` 后，优先选择 **Godot AI**：免费 MIT、明确支持 Codex / Claude Code、工具面覆盖场景树/日志/截图/测试/节点和 UI 操作，且工具数量相对克制。

**来源**
- GitHub：https://github.com/hi-godot/godot-ai
- 导入版本：`2.6.1`（下载源码 commit `5818173` / tag `v2.6.1`）

**项目内新增/修改（进 git）**
- `addons/godot_ai/`：Godot 编辑器插件本体。
- `project.godot`：
  - `[editor_plugins] enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")`
  - `[autoload] _mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"`（插件首次加载后自动加入）
- `AGENTS.md`：新增 Godot AI MCP 的使用方法、前提与守则。
- `HISTORY.md`：记录本节。

**项目外配置（不进 git）**
- `uv`：通过 winget 安装 `astral-sh.uv`，版本 `0.11.19`。当前 Codex shell 若 PATH 未刷新，可临时前置 `C:\Users\user\AppData\Local\Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe`。
- Codex 用户配置：`C:\Users\user\.codex\config.toml` 增加 `[mcp_servers."godot-ai"] url = "http://127.0.0.1:8000/mcp"`。
- Claude Code 用户配置：`claude mcp add --scope user --transport http godot-ai http://127.0.0.1:8000/mcp`，写入 `C:\Users\user\.claude.json`。
- 用户环境变量关闭遥测：`GODOT_AI_DISABLE_TELEMETRY=true` / `DISABLE_TELEMETRY=true`。

**使用方法**
- 先打开 Godot 编辑器：`godot --path F:\godotProject -e`。Godot AI MCP server 由编辑器插件启动；关掉编辑器后 MCP 会断开。
- 正常连接时：
  - MCP HTTP：`127.0.0.1:8000`
  - Godot WebSocket：`127.0.0.1:9500`
  - Claude Code 检查：`claude mcp list` 应显示 `godot-ai ... ✓ Connected`
- 若网络下载依赖，命令行使用 Clash Verge 系统代理：`HTTP_PROXY=http://127.0.0.1:7897` / `HTTPS_PROXY=http://127.0.0.1:7897`。

**踩坑与修复**
1. `uv` 用 winget 装完后当前 shell 的 PATH 未刷新；本次安装用完整 WinGet 包目录临时前置 PATH 继续执行。
2. 插件在 `--headless` 下会打印 `MCP | plugin disabled in headless mode`，这是设计行为；必须用 Godot 编辑器 GUI 启动 server。
3. 用 `Start-Process powershell ...` 嵌套设置环境变量时，Godot 进程没有拿到 `uvx` PATH，日志报 `MCP | no server found — install uv or run: pip install godot-ai`。改用显式环境启动后，日志显示 `MCP | started server` 与 `MCP | connected to server`。
4. 临时诊断日志 `godot_ai_live.log` 属本地排查产物，不纳入 git。

**验收**
- `uvx godot-ai --version` → `godot-ai 2.6.1` ✅
- Godot 编辑器启动后端口检查：`127.0.0.1:8000` / `127.0.0.1:9500` 均监听 ✅
- `claude mcp list` → `godot-ai: http://127.0.0.1:8000/mcp (HTTP) - ✓ Connected` ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过** ✅

### 工具链 — 环境复现指南与 Windows setup 脚本
**背景**
- Godot AI MCP 的插件本体已经进入项目 git，但 agent 客户端注册、`uv`、用户环境变量、Godot/gh/git 等本机工具安装都属于机器级状态；换电脑后不会随仓库自动恢复。
- 因此新增项目级环境指南，类似 Node 项目的 `package.json`/README 角色：说明哪些东西在 git，哪些东西需要每台机器单独装和配。

**新增**
- `docs/ENVIRONMENT.md`：记录 Godot 4.6.3、Godot AI `2.6.1`、`uv`、Codex/Claude MCP 注册、代理、运行测试、打开编辑器、MCP 使用与排错方式。
- `scripts/setup-godot-ai.ps1`：Windows PowerShell 辅助脚本。检查 `addons/godot_ai/plugin.cfg`，检查 `godot`/`git`/`uv`，必要时通过 winget 安装 `astral-sh.uv`，设置 Godot AI 遥测关闭变量，并按需写入 Codex 与 Claude Code 的用户级 MCP 配置。

**决策**
- OS 依赖必须写清楚：Windows 使用 PowerShell + winget + `.ps1`；macOS 使用 Terminal + Homebrew，按 `docs/ENVIRONMENT.md` 手动执行 `brew install --cask godot` / `brew install git uv gh` 并配置 MCP。
- 不把 `C:\Users\user\.codex\config.toml`、`C:\Users\user\.claude.json`、用户环境变量或 winget/uv 安装目录纳入 git；这些是每台机器的本地状态。
- `addons/godot_ai/`、`project.godot` 插件启用、`docs/ENVIRONMENT.md`、`scripts/setup-godot-ai.ps1` 才是项目可追踪部分。

**验收**
- PowerShell parser 检查 `scripts/setup-godot-ai.ps1` 通过，无语法错误。
- `git diff --check` 通过。
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过** ✅

### V2-4 — 动画与特效（仅显示层，路线 A 纯显示层还原）  （本次提交）
**前置决策（用户 2026-06-09 确认）**：见决策日志 30——事件来源走**路线 A：纯显示层、零改逻辑**。逻辑层一行不改，显示层逐帧读状态 + 复刻「目标选择」还原攻击/投射物；玩家法术按点击点/直伤目标精确出特效，AI 法术按「同帧多单位聚集掉血」推断爆点（近似）。

**范围边界**：**只改 `view/battle_scene.gd`**；`logic/*`、`ai/*`、`config/*` 零改动 → 单测仍 110/110。音频/主菜单/结算是 V2-5。仍无外部素材、无 `.import`、无授权负担。

**修改（全部在 `view/battle_scene.gd`）**
- **受击闪白**：逐帧 diff 单位 hp，下降即把主体 `body.color` 向白 lerp + 轻微放大（`modulate>1` 在 GL Compatibility 不保证提亮，故用颜色 lerp，稳定可见）。
- **攻击顶刺**：新增 `_view_find_target` 复刻 `Lane._find_enemy_in_range`（范围内最近敌方单位）+ 尽头敌塔判定来识别「交战」；交战时按 `attack_speed` 节拍把机体朝目标方向顶出再回落（`beat` 预热使接敌当帧即出手，对齐逻辑「接触即攻击」；真伤判定仍以受击闪白为准，二者解耦）。
- **远程投射物**：`attack_range ≥ 0.15`（仅弓箭手 0.25）判远程，攻击节拍时从自身朝目标当前位置发飞镖，按距离折算飞行时长，命中留烟。
- **死亡消散**：单位从 lane 消失时不再立即 `queue_free`，先冒烟，再缩小+淡出+旋转 0.35s 后释放（`dying_units` 承接，逻辑单位早已被 `_remove_dead` 移除）。
- **AOE/法术爆点**：玩家法术（可靠，`_play_spell_fx` 直接知道卡/落点）——火球落点橙色扩张爆盘、电击青蓝放射火花、射箭落箭+尘；直伤落在「最逼近自己塔的敌方单位」处（`_first_enemy_screen_pos_for`，与 `SkillSystem` 选择一致）。AI 法术（显示层看不到其经 `opponent_controller.tick` 的出牌）——按「同帧某 lane ≥2 个玩家单位聚集掉血」推断一次爆点（近似，0.5s 节流 + 0.25 聚集窗）。
- **塔受击/摧毁**：受击抖动 + 白色火花（按 flash 节流）；摧毁瞬间碎块向上爆裂、受重力下落、淡出 + 塔身置灰 + 大抖动。
- 新增轻量特效系统：`fx_layer`（盖在单位/塔之上）+ `projectiles`/`effects`/`dying_units` 列表 + 通用 `_update_effects`（扩张/淡出/速度+重力/自旋）、`_update_projectiles`、`_update_dying`。动画时长一律按渲染 `delta` 推进（显示层插值，**不绑逻辑 tick**——游戏速度仍由 `SimClock` 固定 tick 决定）。

**决策**：见决策日志 30。补充：动画与随机散布（抖动、碎块）仅活在显示层，不影响逻辑确定性；攻击节拍在显示层近似计时，与逻辑 tick 的精确伤害时刻可能微小漂移，但受击闪白由真血量 diff 驱动，锚定真实掉血时刻。

**踩坑与修复**
- 临时 headless 探针时序坑：场景 `_ready` 要等加入树后的首帧才跑，探针在 `_initialize` 即访问 `scene.match_obj` 报 `Nil.config`；改到 `_process` 首帧（_ready 已就绪）后正常。**这是探针自身问题，非 `battle_scene.gd`**；探针（`tests/_fxsmoke.gd`）验后即删、不入 git。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0、`battle_scene.gd` 无解析/编译错误 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **110/110 全过、SCRIPT ERROR=0**（逻辑零改动，无新单测）✅
- `godot --headless --path F:\godotProject` 实跑主场景 14s（AI 自驱）→ 0 运行期错误；常驻路径（出兵建节点 / 攻击节拍复刻 / 塔受击）干净 ✅
- 临时探针强制触发 AI 独跑碰不到的 FX 路径 → **0 运行期错误**；正向证据：DEATH×1（死亡消散实体）、TOWER DOWN×1（碎块）、投射物在飞×1、特效×8（火球/电击/射箭/AI-AOE 推断），玩家三种法术 + 兵牌 no-op 分支均无错 ✅
- **GUI 视觉验收**：人工主观验收**通过**（2026-06-09，用户在编辑器实机确认）；过程用 godot-ai MCP `editor_screenshot source="game"` 辅助核对静态换皮 / 塔摧毁置灰 / 运行时节点树（unit_layer 6 单位 + 6 塔 + fx_layer）。提交 `55c2fb7`、已推 develop。

### 工具链 — godot-ai MCP 画面/FX 验收协议（V2-4 复盘，2026-06-09）
**背景**：V2-4 用 MCP 截图验收时效率差——找工具慢、与「播放状态/截图桥」反复较劲、截图时机靠碰运气、还让用户手动延长对局来配合。用户要求改进，协议已固化进 [CLAUDE.md](CLAUDE.md)「画面/FX 验收用 MCP 时的协议」（可移植、随 repo 走）。
**协议要点**：① 开头一次 ToolSearch 载全工具（editor_state/project_run/project_manage/editor_screenshot/game_manage/logs_read），认准 **`editor_screenshot source="game"`**（2D 工程别用默认 `viewport` 源会报错）；② 干净启动 `stop`→`editor_state`(等 is_playing=false)→`project_run(autosave=false)`→轮询 `game_capture_ready=true` 再截；③ 不碰运气抓 <0.3s 瞬时 FX、不让用户陪打——写**临时(不提交)验收 harness** 用 `Engine.time_scale≈0.15` 慢放/暂停/循环把 FX 定格再截（headless 探针的"有画面"版）；④ `logs_read(source="game")` 读局内事件（`_log` 的 SPAWN/DEATH/TOWER HIT）掐时机；⑤ `game_manage input_mouse` 坐标被映射到桌面全局坐标(多屏)、点不准 UI，别依赖，要交互走代码钩子/harness 或让用户点。
**踩坑**：① input_mouse 注入坐标映射到全局桌面坐标（多显示器），点不中卡牌；② 截图桥须用 MCP 自己 `project_run` 启动的实例（手动 Play 的实例 `_mcp_game_helper` 不一定建桥），且 stop 后要先 `editor_state` 刷新缓存再 run。

### 工具链 — Excel 策划源表 + JSON 生成配置（2026-06-09）
**背景**
- 现有配置只有 `cards.json` / `units.json` / `levels.json` 三张 JSON，早期实现轻量，但继续进入 V2-B/V2-C 后会扩卡、扩关卡、扩 AI 难度与数值平衡；直接手改 JSON 不适合策划长期读改。
- 目标是让人类日常维护 Excel，同时保持 Godot 运行时继续读取 JSON，避免为游戏逻辑引入 Excel 解析依赖。

**新增 / 修改**
- `config/GameConfig.xlsx`：新的策划源表。包含 `Units`、`Cards`、`CardSkills`、`Levels`、`Decks`、`Balance_View`、`_Enums`。`Balance_View` 用公式辅助看 DPS 等派生指标；`_Enums` 为下拉枚举源，不导出。
- `tools/build_config.py`：配置同步脚本。默认从 `GameConfig.xlsx` 生成 `config/cards.json`、`config/units.json`、`config/levels.json`；`--check` 校验 Excel 生成结果与磁盘 JSON 一致；`--from-json` 从当前 JSON 重建 Excel，用于 agent JSON 优先改配置后的同步，以及初始化/救急反向同步。
- `CLAUDE.md`：新增「配置工作流（JSON / Excel 双入口）」；明确 agent 默认直接改 JSON，确认后 `--from-json` 同步 Excel。
- `AGENTS.md`：按用户要求用更完整的 `CLAUDE.md` 内容覆写补齐，并同步配置工作流。
- `.gitattributes`：将 `*.xlsx` 标记为 binary。
- `tests/test_config_loader.gd`：新增 `test_excel_source_workbook_exists`，确保策划源表随项目存在。
- `config/*.json`：当前由 `GameConfig.xlsx` 生成过一次；后续 agent 可直接改 JSON，最终再同步回 Excel。

**决策**
- 运行时仍读 JSON，`ConfigLoader` 与战斗逻辑不为本次迁移改架构。
- agent 默认 JSON 优先；Excel 是给人类读改的工作簿镜像，也是最终需要保持同步的策划视图。
- `CardSkills` 采用“一行一个技能积木”，按 `card_id + order` 聚合成 JSON 的 `skills` 数组，避免在单元格里手写 JSON。
- `attack_interval_s` 是 Excel 面向策划的字段名，生成到 JSON 仍叫 `attack_speed`，沿用现有代码字段；语义记录为「攻击间隔（秒/次）」。
- `--from-json` 是 agent 配置工作流的常规收尾步骤；但它会覆盖 Excel，所以遇到疑似用户未同步 Excel 改动时必须先确认。

**验收**
- `uv run --with openpyxl python tools\build_config.py --check` → `config check ok`、exit 0（uv 首次解析依赖时有 openpyxl 依赖版本 warning，但不影响执行）✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **111/111 全过**、exit 0 ✅

### V2-5a — 主菜单 + 结算面板（场景闭环骨架，仅显示层）  （本次提交）
**前置决策（用户 2026-06-10 确认）**：见决策日志 32（V2-5 拆 3 小步、音频缓做、UI 全英文）。本步只做 **a 场景闭环骨架**。

**范围边界**：仅显示层 / 场景层；`logic/*`、`ai/*`、`config/*`、`tests/*` 零改动 → 单测仍 111/111。战斗内 HUD 美化是 V2-5b，音频已定缓做（V2-5c）。仍无外部素材、无新 `.import`、无授权负担。

**新增 / 修改**
- `view/main_menu.gd` + `view/main_menu.tscn`（新，**主场景**）：主菜单。深绿底 + 三 lane 暗条 + 上下蓝色带；标题 `CLASH PUSHER`、副标题 `3-LANE TOWER RUSH`；`START` → `change_scene_to_file(battle_scene)`、`QUIT` → `get_tree().quit()`。纯程序化绘制、全英文。
- `view/battle_scene.gd`：把原本一行 `banner` Label 的胜负展示升级为**结算面板** `result_layer`（全屏 `Control` + `MOUSE_FILTER_STOP` + 压暗 backdrop，天然拦截身后卡牌点击）——胜负标题（YOU WIN / YOU LOSE / DRAW，按结果着色）+ 比分（`Towers You x Enemy y`，读 `battle.total_tower_hp`）+ `REMATCH`（`reload_current_scene` → 全新一局）/ `MENU`（`change_scene_to_file(main_menu)`）两按钮。`_build_result_panel()` 于 `_build_hud` 末尾建好并隐藏，`_sync_result()` 在对局结束首帧显示一次。删除旧 `banner` 与 `_sync_banner`。
- `project.godot`：`run/main_scene` 由 `battle_scene.tscn` 改为 `main_menu.tscn`，串起 菜单→对局→结算→(再来一局 / 回菜单) 闭环。

**决策**：见决策日志 32。补充：结算面板用「全屏 STOP Control + 子按钮」而非单 Label——覆盖层在 `visible=true` 时拦截身后输入、`visible=false` 时不参与输入，无副作用；REMATCH 用 `reload_current_scene()` 拿到全新一局（Match 重建、圣水归零、塔满血、手牌重置），MENU/START 用 `change_scene_to_file`——标准 Godot 场景切换，逻辑层无需参与、不持跨场景引用。

**踩坑与修复**
- 无（一次通过）。沿用既有显示层经验：跨场景按路径切换、不持引用；新文件先 `--headless --editor --quit` 导入生成 `.uid`；`project.godot` 仅主场景一行变更、无编辑器 churn。

**验收**
- `godot --headless --editor --path F:\godotProject --quit` → exit 0，`main_menu.gd` / `battle_scene.gd` 无解析/编译错误，`project.godot` 仅 `run/main_scene` 一行变更 ✅
- `godot --headless --path F:\godotProject --script res://tests/test_runner.gd` → **111/111 全过**（逻辑零改动，无新单测）✅
- 两场景 headless 烟测（`--quit-after`）→ 0 运行期错误 ✅
- 临时探针强制对局结束 → 结算面板 `visible` 切换正常、WIN/LOSE/DRAW 文案与比分（`Towers You 5200 Enemy 5200`）均无报错，验后即删、不入 git ✅
- **GUI 视觉验收**：人工主观验收**通过**（2026-06-10，用户在编辑器实机确认闭环：菜单 → START → 对局 → 分胜负弹结算 → REMATCH 全新局 / MENU 回菜单）✅
