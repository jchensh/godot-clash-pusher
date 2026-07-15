# 02 · Phase 2 设计宪法 (Design Constitution)

> 依据 [01_research.md](01_research.md) 的调研结论，把稀有度 / 流派 / 觉醒 / 平衡定成**后续 03 卡库、04 觉醒 meta 的强制校验框架**。
> 与现有 `card_progression.json` / `economy.json` / 引擎机制矩阵**同构扩展**，不推翻已实现系统。

<tldr>
1. **稀有度只 gate「机制预算 + 觉醒深度 + 养成投入」，数值放大系数硬性 = 1.0**——同级同费下 legendary 不比 common 强一分裸数值（否则违背 01 原则）；`base_power` 钉死为战力折算/展示元数据，绝不喂战斗结算。
2. **6 个可做流派**（数量/单兵强/速度 3 主轴 + 控场/空中/诱饵 3 补充），真 Siege 与桥头 spam 因"法术/建筑不打塔、只能己方半场部署"**暂缓**；RPS 三角的闭合**强依赖三件套(splash/建筑索敌/status)**，这三个原语在本文 §0 定 schema。
3. **平衡尺 = CV 模型**：CV=√(队伍总HP×队伍总DPS)，近战地面基准 **CV/e≈80**，远程×0.58 / 空军×0.72 / splash−15% / status−20% / 只拆塔+15%——每张新卡先套角色模板锚 CV，再用 counter 关系微调，**先公式后手感**。
</tldr>

---

## §0 前置约定：机制原语 + base_power 定性 + 养成曲线

### 0.1 三件套机制原语（schema 草案，供 §B/§C/03 一致引用；引擎实现成本在 03 `<tech_debt>` 细化）

| 原语 | 数据表达（草案） | 语义 | 服务哪些流派/觉醒 |
|---|---|---|---|
| **splash 溅射** | units.json 加 `splash_radius: float`（0/缺省=单体，现状零回归） | 单位攻击命中 → 对 `current_target` 周围 `splash_radius` 内所有合法敌方同施伤 | 控场/反 swarm；beatdown 后排清场 |
| **建筑索敌** | units.json 加 `target_priority: "nearest"\|"buildings"`（缺省 nearest=现状） | `buildings` 时无视敌方单位、只锁敌塔（未来含建筑类），仍受 aggro 拉扯规则约束可选关 | beatdown/空中 win-con（巨人/野猪/气球式"只拆塔"） |
| **status 状态** | 施加源带 `on_hit_status`/spell 块带 `status: {kind:"slow"\|"stun"\|"freeze", dur:float, mag:float}`；Unit 加状态计时层 | 命中/命中区域内敌方挂计时 buff：slow 降 move/attack_speed×mag，stun/freeze 期间不能动/攻 | 控场（防守反打）；诱饵后手 |

> **三件套是 RPS 三角的承重墙**（01 结论）：无 splash → "beatdown 克 swarm"不成立、swarm 过强。故三者是**本次扩池的前置引擎工作**，不是可选调味。**building-target 先只锁塔即可**（部署的建筑类 = 另一笔账，本期不做）。

### 0.2 `base_power` 定性（消除"稀有度=强度"张力）
- `card_progression.base_power`（100/140/190/260）**只用于**：队伍战力折算展示、匹配/难度参考、养成进度感。**严禁**参与 `units.json` 基础数值或战斗结算。
- 战斗内平衡准绳**唯一** = §D 的 CV 查表（与稀有度无关）。→ 满足 01 硬约束"同级同费不看稀有度"。

### 0.3 养成 mult 曲线（全局、rarity-neutral，取自 `economy.json`）
- 单卡战斗数值乘区 `mult = (1 + 0.10×(level−1)) × 1.25^(rank−1)`（`apply_stat_mult` 只缩放 hp/damage）。
- level 上限随 rank：rank1→L4 / rank2→L7 / rank3→L10；**满态 = rank3 L10 = 1.9 × 1.5625 ≈ 2.97×**。
- **关键**：该曲线对所有稀有度**完全相同**——rarity 只改"爬到满态的成本"，不改满态倍率。故 maxed common 与 maxed legendary 倍率一致，power 差异**只来自 units.json 基础数值(须按 §D 同尺平衡) + 机制**。

