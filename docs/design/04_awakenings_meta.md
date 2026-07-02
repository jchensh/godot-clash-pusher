# 04 · Phase 4 觉醒设计 + Meta 分析 + 平衡原则

> 依 [02_design_constitution.md](02_design_constitution.md) §C 觉醒规则 + [03_card_library.md](03_card_library.md) 卡库施工。
> **前提基线**：R-A/R-B 已采纳 → `baby_dragon` 带 `splash_radius`、`giant`/`golem` 为 `target_priority:buildings`；本阶段觉醒建于此。
> 觉醒 = **rank 永久解锁**（非 CR 循环制）；载体 `card_progression.rank_unlocks`。**机制优先、保留脆弱面、高费小差距**（§C）。

<tldr>
1. **16 张 epic+legendary 全部给了 rank3 signature 觉醒 + rank2 轻量解锁**，每个都"改交互不改数字"（新增一种能 counter 的对象 / 一种被 counter 的方式）、且**保留原脆弱面**；映射到已批三件套 ops，仅 balloon(death_aoe/T6)、inferno(ramp/T7)、electro_wizard(chain 例外) 3 处触延后机制、已显式标注。
2. **Meta 预测 3 强势组合**：熔岩气球空军(Lavaloon) / 野猪循环(Hog Cycle) / 骷髅诱饵(Bait)——各给 counter + 兜底卡；并点出**两处结构性平衡隐患**（无防御建筑→只拆塔 win-con 缺"拉扯"counter；空军池太薄则 Lavaloon 过强），给了对冲手段。
3. **上线平衡原则 = 最小杠杆优先**（费用→数值→数量→机制），§D CV 当护栏，probe 数据驱动而非手感，**永不靠"删掉 counter"来 buff**。
</tldr>

---

## 一、觉醒设计（16 张 epic + legendary）

> 读法：**rank3 = signature 觉醒**（marquee 机制）；**rank2 = 轻量解锁**（数值/count/radius，接现有 scaffolding）。common/rare 不在此（只保留轻量 rank_unlock）。
> 映射列：`ops`=现成积木操作(零引擎)；`T1/T2/T3`=三件套；`T6/T7`=延后机制(仅此觉醒依赖)。

### EPIC（10）

| 卡 | 觉醒前(base) | **rank3 signature 觉醒** | rank2 轻量 | 交互如何改变 | 为何不破坏平衡（脆弱面保留） | 映射 |
|---|---|---|---|---|---|---|
| **musketeer** 女巫 | 远程单体纯输出 | **破法弹**：命中附带 20% 减速(slow) | dmg+ | 从纯 DPS → 能**独自风筝**坦克/快兵，新增"拖延"作用 | 仍 glass HP340，被 fireball/近身/空袭秒 | T3(slow)+ops |
| **baby_dragon** 余烬火颅 | 空中小 splash(R-A) | **烈焰吐息**：splash_radius+1.0 且命中区域减速(slow) | splash+0.5 | 从"空中肉"→**空中群锁**，能定住整波 swarm | 被 musketeer/mega_minion 集火融，纯空 | T1+T3 |
| **lightning** 闪电术 | 单体点伤 280 | **雷暴**：命中点附带小范围眩晕(stun aoe) | dmg+60 | 从单体伤→**防守定身**核爆，改变用途 | 法术无场面，4 费须精准掐时机 | T3(stun)+ops |
| **heal** 治愈术 | 一次性范围治疗 | **战意**：治疗同时给友军 30% 加速 3s(haste) | 治疗量+/radius+ | 从防守续航→**进攻提速**推穿防线的节奏工具 | 无场面、需配一波推进才有价值 | T3+(友方 buff) |
| **wizard** 巫师 | 远程强 splash | **烈焰风暴**：溅射区域减速(slow) | splash/dmg+ | splash DPS →**splash+区域控**，锁 swarm/推进 | glass HP340，被冲脸/fireball | T1+T3 |
| **executioner** 行刑者 | 大范围 splash | **行刑领域**：大 splash 全体减速(slow) | splash+0.5 | 把整波推进拖成慢动作，阵地战核心 | 被单体坦克/glass 近身、慢 | T1+T3 |
| **balloon** 地狱气球 | 空中只砸塔巨伤 | **临空爆弹**：被摧毁时原地范围爆炸(death_aoe) | dmg/HP+ | 击破它也**惩罚防守群**，逼你远离塔拦截 | 提前集火拦下则炸弹浪费；纯空慢 | **T6(延后)** |
| **skeleton_army** 骷髅大军 | 14 骷髅海 | **亡骨领主**：多召唤 1 骷髅王(中甲 splash 领队) | count+2 | swarm 有了**抗溅射锚点**，不再一发全清 | 王死于单体、14 只仍被 aoe 清 | ops(多积木)+T1 |
| **phoenix** 不死凤凰 | 死后化蛋重生一次 | **烈焰重生**：重生体满配 + 落地范围减速(slow) | 重生体 HP+ | 击杀一次触发**防守减速波 + 满血二次**，逼双杀 | 纯空、两波集火即清 | ops(unit_field)+T3 |
| **freeze** 冰冻术 | 范围冻结 2.5s | **绝对零度**：冻结期同时造成范围伤(damage) | dur/radius+ | 从纯定身→**定身+清脆群**软移除 | 法术无场面、须留手掐时机 | ops(多积木)+T3 |

