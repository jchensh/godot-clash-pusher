# 01 · Phase 1 调研 — CR 品类稀有度 / 进化 / 流派 / 费用平衡 / 卡池规模

> 卡池扩充设计四部曲之一。硬性 gate：本阶段结论为后续「设计宪法(02)/卡库(03)/觉醒 meta(04)」的取材与约束基线。
> 方法：WebSearch 取 CR 品类事实 → 用**本项目实际代码/数据**（16 卡 + 引擎机制矩阵）折算启示，不直接搬 CR 绝对数值（两边数值 scale 不同）。

<tldr>
1. **稀有度≠强度**（CR 官方设计佐证）：稀有度只 gate「等级下限 + 升级投入 + 机制复杂度」，不给平白的数值碾压——maxed common 可以是版本答案（骷髅海是 CR 用得最多的卡）。本项目 `base_power` 升序(100/140/190/260)若直喂战斗数值会违背此原则，须在 02 明确它只作**战力折算/展示**、战斗内同级平衡与稀有度无关。
2. **觉醒优先机制、不是加数值**（CR 2024-05 进化重构的明确方向）+ **RPS 三角在数学上依赖 splash**（beatdown 靠溅射克 swarm，无溅射则 swarm 只能被法术克、必然过强）——你批准的 splash/建筑索敌/status 三件套正好是让流派三角闭合的承重墙，不是可选调味。
3. **40–60 张卡被验证是健康的早期规模**（CR 全球上线约 48 张撑起多年竞技 meta），真正的约束不是总数而是**每个流派要有能凑出 deck 的卡池**；现有 16 张只够 ~2 个流派，扩到 ~45–52（约 3×）并按流派覆盖分配是对的。
</tldr>

---

## 议题 1 · 稀有度体系（Common / Rare / Epic / Legendary / Champion）

**事实（CR）**
- 5 档稀有度，**等级下限随稀有度抬升、总级数递减**（2025-11 加到 L16 后）：Common L1–16、Rare L3–16、Epic L6–16、Legendary L9–16、Champion L11–16。每级 HP/伤害 **≈ +10%**。
- **稀有度不代表更强**。稀有度只表示「稀有程度 + 升满投入」：升级材料/金币随稀有度陡增（EWC 折算 1 / 5 / 20 / 1500 / 4000），但**同为版本核心的卡横跨全稀有度**——骷髅海(common)是 2025 全局出场率最高的卡。官方社区指南原话："higher rarity equals better cards. This is false."
- 稀有度与**机制复杂度**正相关：Common = 通用地基角色；Epic = 专精角色；Legendary = 低稀有度没有的独特机制；Champion = 可**主动激活的技能**（花圣水触发、有 CD、每副牌限 1 张）。

**对本项目启示**
- 现有 `card_progression.json` 4 档 + `economy.json`（level_cap_per_rank 4/7/10、upgrade_cost_base 80/160/320/600、unlock_shards 30/50/80/120、rank ×1.25/level ×1.10）**结构上就是 CR 那套**——方向验证，02 做校准/外推即可，不另起炉灶。
- ⚠️**要修正的风险**：`base_power` 100/140/190/260 升序。若它参与战斗内数值 → 高稀有度平白更强，违背 CR 原则。02 必须把 `base_power` 钉死为**队伍战力折算/展示 + 匹配用**的元数据，战斗内平衡按「同级同费不看稀有度」做。稀有度换来的是**机制独特性 + 觉醒资格**，不是裸数值。
- **Champion 第 5 档 = 主动技能 = 重引擎成本**（要新增「点按激活/CD/每副限一」输入与状态系统），**不在你批准的 splash/建筑/status 三件套内**。倾向 02 里给「暂不做 Champion，改用『觉醒』承载高稀有度的机制深度」的建议（带理由），把第 5 档留作后期。