---

## §A 稀有度体系（沿用 4 档 common / rare / epic / legendary）

**中心原则**：稀有度是**「投入 + 机制深度」轴**，不是「强度」轴。高稀有度 = 更专精 / 机制更独特 / 觉醒更深，**不是全面更强**。

| 维度 | Common | Rare | Epic | Legendary |
|---|---|---|---|---|
| **数值放大系数**（同费 HP/DPS 基准偏移） | **1.0** | **1.0** | **1.0** | **1.0** ← 硬性，全档一致 |
| **单卡强度上限** | §D CV 预算封顶（全档同尺，legendary **不得**超预算） | 同 | 同 | 同 |
| **机制预算**（同费可携带多少"特殊机制"，且机制**吃掉**部分裸数值预算、非叠加） | 0–1 轻机制（count/亡语） | 1 机制（对空/远程/1 件套） | 1 强机制 or 2 件套组合 | 1 签名机制（多件套/独特交互，专精换脆弱面） |
| **觉醒资格**（详见 §C） | rank2/3 = 数值跳 + 轻量(count+/radius+) | rank2/3 = 1 项轻机制 | **rank3 = 签名觉醒(新机制/三件套)** | **rank2 可机制、rank3 = marquee 觉醒** |
| **base_power**（展示折算） | 100 | 140 | 190 | 260 |
| **解锁碎片** | 30 | 50 | 80 | 120 |
| **升级金币基数 / +50%/级** | 80 | 160 | 320 | 600 |
| **升阶成本**（rank2/rank3） | 20碎+2k / 50碎+5k | 30碎+4k / 80碎+10k | 40碎+8k / 120碎+20k | 60碎+15k / 200碎+40k |
| **金字塔配额（03 目标 ~48 张）** | **~18** | **~14** | **~10** | **~6** |

**为什么机制预算随稀有度升、但强度不升**：一个 legendary 用"签名机制"消耗掉它本可用于裸 HP/DPS 的预算（§D 里 splash −15%、status −20% 就是这个折价），换来**独特性与专精**，同时用**脆弱面**（如只拆塔不能防守、低血、慢）保证可被 counter。它更"有意思/更极端"，不更"强"。稀有度真正的墙在**养成成本**（解锁碎片 + 升级/升阶金币逐档 ×2），符合 CR「稀有=难满，不是难赢」。

---

## §B 流派体系

> 每副牌 8 张（`encounters` schema 校验）。均费 = 8 张 elixir 之和 ÷ 8。win-con = 可靠拆塔核心。

### 主轴 3（现引擎 + 三件套即可完整成立）

**① 数量流 Swarm（群涌）**
- 核心打法：低费多体铺场，靠数量 + 包围淹没单体、绕后拆塔；正面换血、抓对方无 aoe 空档。
- 费用结构：均费 **~3.0**，主力 1–3 费群卡（skeletons/goblins 及新增）；win-con = 群体压塔 or 便宜 building-target 兵。
- 典型骨架：2×群卡 + 1 空军群 + 1 便宜法术(诱饵) + 1 廉价 win-con + 2 通用支援 + 1 小法术。
- **克** glass cannon / 无溅射的单体防守；**被** splash 单位 + 范围法术（arrows/log/fireball）**克**（单体 HP 必须 ≤ 一发溅射能清，§D 硬约束）。

**② 单兵强流 Beatdown（坦克攒波）**
- 核心打法：坦克（**building-target 只拆塔**）在己方半场起手，后排叠输出/空军，滚到桥头成型一波带走；用一波价值 > 对方防守费用取胜。
- 费用结构：均费 **~4.2**（偏高），含 1 个 5–7 费坦克 win-con + 2–3 后排输出；怕被抓另一路。
- 典型骨架：1 坦克(only-building) + 2 后排 DPS(远程/splash) + 1 空军 + 1 重法术(fireball/lightning) + 1 小法术 + 2 便宜防守。
- **克** swarm（后排 splash 清）/ control（顶血硬推）；**被** cycle out-cycle + 高单体 DPS(mini_pekka 式) + inferno/status 叠伤 / 建筑分心 **克**。

