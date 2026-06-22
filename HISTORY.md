# HISTORY.md — 开发历史与进度记录

> **本文件用途**：给任何接手的人/agent（新开对话也一样）一个**准确、自足**的项目进度与历史。
> 阅读顺序：[PLAN_GRAND.md](PLAN_GRAND.md)（roadmap）→ [PLAN_V4.md](PLAN_V4.md)（**当前阶段权威规划**）+ [docs/PLAN_V3.md](docs/PLAN_V3.md)（V3 收尾参考）→ [CLAUDE.md](CLAUDE.md)（操作手册）→ 本文件（进度总览 + 决策日志 + 当前阶段逐步）。
> **完成阶段的详细逐步历史已归档**：V1/V2 → [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)；V3 → [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。本文件只保留**进度总览 + 决策日志 + 当前阶段**。已完成阶段的 PLAN（V1/V2/V3）也已归档到 `docs/`。
> **维护约定**：每完成一步（或重要决策/踩坑）在此追加（V4 阶段直接写本文件；V3 及更早的详细段只追加到对应 docs/ 归档），随该步 commit。

---

## 快速上手（新 agent 必看）

- **本机是 Windows**（路径 `F:\godotProject`，shell 用 Git Bash）。**文档历史里的 macOS 命令是早期 Mac 用户留下的**（V1/V2 时期），含义照搬即可：把 `HOME=/private/tmp/godot-home godot ...` 翻成本机的 Godot 完整 exe 路径（`~\bin\godot.cmd` 或 winget 安装的 console exe）。
- 跑全部单元测试（逻辑层验收主手段，带 `HOME` 隔离避免污染真实 home）。文档里的标准命令：
  ```bash
  HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd
  ```
  Windows 下用本机 godot exe 替换 `godot` 即可。退出码 0=全过；非 0=有失败（末尾打印明细）。
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
| 9 | 安卓导出 + 触摸 + 竖屏 | ⏸ 缓做（移至 V4 产品化阶段） | — |
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
| V3-4b | 战间 draft 三选一（确定性候选、改写本 run 卡组、卡组可增长） | ✅ 完成（单测） | `239012b` |
| V3-4c | relic 系统（JSON 数值修正器、effective level 不污染 base、起手圣水） | ✅ 完成（单测） | `239012b` |
| V3-4d | boss/精英节点难度修正 + 局间 meta 解锁 + 存档（user:// 往返）+ 最简 run view | ✅ 完成（单测 + headless smoke；引擎内流程交真人验收） | `239012b` |
| V3-6a | 拖拽部署（CR 式）+ 落点 ghost/合法红绿 + 半场高亮 + 落地涟漪 + 入场缩放（仅 view） | ✅ 完成（单测 172/172；**真人实机 7/7 验收通过 2026-06-16**） | `1999797` |
| V3-6b | 战斗 juice：移动插值 + 受击闪白 + 浮动伤害数字 + 命中顿帧 + 震屏 + 命中火花（仅 view） | ✅ 代码完成（单测 172/172 零回归；手感待真人验收） | `8a09953` |
| V3-6c | HUD 反馈：分段圣水条 + 满槽脉动 + 卡面自绘(费用/不可用扫光/选中) + 下一张预览 + 王冠/倒计时强调（仅 view） | ✅ 代码完成（单测 172/172 零回归；外观待真人验收） | `819a713` |
| V3-6d | 胜负演出（调暗/标题 sting/王冠落入/比分滚动/按钮淡入）+ run 奖励·结算揭示动画（仅 view） | 🚧 代码完成（headless smoke + 单测 172/172 零回归；演出待真人验收） | `c22d601` |
| V3-7 准备 | 美术素材入库（`assets/` 选用 94 + `testAssets/` 库）+ ART_ASSETS 美术圣经雏形（题材=黑暗中世纪幻想） | ✅ 完成 | `6579207` |
| V3-7 ① | 卡牌黑暗中世纪化改名（`cards.json` name 中英定稿，id 不变） | ✅ 完成（单测 172/172；config check ok） | `0cb32f2` |
| V3-7 ② | 多语言 i18n（中英表 + autoload + 像素中文字体 + 6 场景接入 + 设置内切换/存盘） | ✅ 代码完成（6 场景 smoke + 单测 172/172；中文显示真人认可） | `0cb32f2` |
| V3-7 ③ | 美术垂直切片（骑士精灵 / building 塔贴图 / 火爆炸序列 FX + 像素 nearest filter；架构 A：immediate `_draw`+`draw_texture`，仅 view） | ✅ 完成（**真人 6/6 验收通过 2026-06-20**；单测 172/172） | `41c09d5` |
| V3-7b-1 | 量产·单位精灵全量（10 单位 manifest `view/sprite_db.gd` + 走/攻状态派生 + 朝向；修正 ③ 骑士帧 bug） | ✅ 完成（**真人 1-7 验收通过**；单测 172/172） | `4aacb21` |
| V3-7b-2 | 量产·塔（王=building1 / 公主=building6 + 保持长宽比贴地 + 金王冠 + 废墟态） | ✅ 完成（**MCP 截图验收**；单测 172/172） | `4aacb21` |
| V3-7b-3 | 量产·技能命中 FX 按卡区分 + 远程投射物（路线 A 冷却跳升检测；含投射物只射一发 bug 修复） | ✅ 完成（**MCP 计数器验证投射物持续开火** + 真人玩通无错；单测 172/172） | `4aacb21` |
| V3-7b-4 | 量产·地形 tile（Lonesome FLOOR 地面 / simple_water 12帧动画河 / COBBLESTONE 桥；逐逻辑格铺替纯色块） | ✅ 完成（单测 172/172 + smoke） | `f3c8abf` |
| V3-7b-5 | 量产·战斗手牌卡面（兵牌=单位精灵正面帧 / 法术牌=特效图标；draft·组卡卡面留 7b-5b） | ✅ 完成（**真人验收通过**；单测 172/172 + smoke） | `0e73300` |
| V3-7b-5b | 量产·draft 奖励卡 + 组卡界面卡面（Control+TextureRect 加单位/法术肖像；共享 `SpriteDB.card_portrait_tex`） | ✅ 完成（**真人验收通过**；导入解析+单测 172/172+deck_builder smoke） | `39c80ff` |
| V3-7b-6 | 美术圣经定稿（`docs/ART_ASSETS.md`：单位 manifest 帧网格/行/朝向 + 帧坐定方法 + 塔/FX/地形/卡面 as-built + 缺口/许可，决策 42 升级） | ✅ 完成（纯文档） | `eddba86` |
| V3-8 | 音频资源表 + 运行时音频机制（AudioConfig.xlsx→audio_assets.json→AudioManager） | ✅ 代码完成（audio config check；单测 177/177；headless editor 导入通过；真实素材待补） | `0c5ce0e` |
| V3-9 ① | 难度系统扩 5 档（rookie/easy/normal/hard/extreme）+ 标题/配色/5 关 + 降难度底 | ✅ 完成（梯度实测单调；单测 177/177；config check ok；手感交真人） | `0c5ce0e` |
| V3-R | 回归修复：寻路卡桥/塔射箭/亡语落水/攻击动画（真人验收通过 2026-06-21） | ✅ 完成（单测 180/180） | `14a29e5` |
| V3-UI | 像素 UI 设计系统(PixelUI 9-slice) + 6 屏全统一(主菜单/选关/设置/组卡/run/战斗HUD) + 选关返回 bug 修复 | ✅ 完成（真人验收通过 2026-06-21；单测 180/180） | `242b287` |
| V3-5a | 新手战役框架：CampaignState(可重试) + campaign.json 6 教学关 + 战役中枢 view + battle 战役模式 + 菜单入口（含修复选关混入 campaign 关 bug） | ✅ 完成（真人 1-6 验收通过 2026-06-22；单测 186/186） | `80cf141` |
| V3-5b | 新手引导覆盖层：tutorial.json 数据驱动 + battle_scene 引导(压暗/挖洞高亮/手指/气泡, tap+动作推进) | ✅ 完成（真人验收通过 2026-06-22；单测 186/186） | `4364dbb` |
| V4-S0 | 协议/Go 脚手架/docker compose（PLAN_V4 + proto + server/ + Makefile） | 🚧 进行中（PLAN 已写，脚手架待写） | — |

> **当前阶段 = V4 联网升级 + 实时对战**（账号/匹配/PvP/赛季/排行榜；长期 F2P 但前期玩法验证不实现支付）。权威规划见 [PLAN_V4.md](PLAN_V4.md)；方向锁定见决策日志 46。**V1/V2/V3 全部完成**——V1 机制白膜 → V2 3-lane + 程序化换皮 + AI 难度 + 内容平衡 → V3 2D 战斗 reboot + 空军 + 新积木 + Roguelite 主轴 + 交互手感 + 精灵美术 + 音频骨架 + 难度 5 档 + 像素 UI 设计系统 + 新手战役 + 引导。V1/V2 详细见 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)，V3 详细见 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。**V3-9 平衡剩余子项**（数值/节奏调优 + 设置/导出/上架打磨）与 V4 早期阶段（S0~S2 账号/档案）可并行。**下一步**：V4-S0（proto + Go 脚手架 + docker compose）。