### LEGENDARY（6）

| 卡 | 觉醒前(base) | **rank3 signature 觉醒** | rank2 轻量 | 交互如何改变 | 为何不破坏平衡（脆弱面保留） | 映射 |
|---|---|---|---|---|---|---|
| **golem** 亡灵巨像 | 只拆塔大坦(R-B)+死裂 2 哥布林 | **崩解**：死裂物升级为 2 石心魔像(中坦·只拆塔) | 裂物 HP+ | 推进**死后不停**——魔像续接冲塔 | 仍慢/贵、无对空无清群、极依赖后排 | ops(unit_field→只拆塔裂物)+T2 |
| **lava_hound** 熔岩魔像 | 空中只拆塔大坦+死裂 6 火犬 | **熔火降临**：火犬升级为远程喷火小龙(带 splash) | 火犬 count/HP+ | 击破后裂出**空中 splash 群**，反杀你的对空 swarm | 慢、直伤极低、纯空、须先融本体 | ops(unit_field)+T1 |
| **ice_wizard** 寒冰法师 | 远程 splash+持续减速 | **凛冬将至**：对同一目标减速叠层，满层短冻结(slow→freeze) | slow mag+ | 可**独锁一个 win-con**（hog/RG）升级到定身 | HP240 glass、伤极低、纯辅助 | T3(叠层, 扩展) |
| **electro_wizard** 电法师 | 命中眩晕+落地电爆 | **连锁闪电**：攻击连锁跳第 2 目标，双眩晕 | 眩晕时长+ | 能**同时锁两个**威胁/两只 swarm | glass HP340、DPS 低 | **chain(例外)**+T3 |
| **princess** 公主 | 超远程(9) splash 狙击 | **烈焰箭雨**：命中点留短暂燃烧减速地带(slow field) | splash/range+ | 从点名 chip→**隔场封锁一条 lane** 的区域控 | HP220、任意法术/近身即死 | T1+T3(地带) |
| **inferno_dragon** 地狱飞龙 | 空中固定高 DPS 反坦 | **熔核过载**：对同一目标 DPS 每秒递增(ramp)，换目标重置 | base DPS/HP+ | 从固定反坦→**越锁越猛的融坦**，但被打断即归零 | reset-on-distract 就是它的 counter；被 swarm 废 | **T7(延后)** |

**小结**：16 个觉醒无一是"纯数值膨胀"（§C 反例1），无一抹掉原 counter（§C 反例2）。**触延后机制仅 3 处**：balloon(T6 death_aoe)、inferno(T7 ramp)、electro_wizard(chain 例外，Phase3 tech_debt 已列)——其余全部 ops + 三件套可表达。**ice_wizard 的"减速叠层→冻结"、heal 的"友军加速"是对 T3 status 的小扩展**（叠层计数 / 友方 buff 方向），实现时按 T3 一并做。

---

## 二、Meta 分析

### 预期 3 大强势组合 + counter + 兜底

**① Lavaloon 熔岩气球空军（Air-Beatdown）**
- 骨架：lava_hound + balloon + mega_minion + phoenix + baby_dragon + 对空小法术 + 便宜防守 ×2。均费偏高。
- 强在哪：双空中只拆塔 win-con，**没有对空的地面 deck 直接被打穿**；lava 顶血、balloon 砸塔、死裂物二次收割。
- **Counter**：对空集火——`musketeer`(觉醒变减速狙)/`mega_minion`/`minion_horde`/`electro_wizard`(眩晕打断 balloon)/`inferno_dragon`(融 lava 本体)。
- **兜底（防其过强）**：保证对空池能**费用换赢**空军 win-con；若数据显示 Lavaloon 压制 → 先调 lava/balloon 数值(HP/费)，勿动机制。

**② Hog Cycle 野猪循环（Cycle）**
- 骨架：hog_rider + ice_spirit + electro_spirit + skeletons + 小法术 ×2 + valkyrie + musketeer。均费最低。
- 强在哪：2–3 秒摸回 hog、反复只拆塔 chip，抓对手重卡轮空。
- **Counter**：便宜 swarm 围杀(skeletons/goblins body-block)+ 高单体 DPS(mini_pekka)+ valkyrie 顶。
- **兜底**：⚠️见下"结构隐患 A"——**无防御建筑做"拉扯"**，只拆塔 win-con 的 counter 偏弱，需靠 body-block + 塔火，balance 上要盯。