**③ 速度流 Cycle（循环突袭）**
- 核心打法：极低均费，2–3 秒一循环快速摸回 win-con，反复 chip + 抓对手重卡轮空的空档、另一路 punish。
- 费用结构：均费 **~2.6–3.0**（全场最低），大量 1–2 费；win-con = 便宜快速 building-target 兵（野猪式）。
- 典型骨架：1 便宜 win-con + 4×(1–2 费循环卡：spirit/skeletons/小兵/小法术) + 1 中费防守 + 1 空军 + 1 小法术。
- **克** beatdown（out-cycle + 反手）；**被** swarm 淹单体防守 / 强 control 防死 **克**。

### 补充 3（三件套解锁，补齐 meta 生态）

**④ 控场流 Splash-Control（防守反打 lite）**
- 打法：splash 单位 + status(减速/眩晕) 做高效防守，转化防守单位为反打。**不做"法术蹭塔"**（引擎不支持）→ 靠反打累积而非 chip。
- 费用：均费 ~3.6；核心 = 2 splash + 1 status 施加 + 高效防守件。
- **克** swarm / bridge-spam；**被** beatdown 顶血推过 / 超远程风筝 **克**。

**⑤ 空中流 Air（空压）**
- 打法：空军 win-con（飞行直线越河、只被"对空"克）+ 对空支援护航；打没有对空的 deck。
- 费用：均费 ~3.8；核心 = 1–2 空军 win-con + 对空远程 + 小法术。
- **克** 缺对空的地面 deck；**被** 对空远程集火(musketeer 式) / 对空群(minions) **克**。

**⑥ 诱饵流 Bait-lite（消耗后手）**
- 打法：多张"怕小法术"的便宜 swarm，诱对手把 arrows/log/zap 浪费掉，再落后手核心吃价值。**主要在 PvP 天梯有效**（PvE AI 对法术追踪弱，价值打折——03 会据此控制其在 PvE 遭遇的占比）。
- 费用：均费 ~3.2；核心 = 3–4 张怕法术的 swarm/建筑。
- **克** 法术依赖 deck；**被** splash 单位（不靠法术清群）**克**。

### 暂缓 2（需超三件套的引擎，留后期版本）
- **⑦ 攻城流 Siege**：需"建筑隔场打塔"（伤害积木/建筑能打塔）——本期不做。
- **⑧ 桥头速攻 Bridge-Spam(真)**：需"敌方半场/桥头部署"（现限己方半场，决策36）——本期用高速兵抓空档做 **spam-lite** 混进 cycle，不单列。

### RPS 三角（03 每张卡按此确认克制闭环）
```
        splash 清群
Beatdown ─────────────▶ Swarm
   ▲                      │
   │ out-cycle+反手        │ 淹没单体防守
   │                      ▼
   └──────── Cycle ◀───────┘
对角：Air 打"无对空"任意流派、被对空集火克；Control 克 Swarm/Spam、被 Beatdown 顶穿。
```

---

## §C 觉醒系统规则

**定位**：觉醒 = **rank 永久解锁**（非 CR 的战斗内循环/进化槽——01 结论，避免大改且契合 PvE 养成）。载体 = 现有 `card_progression.rank_unlocks`（rank2/rank3），成本走 `economy.rank_up`。

### C.1 解锁方式
- 攒**卡专属碎片 + 金币**升阶（rank1→2→3），成本随稀有度递增（§A 表）。rank 提升同时解锁：①`rank_stat_mult ×1.25` 数值跳（自动）②该 rank 的 `rank_unlocks` 条目（stat 或 skill）。
- 永久生效：升阶后该卡在任何对局始终是觉醒态（区别于 CR 每局重新循环）。