来源：[Fandom·Cards](https://clashroyale.fandom.com/wiki/Cards) / [ClashDecks·稀有度指南](https://clashdecks.com/guides/beginner/understanding-card-rarities) / [RoyaleAPI·L16 经济](https://royaleapi.com/blog/level-16-and-economy-changes-2025-q4)

---

## 议题 2 · Evolution（进化/觉醒）机制

**事实（CR）**
- **触发 = 循环制**：把带进化的卡在一局里打出 N 次(cycle)后，下一次部署即为进化体；进化体死亡则重置、需重新循环。进化不额外花圣水。cycle 数按卡而定（骷髅 3、野蛮人/皇家巨人 1、火花女 2）。
- **进化槽**：每副牌 1–2 个专用槽（King 等级/竞技场解锁）；卡放非进化槽则只当普通卡用。解锁靠**每卡 6 枚进化碎片**或**通用碎片**。
- **设计铁律（2024-05 重构）**："shift Evolutions' power away from raw stats towards their unique abilities."——他们**主动砍进化的裸血/裸伤**（皇家巨人进化血量加成 1.1×→1.0×；野蛮人移除伤害 boost、血量 1.25×→1.1×），把强度压回**机制**。理由原话：进化与基础的差距「too large, especially for costing 6+ Elixir」。
- **机制模式库**（可直接抄成觉醒设计词汇）：
  - Knight → **受伤减免**(减伤 buff，防御向)
  - Firecracker → 弹片分裂 + 留**灼烧/减速地带**(area denial + status)
  - Barbarians → **命中触发狂暴**(自 buff 攻速/移速)
  - Bomber → **弹跳炸弹**(多段/穿透)
  - Skeletons → **多召唤**(count+) + 首击加速
  - Battle Ram → **亡语召唤『进化体』**(死亡裂进化兵)
  - Mortar / Royal Giant → 纯攻/纯血强化（**官方认为这类最没意思、反复被 nerf**）

**对本项目启示**
- ✅ **觉醒引擎已就位**：`rank_unlocks` 的 `type=skill` + ops(`count_add`/`num_add`/`num_mult`/`unit_field`) 就是「改积木/改单位属性」。凡能用这 4 个 op 表达的机制觉醒 = **零引擎成本**（如 Skeletons 多召唤、Battle Ram 式亡语裂兵已可做）。
- ⚠️**别照搬 CR 的循环/进化槽**：CR 进化是**战斗内循环、临时、死亡重置**；本项目应做**rank 永久解锁**（升阶后该卡永远是觉醒态）。后者更契合 PvE 养成、且引擎现成，前者要新增 cycle 计数 + 进化槽 deck 系统 = 大改。**结论：我们叫「觉醒」但走 rank 永久制，不抄 evo-slot。**
- ✅ **机制优先原则直接采纳**（02 的觉醒规则第一条）：觉醒尽量 `type=skill` 改机制，`type=stat` 纯数值只作陪衬；且**数值加成要克制**（CR 血泪教训：高费卡的觉醒/基础差距过大 = 平衡地狱）。新机制里的「灼烧/减速地带、命中触发 buff、减伤」正需要你批准的 **status effects**。

来源：[Fandom·Card Evolution](https://clashroyale.fandom.com/wiki/Card_Evolution) / [Supercell·2024-05 平衡](https://supercell.com/en/games/clashroyale/blog/release-notes/may-balance-changes/) / [Fandom·Firecracker 进化](https://clashroyale.fandom.com/wiki/Firecracker/Evolution) / [Fandom·Barbarians 进化](https://clashroyale.fandom.com/wiki/Barbarians/Evolution)

---

## 议题 3 · Archetype 分类与胜负逻辑

**事实（CR）**
- 主流 7 类，每类都有明确**win condition（可靠拆塔的核心卡）**：
  - **Beatdown**：坦克在前 + 后排输出，攒一波大推；贵、怕对方拆另一路。win-con=Giant/Golem/Lava Hound。
  - **Control**：不追一波带走，靠高效防守 + 反打 + **法术蹭塔**慢慢磨。多带 Rocket/Poison 重法术。
  - **Cycle**：极低均费，快速循环回 win-con（Hog）反复施压、抓对手轮空。
  - **Siege**：win-con 是**建筑**（X-Bow/Mortar），架在己方半场**隔场打塔**，靠便宜卡护builder + 比对方更快循环回来。
  - **Bridge Spam**：桥头速推快高伤单位（Bandit/Battle Ram/Royal Ghost），惩罚对手 overcommit。
  - **Bait**：逼对手把小法术(Log/Arrows)浪在一个 swarm 上，再放怕法术的核心卡吃巨大价值(Goblin Barrel)。
  - **Hybrid**：混两类，难预判。
- **技能表达各异**：cycle 吃精算/数牌，beatdown 吃规划/取舍，control 吃耐心/法术纪律，bridge spam 吃 punish 时机，bait 吃法术追踪。

**对本项目启示**
- 你提的 3 类（数量流/单兵强流/速度流）= CR 的 **swarm-bait / beatdown / cycle 子集**。要撑健康 meta，02 需补：**Control（防守反打）、Splash 控场、Air（空中压制）**；**Siege / Bait 部分做、真 Siege 暂缓**——理由见下条引擎约束。
- ⚠️**部分 CR 流派依赖本引擎没有的机制**：
  - **Control 的「法术蹭塔」和 Siege 的「建筑隔场打塔」都被『伤害积木不打塔』挡死**（`skill_system.gd:9`）。→ 真 Siege 需要「建筑类 + 建筑能打塔」两项大改，**暂缓**；Control 先靠 status(减速/眩晕) + 高效防守做「防守反打 lite」，蹭塔留后。
  - **Bridge Spam 需要「桥头/敌方半场部署」**，当前部署限己方半场(决策36)。→ 用「高速兵抓轮空」做 spam-lite，真桥头部署留后。
- ✅ 你批准的三件套刚好各对应一个流派支柱：**splash→控场/反 swarm、建筑索敌→beatdown 的『只拆塔』win-con(巨人/野猪/气球式)、status→control**。方向对。

来源：[APE-CON·Archetypes 2026](https://ape-con.com/clash-royale-deck-archetypes-master-every-playstyle-to-dominate-the-arena-in-2026/) / [GamingOnPhone·Archetypes](https://gamingonphone.com/guides/clash-royale-deck-archetypes/) / [GameRant·Deck Types](https://gamerant.com/clash-royale-all-deck-types/)

---

## 议题 4 · 数量流 vs 单兵强流 vs 速度流：数值特征与克制

**事实（CR）**
- **RPS 软三角**（个人操作可翻盘，非硬性）：
  - **Cycle/Bait → 克 → Beatdown**：out-cycle 重投入、抓对手压下 8 费坦克后的空档打反手、另一路施压。
  - **Beatdown → 克 → Swarm**：**靠 splash + 范围法术清群**、坦克顶着推过去。
  - **Swarm → 克 → Cycle/单体高 DPS**：群体淹没「没法术就处理不了群」的单体防守（原话：Mini P.E.K.K.A 克一切单体、唯独 `can't deal with swarms — it needs a spell's help`）。
- **核心货币 = 圣水优势**：5 费拆对方 7 费推 = +2 优势，优势赢局。"elixir management is more important than card levels."
- **数值签名**：swarm = 低 HP/e、高 DPS/e、分散在多体（脆）；beatdown 坦克 = 高 HP/e、低 DPS/e、集中单体；glass cannon = 高 DPS 集中 + 低 HP；cycle = 低均费、便宜灵活。

**对本项目启示（用本项目 16 卡实测折算 → 见议题 5 的表）**
- ✅ 我们**已有三类的数值签名**：skeletons/goblins = swarm（DPS/e 最高 80/68、HP/e 最低）；giant/golem/baby_dragon = beatdown（HP/e 428/400/225、DPS/e 垫底）；mini_pekka = glass cannon（DPS 集中 700HP 单体）；便宜卡(zap/log/skeletons/goblins 2 费)撑 cycle。方向对，是好底子。
- ⚠️**三角当前是断的**：`baby_dragon` 本该是反 swarm 的 splash 核心却**无溅射**、`giant/golem` 不 building-only 索敌、无 status → **beatdown 克 swarm 这条边不成立**，swarm 目前只能被法术(arrows/log)克 → swarm 会过强/或法术过载。**修好三件套 = 修好三角**。这是本次扩池最高优先的平衡目标。
- **反制矩阵（02 每张卡按此配 counter，确保『没有无敌卡』）**：swarm ← splash/范围法术；坦克 ← 高单体 DPS(mini_pekka 式) / 建筑索敌分心 / inferno 式叠伤；glass cannon ← swarm 淹 / 便宜换; 远程 ← 快速近身 / 空军绕；空军 ← 对空远程。

来源：[ClashDecks·Beatdown 攻略](https://clashdecks.com/guides/decks/beatdown-deck-strategy-guide) / [4Topic·Meta 2026](https://www.4topic.com/top-7-best-meta-decks-clash-royale-2026-win-now/)

---

## 议题 5 · 费用↔HP↔DPS↔count 平衡方法论

**事实（CR）**
- **没有公开的封闭公式**。官方**按角色/目标类型(地空)/射程/特殊能力**逐卡平衡：坦克拿血弃 DPS、glass cannon 反之、swarm 把预算摊到多体；**射程、对空、能力都会「吃掉」数值预算**，让裸 HP/DPS 看着不划算才公平。
- 实操法：拉原始 HP + DPS ÷ 费用得 per-elixir，再按「效用/目标/能力」修正。DeckShop/Gigasheet/Fandom 有全卡数值表可拉。

**对本项目启示 — 一张从本项目自己 16 卡算出来的价值锚（part.总量/费）**

| 卡 | 费 | HP/e | DPS/e | HP×DPS 积 | 射程 | 目标 | 角色读数 |
|---|---|---|---|---|---|---|---|
| golem | 7 | 428 | 8.9 | 3800(+亡语) | 近 | 地 | 大坦克 |
| giant | 5 | 400 | 16 | 6400 | 近 | 地 | 坦克 |
| baby_dragon | 4 | 225 | 15.4 | 3465 | 中 | **空** | 空中肉 |
| knight | 3 | 200 | 20.8 | 4160 | 近 | 地 | 均衡肉 |
| mini_pekka | 4 | 175 | 44 | 7700 | 近 | 地 | glass cannon |
| goblins | 2 | 120 | 68 | 8160 | 近 | 地 | swarm |
| minions | 3 | 90 | 35 | 3150 | 中 | **空** | 空 swarm |
| musketeer | 4 | 85 | 25 | 2125 | **远5.5** | 双 | 远程 DPS |
| skeletons | 2 | 80 | 80 | 6400 | 近 | 地 | 极限 swarm |
| archers | 3 | 80 | 26.7 | 2136 | **远4.5** | 双 | 对空远程 |

- **清晰规律（可直接当 02 的查表锚，且与 CR「射程/对空吃预算」原则对上）**：
  - **近战地面兵 HP×DPS 积 ≈ 4000–8000**（swarm/glass 偏高但拿脆命换）；**远程 or 空军 ≈ 2000–3500** —— **射程/对空大约吃掉一半数值预算**。新卡若给远程/对空必须按这个「targeting tax」扣数值，否则必超模。
  - swarm 走高积 + 极低单体（怕溅射）；坦克走高 HP/e + 极低 DPS/e（怕高单体 DPS）；两端都天然带 counter。
- ⚠️**建立本项目自己的『费用预算』而非搬 CR 数字**：CR 塔血/圣水回速与我方不同，绝对值不可移植；02 用上表把每费的 HP/DPS 预算 + 角色/射程/对空/splash/status 的「预算折价」定成查表，新卡先套表锚定、再用 counter 关系微调。

来源：[DeckShop·HP 表](https://www.deckshop.pro/card/hitpoints) / [DeckShop·伤害表](https://www.deckshop.pro/card/damage) / [Gigasheet·CR 数值集](https://www.gigasheet.com/sample-data/clash-royale-cards-stats)（＋本项目 `units.json`/`cards.json` 实测）

---

## 议题 6 · 中核卡池规模参考

**事实（CR）**
- 上线轨迹：软启动 **42 张**(3 档 Common/Rare/Epic) → 全球上线 **约 48 张**(+Legendary) → Champion(2021) → Evolution(2023) → 现 **约 125 张**。**8 张一副牌**。
- **没有固定「健康张数」目标**，CR 靠**每月平衡更新**压制统治卡来维持 meta 健康（也顺带驱动付费升级）。

**对本项目启示**
- ✅ **40–60 验证成立**：CR 用 ~48 张撑起了多年竞技 meta。真正约束不是总数而是**「每个流派都有能凑出 8 张 deck 的卡池」**——现有 16 张只够 ~2 个流派(swarm + 半吊子 beatdown)，太薄。
- **规模按流派覆盖倒推**，非拍总数：若定 5–6 个流派，每个流派需 win-con 1–2 + 核心 3–4 + 通用支援若干（可跨流派复用），叠加去重 → **落在 ~45–52 张**（约现有 3×），金字塔稀有度分布。
- ⚠️**别冲 100+**：CR 的 125 张是 10 年 + 大团队 + 月度平衡换来的，也伴随 power creep 与平衡负担。小团队 + 服务器权威结算下，**45–52 是深度与可维护性的甜点**；宁可少而每张有明确 counter/意图，也不多而稀。

来源：[Wikipedia·Clash Royale](https://en.wikipedia.org/wiki/Clash_Royale) / [noff.gg·125 卡](https://www.noff.gg/clash-royale/cards) / [Fandom·Cards](https://clashroyale.fandom.com/wiki/Cards)

---

## `<research_summary>`

### ✅ 被验证的设计直觉（可直接进 02 当公理）
1. **稀有度≠全面更强**——CR 官方社区明确 + 骷髅海(common)是版本答案。稀有度 gate 的是「等级下限 + 升满投入 + 机制复杂度 + 觉醒资格」，不是裸数值。
2. **觉醒优先机制、不是加数值**——正是 CR 2024-05 进化重构方向；且数值加成要克制（高费卡觉醒差距过大 = 平衡灾难）。
3. **swarm / beatdown / cycle 三类 + RPS 软克制**成立，且**本项目 16 卡已具备三类的数值签名**（好底子）。
4. **40–60 张是健康早期规模**，按流派覆盖倒推 → ~45–52 张、金字塔分布。
5. **在现有 4 档 + rank_unlocks + economy 骨架上扩展**是对的，与 CR 结构同构。
6. **每张卡必须可被 counter + 圣水优势是核心货币**——CR 反复强调。

### ⚠️ 需修正 / 加约束的直觉
1. **`base_power` 升序不能喂战斗数值**——否则高稀有度平白更强、违背原则 1。02 钉死它=战力折算/展示/匹配元数据；战斗内「同级同费不看稀有度」。
2. **Champion 第 5 档 = 主动激活技能 = 重引擎**（点按/CD/每副限一），超出已批准三件套 → 建议**暂不做**，高稀有度的机制深度由「觉醒」承载。
3. **觉醒走 rank 永久制、不抄 CR 的循环/进化槽**——后者要 cycle 计数 + evo-slot deck 系统，大改且不契合 PvE 养成；我们的 `rank_unlocks` 永久解锁已现成。
4. **CR 的 Control/Siege 依赖『法术打塔 / 建筑隔场打塔』，本引擎没有**（伤害积木不打塔）→ 真 Siege 暂缓、Control 先做「status + 高效防守」lite；蹭塔/桥头部署留后。
5. **RPS 三角当前是断的**：baby_dragon 无溅射、坦克不 building-only、无 status → 「beatdown 克 swarm」这条边不成立。**修三件套 = 修三角**，是本次扩池第一优先平衡目标（不是可选调味）。
6. **射程/对空 ≈ 吃掉一半数值预算**（本项目 16 卡实测：近战地面 HP×DPS 积 4000–8000 vs 远程/空军 2000–3500）→ 新远程/对空卡必须按 targeting tax 扣数值。

### → 交给 Phase 2（设计宪法）的直接输入
- **A 稀有度**：沿用 4 档；定「稀有度只给机制/觉醒资格、不给裸数值」的硬约束；给出 base_power/成本随新卡外推规则；Champion 暂缓的取舍写清。
- **B 流派**：swarm / beatdown / cycle 为主轴 + 补 splash 控场 / air / control-lite；每流派给费用结构 + 典型 deck 骨架 + 克/被克；标注哪些靠三件套解锁、哪些(真 Siege/桥头 spam)留后。
- **C 觉醒规则**：rank 永久制 + 机制优先 + 数值克制；3 条好原则 + 2 反例；机制映射到 ops 或三件套。
- **D 平衡查表**：用议题 5 的 per-elixir 价值锚，定每费 HP/DPS 预算 + 角色/射程/对空/splash/status 的预算折价，作为 03 每张新卡的校验尺。