**③ Bait 骷髅诱饵（Bait-lite）**
- 骨架：goblin_barrel + skeleton_army + spear_goblins + goblin_gang + princess + 便宜件。
- 强在哪：怕小法术的卡堆满，逼对手浪费 log/arrows/zap，后手核心吃塔。
- **Counter**：**不靠法术的 splash**——valkyrie/wizard/executioner/`baby_dragon`(觉醒空中清群)。这正是 RPS"splash 克 swarm"。
- **兜底**：splash 池够强则 bait 不失控；bait 在 **PvE 对 AI 价值打折**（AI 法术追踪弱，S8 遭遇里控制 bait 型 encounter 占比）。

### ⚠️ 两处结构性平衡隐患（须盯 + 已给对冲）

| # | 隐患 | 根因 | 对冲手段 |
|---|---|---|---|
| **A** | **只拆塔 win-con（hog/RG/ram/bone_ram/balloon/lava）缺"建筑拉扯"counter** | 本期不做防御建筑类；CR 里靠 cannon/tesla 拉走 hog，我们没有 | ①建议 `target_priority:buildings` 做成**"优先建筑但仍受 aggro 拉扯"**软版（T2 schema 已留可选关）→ 恢复"用兵分心"这条 counter；②或纯只拆塔 + 靠 body-block/塔火，数值上压 win-con HP。**先上软版**，probe 后定 |
| **B** | **空军(Lavaloon)潜在过强** | 空中只拆塔 + 死裂物，若对空池薄则无解 | 对空覆盖已铺：musketeer(觉醒)/mega_minion/minion_horde/bats/electro_wizard/inferno_dragon——保证其中 ≥2 能费用换赢；不足则加对空数值，勿加机制 |

---

## 三、上线后平衡调优原则

**核心：最小杠杆优先，机制是最后手段。**

1. **先调数值、后调机制**——杠杆从轻到重：**费用 → 单体数值(HP/DPS) → 数量/count → 机制**。前三档可逆、低风险，用 §D CV 当护栏（改完仍须落在角色模板 CV/e 带内）。机制改动稀有、慎用。
2. **何时调数值**：卡的**角色与 counter 关系仍健康**、只是强/弱于预期 → 在 §D 预算内调 HP/DPS/费/count。占 95% 的平衡工作。（例：hog 过强 → −HP 或 +0.5 费。）
3. **何时调机制**：卡**找不到 counter / 打破 RPS / 数值怎么调都不好玩** → 说明交互本身坏了，才改机制（给它加一个脆弱面、改索敌、调觉醒）。（例：只拆塔若被证明无解 → 改"软版可拉扯"= 机制改。）
4. **铁律（不可违反）**：
   - **永不靠"删掉 counter"来 buff**（违反 §C 原则2、造无敌卡）。
   - 觉醒平衡先动 rank2 轻量层，再动 signature；高费卡觉醒差距保持小（§C，CR 血泪）。
   - `base_power` 只随稀有度/费用外推，**不参与战斗数值**。
5. **数据驱动而非手感**：用 V5-S8 probe harness 的**出场率 + 胜率 + 费用差**数据定位问题卡；批量 pass（CR 月度节奏），每次改动记 HISTORY，可回滚。
6. **新机制上线节奏**：三件套 → retrofit(R-A/R-B) → 新卡数值铺入 → 觉醒(signature) → T6/T7 延后件。**每层跑通 + probe 平衡再上下一层**，不一次性全开。

---

## 落地实施建议顺序（交给工程 / PLAN_V5 排期，非本设计文档强制）
1. **引擎三件套 T1/T2/T3**（含 T3 的叠层/友方 buff 小扩展）+ 单测。
2. **retrofit R-A/R-B** + probe 复衡现有 16 张。
3. **新卡数值铺入** `cards.json`/`units.json`/`card_progression.json`（32 张，示意值）+ config_loader 校验（新增 `splash_radius`/`target_priority`/`on_hit_status`/status 块的 schema 校验）。
4. **觉醒 signature** 填入 `rank_unlocks`（epic+legendary 16 张）。
5. **probe 平衡 pass**（§D CV + 出场/胜率）→ 定稿数值。
6. **T6/T7 延后件**（balloon 爆弹 / inferno ramp）随后续版本。

> 四阶段设计交付完成：[01 调研](01_research.md) → [02 宪法](02_design_constitution.md) → [03 卡库](03_card_library.md) → 04 觉醒+Meta。设计层自洽：稀有度(投入轴不给裸强度)×流派(RPS 靠三件套闭合)×觉醒(机制优先+保脆弱面) 三维无内部矛盾，可直转数据与工程排期。