### C.2 机制 vs 数值（硬取向：机制优先）
- **type=skill（改积木/机制）优先于 type=stat（纯数值）**。CR 2024-05 血泪：进化强度堆在裸数值 = 平衡灾难，反复被 nerf。
- **数值加成必须克制**：单次 rank_unlock 的纯数值增量应显著小于 `rank_stat_mult` 自带的跳变；机制觉醒里附带的数值（如 radius+0.5）只作机制的载体，不做主力强度来源。
- **机制觉醒映射到 ops 或三件套**：
  - 现成 ops（零引擎）：`count_add`（多召唤）/`num_add`·`num_mult`（半径/伤害/治疗微调）/`unit_field`（改单位属性如 death_spawn、加 `splash_radius`/`on_hit_status`/`target_priority`——即**用 unit_field 把三件套挂上去**）。
  - 需三件套引擎：溅射觉醒、status 觉醒、只拆塔觉醒——03 引擎就绪后即可用 `unit_field` op 表达，无需再加 op 类型。

### C.3 觉醒资格（按稀有度分层，理由）
- **签名觉醒（新机制/三件套）集中在 epic+/legendary**；common/rare 的 rank_unlocks 保持**轻量**（count+/radius+/stat）。
- 理由：common 是新手地基，要**可读、简单**；把"改变交互的 marquee 机制"放高稀有度，既符合"高稀有=机制独特/更专精"，又用养成成本 gate 住深度，避免低门槛卡堆复杂机制拉高理解负担。
- ⚠️**据此修正现有占位**：`knight`(common) rank3 "攻击附带小溅射"这类 marquee 机制应**下沉为轻量**(或移给某 epic 新卡)；splash/status/chain 觉醒**不放 common**。（04 逐卡落实。）

### C.4 三条"好觉醒"原则 + 两个反例
**好原则**
1. **改交互，不改数字**：觉醒后这张卡的**打法/克制关系**变了（多一种应对方式），而非单纯更肉更痛。例：baby_dragon 觉醒 → 获得 `splash_radius`，从"单体飞行肉"变成"反 swarm 空中清场"，**新增了它能 counter 的对象**。
2. **保留原有脆弱面**：觉醒**不消除**这张卡的 counter。例：只拆塔坦克觉醒加血，但依旧"能被建筑分心/被高单体 DPS 融"——counter 关系不断。
3. **费用/稀有度自洽**：觉醒强度增量与"爬到该 rank 的养成成本"匹配；高费卡觉醒差距要**小**（CR 教训：6+ 费卡进化差距过大 = 灾难）。

**反例（禁止）**
1. **纯数值膨胀**：rank3 = "HP+40% 伤害+40%"——无新交互、直接拉爆同费对位、power creep 起点。→ 违反原则 1。
2. **抹掉 counter 的全能觉醒**：给远程 glass cannon 觉醒同时加"高血 + 对空 + 溅射 + 减速"——它不再有被克的脆弱面 = 无敌卡。→ 违反原则 2 与"每卡可被 counter"。

---

## §D 数值平衡基准（cost↔HP↔DPS↔count 查表 / 校验尺）

> 用**本项目自己 16 卡实测**（01 议题5）建尺，不搬 CR 绝对值。所有量 per-elixir，scale 无关。量纲：`attack_speed`=间隔s，DPS=damage/interval；HP/DPS 用**队伍总量**（×count）。

### D.1 核心度量 CV（Combat Value）
- **CV = √(队伍总HP × 队伍总DPS)**（几何均值：HP 与 DPS 乘法权衡，一端趋0则整体价值趋0，符合直觉）。含 death-spawn 的把裂出单位 CV 计入。
- 平衡目标：**CV/elixir** 落在角色模板带内。近战地面基准 ≈ **80**（实测 giant 80 / skeletons 80 / mini_pekka 88 / goblins 90；knight 64 偏低=纯无脆弱面的均衡肉本身吃预算）。

### D.2 角色模板表（先套模板锚 CV/e，再分配 HP:DPS）

| 角色模板 | CV/e 目标带 | HP:DPS 分配 | 目标/射程特征 | 现有对标 |
|---|---|---|---|---|
| 近战地面·均衡肉 | 62–72 | ~3:1 | 近战、hits ground | knight |
| 近战地面·坦克 | 74–84 | 6:1–10:1 | 近战、常配 building-target | giant/golem |
| 近战地面·glass cannon | 84–92 | 1:2（低血高DPS集中） | 近战、单体 | mini_pekka |
| 近战地面·swarm | 80–92 | ~1:1 摊 N 体 | 近战、单体极低血 | goblins/skeletons |
| 空军·肉/中程 | 55–62 | ~4:1 | 飞行、中射程 | baby_dragon |
| 空军·swarm | 54–60 | ~1:1 摊 N 体 | 飞行、单体低血 | minions |
| 远程地面·双打 | 44–50 | 1:1.5 | 射程≥4、hits both | musketeer/archers |