**测试**：186/186（`HOME` 隔离）。**分支/远端**：开发在 `develop`、`main` 稳定线、`release` 为 Antigravity（Google IDE）创建的安卓打包分支（跟随 develop，agent 默认不动）、`origin`=github.com/jchensh/godot-clash-pusher ；用户说「提交」才 commit + push（走代理）。**配置工作流**：改 `config/*.json` → `uv run --with openpyxl python tools/build_config.py --from-json` 同步 `GameConfig.xlsx` → `--check`；音频单独走 `config/AudioConfig.xlsx` → `config/audio_assets.json`，用 `tools/build_audio_config.py --check` 校验。**godot-ai MCP**：表现层辅助（仅编辑器开着时可用），默认不主动用——细节见 [CLAUDE.md](CLAUDE.md) / [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

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

36. **V3 = 战斗核心 2D reboot + 混合主轴 + 2D 卡通精灵**：用户判断「3-lane + 无自由地形」的简化丢失了皇室战争「兵自由走位的轻 RTS」核心乐趣，要求向 CR 看齐重构。锁定四大取舍：①**战斗模型 2D 化（取代 lane）**——河 + 左右双桥、每方 2 公主 1 王、**己方半场任意落点**、地面兵流场绕桥、空军越河（**首版先全地面**、空军 V3-2）；②**仇恨 = 完整 CR 式**（默认锁最近敌塔、敌方单位进 `aggro_radius` 转火，可拉扯/风筝）；③**出兵领土 = 固定己方半场**（不做破塔扩张领土，留后续）；④**碰撞 = 软推挤**（体积半径 + 确定性分离，**不用物理引擎**、可单测）。**单机主轴 = 混合**（5–6 关脚本短战役兼新手教学 → Roguelite 终盘：3 act / draft 三选一 / relic=JSON 数值修正器 / 永久死亡 / 局间 meta 解锁，复用 `Match`/`Battle`/`AIController`/JSON 管线）。**美术 = 2D 卡通精灵**（静态精灵 + 现有 tween 鞭 动画、素材包打底）。施工图 + 程序重构设计见 [docs/PLAN_V3.md](docs/PLAN_V3.md)。**改 CLAUDE.md 硬性 DO-NOT**：1D lane 进度 → 抽象 2D 场地坐标（tile 空间）；「不用物理引擎」保留（自写确定性软分离）。**重构策略 = 绞杀式（strangler）**：新 `arena.gd` 与旧 `lane.gd` 并存、逐子步迁移、**单测全程绿**，待 V3-1h 全通后再删 lane.gd 及 lane 单测。（⚠️ 此条 V3-1b 起被决策 37 覆盖为「推倒重来」。）

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

> 44 为 **V3 UI/UX 整体优化（像素设计系统 + 全屏统一）**，用户 2026-06-21 确认。

44. **UI = 像素设计系统 PixelUI + 全屏统一**：用户要求菜单/系统界面整体优化、保持像素风（非高清拟物）。立 `view/ui/pixel_ui.gd`（9-slice 按钮/面板 + 色板 + 动态色 sbpixel）+ `tools/gen_ui_assets.py` 生成贴图。落地 = Theme/9-slice（用户选）。**关键约束**：编辑器开着时 MCP 无法为全新 png 生成 `.import`（Godot 双实例锁，headless `--import` 抢锁）→ 定「固定中性样式（按钮/面板）用 9-slice 贴图、动态语义色（难度/稀有度）用程序化 StyleBoxFlat」。6 屏全统一（主菜单/选关/设置/组卡/run/战斗HUD），战斗 HUD 仅色板对齐、战场单位色不动。

> 45 为 **V3-5 新手战役范围**，用户 2026-06-22 确认。

45. **V3-5 = 新手战役（教学专属 6 关 + 可重试 + 无剧情 + roguelite 不锁）**：①关卡 = 新增教学专属序列（`campaign.json` 6 关，焦点 deploy→elixir→bridge→defend→spell→boss + AI 循序），不复用 5 难度关；新增 `campaign_01~06` 到 `levels.json`（⚠️**选关界面须过滤 campaign_* 关，否则混入自由对战**）。②流转 = 可重试（`CampaignState`：胜推进/败留原地重打/全胜通关，区别于 roguelite 二元永久死亡）。③剧情 = 首版极简（关名+focus，无叙事）。④roguelite = 一直开放（不锁）。⑤拆 V3-5a 框架 + V3-5b 新手引导覆盖层。⑥菜单「新手战役」主线金按钮。

> 46 为 **V4 联网升级 + 实时对战方向锁定**，用户 2026-06-23 确认。

46. **V4 = 联网升级 + 实时对战（玩法验证导向）**：用户判断 V3 单机已收尾，要为 PvP/匹配/赛季/排行榜搭服务端基础。锁定：①**战斗权威 = lockstep + 状态哈希校验**（沿用现有 `logic/` 10Hz 确定性 tick，不重写 Go 战斗逻辑）；②**服务端语言 = Go**（高并发 WS、tick 循环、protobuf 一流）；③**网络协议 = WebSocket + protobuf**（移动友好、二进制紧凑；不用 UDP）；④**数据库 = PostgreSQL + Redis**（PG 主存账号/档案/战绩；Redis ZSET 匹配队列+榜单+对局缓存+限流）；⑤**认证 = JWT + refresh token**，前期**匿名 device_id 登录**（无 SMS/邮箱/三方）；⑥**商业模式长期 F2P + 内购解锁/养成**（schema 预留 `purchases`/`unlocks`/`currency` 字段，但**前期完全不实现支付/IAP/养成**）；⑦**部署 = 本地 docker compose**，不上云、不做合规、不做监控告警；⑧**V3 Roguelite + 短战役保留为单人训练营**，不动；PvP 走全新主轴入口；⑨**仓库结构 = 单仓 `/server` 子目录（Go）+ `/proto` 共享 schema**；⑩**客户端平台 = Android + Windows**（iOS/Mac/Linux 不做）。**反作弊深度**：基础 JWT + 状态哈希 + 速率限制；异常检测/封禁推后到 S7。**新增 DO-NOT**：客户端禁止权威化战斗状态——所有指令走服务端转发、状态以双方+服务端三方 hash 对帐为准。**阶段划分**：S0~S5 玩法验证（脚手架/匿名登录/档案云存/lockstep 对战/匹配/赛季+榜）；S6~S12 产品化（战绩回放/反作弊深化/部署/版本/IAP/正式登录/合规/聊天好友）推后。**与 V3-9 关系**：V3-9 平衡剩余子项（数值/节奏调优）与 V4-S0~S2 可并行。施工图见 [PLAN_V4.md](PLAN_V4.md)。

---

## V4 — 联网升级 + 实时对战（进行中）

> 方向见决策 46，权威规划见 [PLAN_V4.md](PLAN_V4.md)。**头号工程 = V4-S3 lockstep 实时对战网络层**。S0~S5 = 玩法验证骨架（脚手架/账号/档案/对战/匹配/赛季+榜），S6~S12 = 产品化推后。每步追加在本段（V3 及更早的详细段去 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md) 写）。

### V4-S0 — 协议/Go 脚手架/docker compose（**当前步骤**）  （未开工）
**前置决策**：见决策 46。
**计划**：
- `proto/` 初版（common/auth/profile/match/battle/leaderboard，~15 条消息）。
- `server/` Go 项目脚手架（`cmd/{gateway,api,battle,migrate}` + `internal/{auth,profile,matchmaking,battle,leaderboard,season,store,pb}` + `migrations/` + `Dockerfile` + `go.mod`）。
- `docker-compose.yml`（pg + redis + server）+ `Makefile`（`gen-proto` / `test` / `up` / `down` / `migrate`）。
- 客户端 `proto/` 解析目录 + gd-protobuf 接入（实际 net/ 接通在 S1）。

**验收**：
- `docker compose up` 起服务（pg + redis + server 三容器健康）。
- `cd server && go test ./...` 通过（脚手架阶段单测占位即可）。
- `make gen-proto` 同时生成 Go (`server/internal/pb/`) 与 GDScript (`net/proto/`) 产物。
- Godot 单测仍 186/186（客户端 net/ 仅新增 proto 解析，不接 logic）。