> 读法：**射程/对空 ≈ 吃掉一半数值预算**（远程 44–50 vs 近战 80）。这是硬规律，新远程/对空卡不套此带必超模。

### D.3 特殊机制预算折价（在角色模板 CV/e 上再乘）
| 机制 | CV/e 调整 | 依据 |
|---|---|---|
| **splash 攻击** | **×0.85**（−15%） | 溅射=强反 swarm 效用，须扣裸数值 |
| **status on-hit**（减速/眩晕） | **×0.80**（−20%） | 控制效用最贵 |
| **建筑索敌 only-building** | **×1.15**（+15%） | 放弃防守/易被分心=脆弱面，补数值（CR 巨人系更肉的原因） |
| **death-spawn 亡语** | 裂出单位 CV 计入总 CV（不额外折价） | 价值已在裂兵里 |
| **纯地面 hits-ground-only** | 已含在近战地面基准（无对空即"欠"对空效用，故基准可略高） | — |

### D.4 HP↔DPS 分配 + count/swarm 硬约束
- 在 CV 预算内按角色分配：坦克压 DPS 抬 HP、glass cannon 反之、swarm 摊到 N 体。
- **swarm 单体 HP 上限（硬约束）**：单体 HP **必须 ≤ 池中主力溅射/范围法术一发伤害**（保证"被 splash/arrows/log 一扫清"这条 counter 永远成立）。参考现有小法术：arrows 140 / log 130 / zap 75。→ swarm 单体 HP 建议 ≤ ~130，越靠核心 swarm 越低。
- swarm CV/e 可取带上限（碎片化本身脆），但**不得**同时给"高单体血 + 多体"（那是无敌卡）。

### D.5 法术（spell）数值参考（对标现有）
| 类型 | 费用锚 | 参考值 | 说明 |
|---|---|---|---|
| aoe_damage 小清场 | 2–3 | log r2.0/130、arrows r2.5/140 | 清 swarm；伤害 ≥ 目标 swarm 单体 HP |
| aoe_damage 重法 | 4 | fireball r3.0/300 | 清中血群 + 换价值 |
| direct_damage 点杀 | 2 / 4 | zap 75、lightning 280 | 命中最近1敌兵（无连锁，除非 §C 觉醒） |
| aoe_heal | 3 | heal r3.0/150 | 一次性治友军 |
> 法术**不打塔**（引擎约束）→ spell 价值全在"清场/换兵"，定价按"能解掉多少费用的兵"锚，不含拆塔收益。

### D.6 每张新卡的 counter 保证 checklist（03 逐卡过）
落卡前确认池中**≥2 个** counter 成立：
- swarm → 有溅射/范围法术能一扫其单体？
- 坦克/only-building → 有高单体 DPS 融 + 建筑/status 分心减速？
- glass cannon → 有便宜 swarm 淹 or 换血法术？
- 远程 → 有快速近身兵 or 空军绕？
- 空军 → 有对空(air/both) 集火？
- 新机制卡 → 其**脆弱面**明确写出，且池中有对应答案？
**任何一张卡找不到 ≥2 counter → 打回重配数值/机制。**

---

## 交给 Phase 3（卡库）的强制约束速查
1. 规模 ~48 张，稀有度金字塔 **~18/14/10/6**（common→legendary）。
2. 每张卡：套 §D 角色模板锚 CV/e → 分配 HP:DPS → 过 §D.6 counter checklist。
3. 流派覆盖：主轴 3 各 ≥ 完整 deck 骨架的卡；补充 3 各 ≥ 核心 2–3。真 Siege/桥头 spam 不出卡。
4. 用三件套的卡 → 进 `<tech_debt>` 标引擎成本；splash/status/building-target 按 §0.1 schema。
5. 觉醒资格按 §C.3 分层标注（signature 觉醒仅 epic+）。
6. `base_power` 按稀有度填（100/140/190/260），**不参与**战斗数值。
