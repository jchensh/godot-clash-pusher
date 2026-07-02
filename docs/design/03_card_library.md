# 03 · Phase 3 卡库（16 → 48）

> 依 [02_design_constitution.md](02_design_constitution.md) 施工。**新增 32 张**，与现有 16 张合计 **48**，稀有度金字塔 **common 18 / rare 14 / epic 10 / legendary 6**。
> 数值 = 套 §D 角色模板锚定的**示意值·待 V5-S8 probe 平衡**（同项目 `card_progression.json` 惯例）。表可直转 `cards.json` / `units.json`。

<tldr>
1. **+32 张达 48、金字塔 18/14/10/6**：common 补群卡/精灵/廉价 win-con，rare 补 win-con/splash/控场，epic 补签名机制(splash 法师/大群/空军 win-con)，legendary 5 张各一个专精 marquee 机制 + 明确脆弱面。6 流派全部凑得出完整 deck。
2. **三件套 tech_debt 收敛为 3 大项**（splash / building-target / status）+ 2 小项（法术在目标点造兵、精灵简化）+ 2 延后（death_aoe / ramp 仅作觉醒）；每张用到的卡都在 `<tech_debt>` 归组，无隐藏成本。
3. **建议顺带 retrofit 两处**（`baby_dragon` 加小 splash 修好"空中反 swarm"、`giant`/`golem` 可选改 building-target 变真 beatdown win-con）——这是让 RPS 三角闭合的收尾，但会改现有行为，**列出待你拍**。
</tldr>

---

## 规模与覆盖自检

| 稀有度 | 现有 | 新增 | 合计 | 目标 |
|---|---|---|---|---|
| common | 6 | 12 | **18** | 18 ✓ |
| rare | 5 | 9 | **14** | 14 ✓ |
| epic | 4 | 6 | **10** | 10 ✓ |
| legendary | 1 | 5 | **6** | 6 ✓ |
| **合计** | 16 | 32 | **48** | 48 ✓ |

**流派覆盖**（✓=可凑完整 8 张 deck，◐=核心 2–3 张）：数量流 Swarm ✓ / 单兵强流 Beatdown ✓ / 速度流 Cycle ✓ / 控场流 Splash-Control ✓ / 空中流 Air ✓ / 诱饵流 Bait-lite ◐。真 Siege / 桥头 Spam 不出卡（§B 暂缓）。

**世界观/命名**：沿用现有暗黑奇幻混搭（骑士/哥布林/怨灵/亡灵/余烬）。新卡走同调：亡骨/寒冰/雷电/熔岩/凤凰系。

> 数值列约定：`HP`/`dmg` 为**单体**；`间隔`=attack_speed(秒)；`DPS`=dmg÷间隔（单体）；`count`>1 时队伍量=×count。`自身`=target_type，`打击`=attack_targets。特殊字段即 §0.1 三件套 schema。

---

## COMMON（+12）— 地基/群卡/廉价件，无 signature 机制

### 数据表（转 units.json / cards.json）
| id | 中文名 | 费 | count | HP | dmg | 间隔 | DPS | 射程 | 移速 | 自身 | 打击 | 特殊字段 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| spear_goblins | 长矛哥布林 | 2 | 3 | 45 | 38 | 1.0 | 38 | 4.0 | 1.6 | ground | both | — |
| bats | 血蝠群 | 2 | 5 | 35 | 32 | 1.0 | 32 | 1.5 | 2.4 | air | both | — |
| barbarians | 蛮兵 | 5 | 5 | 280 | 58 | 1.3 | 45 | 1.2 | 1.5 | ground | ground | — |
| minion_horde | 怨灵大军 | 5 | 6 | 90 | 35 | 1.0 | 35 | 2.0 | 2.2 | air | both | 复用 minion_body |
| ice_spirit | 冰灵 | 1 | 1 | 60 | 30 | 1.0 | 30 | 1.5 | 2.6 | ground | both | on_hit_status slow(dur1.0,mag0.5) |
| fire_spirit | 火灵 | 1 | 1 | 60 | 80 | 1.0 | 80 | 1.5 | 2.6 | air | both | splash_radius 1.5 |
| electro_spirit | 电灵 | 1 | 1 | 60 | 24 | 1.0 | 24 | 2.0 | 2.6 | ground | both | on_hit_status stun(dur0.5) |
| squire | 见习骑士 | 2 | 1 | 340 | 50 | 1.2 | 42 | 1.2 | 1.6 | ground | ground | — |
| axe_thrower | 掷斧手 | 3 | 1 | 160 | 70 | 1.1 | 64 | 4.5 | 1.6 | ground | ground | 地面专属远程(无对空) |
| cave_spiders | 洞穴蛛群 | 3 | 4 | 70 | 40 | 1.0 | 40 | 1.0 | 2.8 | ground | ground | — |
| rock_shower | 石雨(法术) | 2 | — | — | — | — | — | — | — | — | — | aoe_damage r2.2/125 |
| bone_ram | 亡骨冲车 | 4 | 1 | 650 | 120 | 1.5 | 80 | 1.2 | 2.2 | ground | ground | target_priority buildings + death_spawn 2 skeleton_body |

### 设计表
| id | 流派 | 机制一句话 | 设计意图 / 克谁 | 对标 | 觉醒 | TD |
|---|---|---|---|---|---|---|
| spear_goblins | Swarm/Bait | 3 只远程哥布林，脆 | 便宜对空+骚扰；克 glass/远程 · 被任意小法术一扫 | archers+goblins | — | — |
| bats | Air/Swarm | 5 只极脆飞蝠 | 便宜对空群；克无对空兵 · 被 arrows/zap 秒 | minions↓ | — | — |
| barbarians | Swarm/Beatdown | 5 只中甲近战墙 | 防大兵/顶线；克单体坦克 · 被 splash/fireball | knight×n | — | — |
| minion_horde | Air/Swarm | 6 只飞行群 | 空中 DPS 爆发;克地面无对空推 · 被 arrows | minions×2 | — | — |
| ice_spirit | Cycle | 命中冻一下(减速) | 1 费循环+减速起手;拖延推进 · 被任意 aoe | skeletons↓ | — | status |
| fire_spirit | Cycle/anti-swarm | 撞上溅射爆一下 | 1 费清群;克 swarm · 被单体高血兵无视 | — | — | splash |
| electro_spirit | Cycle | 命中短眩晕 | 1 费重置攻击/救火;克 inferno 系 · 被高血兵 | — | — | status |
| squire | Cycle/防守 | 廉价小肉盾 | 2 费顶线/循环;克单体 win-con · 被群/glass | knight↓ | — | — |
| axe_thrower | 支援 DPS | 地面远程(不打空) | 便宜远程输出;克地面推 · 被空军无解/近身 | musketeer↓ | — | — |
| cave_spiders | Swarm | 4 只极速蛛 | 绕后/包围单体;克坦克/远程 · 被 splash | goblins | — | — |
| rock_shower | Control | 小范围直伤 | 廉价清群/收尾;克 swarm · (法术无 counter，靠费用) | arrows/log | — | — |
| bone_ram | Cycle/Beatdown | 只冲塔+亡语裂骷髅 | 便宜 win-con;直取塔 · 被建筑分心/群拦 | giant↓fast | — | building-target |

---

## RARE（+9）— win-con / splash / 控场件

### 数据表
| id | 中文名 | 费 | count | HP | dmg | 间隔 | DPS | 射程 | 移速 | 自身 | 打击 | 特殊字段 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| royal_giant | 皇家巨像 | 5 | 1 | 1800 | 150 | 1.5 | 100 | 5.0 | 1.1 | ground | ground | target_priority buildings（远程只轰塔） |
| hog_rider | 野猪骑士 | 4 | 1 | 1000 | 120 | 1.6 | 75 | 1.2 | 2.6 | ground | ground | target_priority buildings |
| valkyrie | 瓦尔基里 | 4 | 1 | 900 | 90 | 1.5 | 60 | 1.2 | 1.5 | ground | ground | splash_radius 1.5(360°) |
| bomber | 投弹亡灵 | 2 | 1 | 130 | 80 | 1.9 | 42 | 4.5 | 1.6 | ground | ground | splash_radius 1.5 |
| mega_minion | 巨型怨灵 | 3 | 1 | 340 | 120 | 1.5 | 80 | 2.0 | 1.8 | air | both | — |
| goblin_gang | 哥布林帮 | 3 | 3+2 | — | — | — | — | — | — | — | — | 多积木:spawn 3 goblin_body + 2 spear_goblin |
| battle_ram | 战锤冲车 | 4 | 1 | 700 | 100 | 1.5 | 67 | 1.2 | 2.4 | ground | ground | target_priority buildings + death_spawn 2 barbarian |
| giant_snowball | 寒冰球(法术) | 2 | — | — | — | — | — | — | — | — | — | aoe_damage r2.0/110 + status slow(dur1.5,mag0.35) |
| goblin_barrel | 哥布林桶(法术) | 3 | 3 | — | — | — | — | — | — | — | — | spawn 3 goblin_body @目标点 |

### 设计表
| id | 流派 | 机制一句话 | 设计意图 / 克谁 | 对标 | 觉醒 | TD |
|---|---|---|---|---|---|---|
| royal_giant | Beatdown | 远程只轰塔的坦克 | 隔一小段距离刷塔;克 control 站桩 · 被建筑/高单体 DPS 融 | giant+musketeer | — | building-target |
| hog_rider | Cycle/Beatdown | 快速只冲塔 | 循环 win-con 抓空档;克慢速 deck · 被建筑分心+群拦 | mini_pekka↕ | — | building-target |
| valkyrie | Control | 360° 溅射肉盾 | 反 swarm 核心+顶线;克所有地面群 · 被空军/单体高 DPS | knight+splash | — | splash |
| bomber | Control | 远程溅射炸群(脆) | 便宜清群输出;克 swarm · 被任意小法术(HP130 一扫)/空军 | archers+splash | — | splash |
| mega_minion | Air | 中甲飞兵打空/地 | 稳定对空+空中支援;克空军/远程 · 被对空群/集火 | baby_dragon↓ | — | — |
| goblin_gang | Swarm/Bait | 近战+远程混合群 | 全能诱饵/换血;克单体 win-con · 被 2 连小法术 | goblins+spear | — | — |
| battle_ram | Beatdown/spam | 撞塔+死后裂 2 蛮兵 | 桥头压制的便宜 win-con;克远程 deck · 被建筑/群 | hog+deathspawn | — | building-target |
| giant_snowball | Control | 小直伤+减速+微退 | 清脆群+拖 win-con;克 swarm/救火 · (法术) | log+status | — | status |
| goblin_barrel | Bait | 目标点砸出 3 哥布林 | 诱饵 win-con 直取塔;克无 splash 防守 · 被 log/arrows | goblins-as-spell | — | 法术目标点造兵 |

---

## EPIC（+6）— 签名机制（具备觉醒资格）

### 数据表
| id | 中文名 | 费 | count | HP | dmg | 间隔 | DPS | 射程 | 移速 | 自身 | 打击 | 特殊字段 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| wizard | 巫师 | 4 | 1 | 340 | 130 | 1.4 | 93 | 5.0 | 1.6 | ground | both | splash_radius 1.8 |
| executioner | 行刑者 | 5 | 1 | 620 | 90 | 1.6 | 56 | 4.5 | 1.5 | ground | both | splash_radius 2.5(大) |
| balloon | 地狱气球 | 5 | 1 | 1100 | 400 | 2.5 | 160 | 1.5 | 1.8 | air | ground | target_priority buildings（空中只砸塔） |
| skeleton_army | 骷髅大军 | 4 | 14 | 40 | 40 | 1.0 | 40 | 1.0 | 2.4 | ground | ground | 复用 skeleton_body ×14 |
| phoenix | 不死凤凰 | 4 | 1 | 600 | 90 | 1.3 | 69 | 2.0 | 2.0 | air | both | death_spawn 1 phoenix_reborn(HP300/dmg60) |
| freeze | 冰冻术(法术) | 4 | — | — | — | — | — | — | — | — | — | status freeze r3.0 dur2.5 |

### 设计表
| id | 流派 | 机制一句话 | 设计意图 / 克谁 | 对标 | 觉醒概念(一句话·详见04) | TD |
|---|---|---|---|---|---|---|
| wizard | Beatdown 支援/Control | 远程强溅射输出 | 后排清群+主力 DPS;克 swarm · 被 fireball/近身/空军集火 | musketeer+splash | 溅射附带小灼烧地带(status) | splash |
| executioner | Control | 大范围溅射清场 | 阵地清群;克重 swarm/群冲 · 被单体坦克/glass | musketeer↑splash | 斧回旋=去程回程两段命中 | splash |
| balloon | Air/Beatdown | 空中只砸塔巨伤 | 空中 win-con 高威胁;克无对空 deck · 被对空群集火 | giant-air-only | 落地/被击破留 death 炸弹(death_aoe) | building-target+air |
| skeleton_army | Swarm/Bait | 14 骷髅海 | 淹单体/诱大法术;克单体 win-con · 被任意 aoe 全清 | skeletons×3.5 | 召唤时附带 1 亡骨巨兵领队 | — |
| phoenix | Air | 死后化蛋重生一次 | 粘性空中支援;克远程/空军 · 被两波集火/对空群 | baby_dragon+revive | 重生体满血+短无敌帧 | — |
| freeze | Control | 范围冻结 2.5s | 定身一波防守/强开;克密集推进 · (法术·须留手) | lightning→control | 冻结附带小伤害 | status(freeze) |

---

## LEGENDARY（+5）— 专精 marquee，每张一个独特机制 + 明确脆弱面

### 数据表
| id | 中文名 | 费 | count | HP | dmg | 间隔 | DPS | 射程 | 移速 | 自身 | 打击 | 特殊字段 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| lava_hound | 熔岩魔像 | 7 | 1 | 3400 | 40 | 1.3 | 31 | 2.0 | 1.0 | air | ground | target_priority buildings + death_spawn 6 lava_pup(HP110/dmg35 air·both) |
| ice_wizard | 寒冰法师 | 3 | 1 | 240 | 30 | 1.5 | 20 | 5.0 | 1.6 | ground | both | splash_radius 1.8 + on_hit_status slow(mag0.35 持续) |
| electro_wizard | 电法师 | 4 | 1 | 340 | 90 | 1.8 | 50 | 4.5 | 1.6 | ground | both | on_hit_status stun(0.5) + 多积木落地 aoe r2.0/90 |
| princess | 公主 | 3 | 1 | 220 | 120 | 3.0 | 40 | 9.0 | 1.6 | ground | both | splash_radius 1.5（超远程狙击） |
| inferno_dragon | 地狱飞龙 | 4 | 1 | 700 | 200 | 1.0 | 200 | 3.5 | 1.9 | air | both | 单体超高 DPS(反坦克);ramp 留觉醒 |

### 设计表
| id | 流派 | 机制一句话 | 设计意图 / 克谁 | **脆弱面(counter 锚)** | 对标 | 觉醒概念(详见04) | TD |
|---|---|---|---|---|---|---|---|
| lava_hound | Air/Beatdown | 空中只砸塔大坦+死后裂 6 火犬 | 空中 beatdown 顶级 win-con | 直伤极低、慢、纯空;对空集火先融本体再清犬 | golem-air | 火犬升级为会喷火的小龙 | building-target+air |
| ice_wizard | Control | 远程溅射+永久减速光环 | 控场支柱:减速拖住整波推进 | 血薄伤低、纯辅助无输出 | musketeer↓+splash+slow | 减速叠加至短冻结 | splash+status |
| electro_wizard | Control/反空 | 命中眩晕+落地电爆 | 重置 inferno/救火/反空 utility | glass 血薄、DPS 低 | musketeer+stun | 眩晕变连锁 2 目标 | status(stun) |
| princess | Bait/chip | 超远程(9)溅射狙击 | 隔场点名清群/骚扰塔线 | HP220 任意一发法术/近身即死 | archers 超远程 splash | 箭矢命中留燃烧地带 | splash(+超远程) |
| inferno_dragon | Air/反坦克 | 单体超高 DPS 空中融坦 | 专克大坦(golem/giant/RG) | 只打单体、被 swarm/分心废掉 | baby_dragon 反坦 | DPS 随持续命中 ramp 递增 | —(ramp=觉醒) |

---

## `<tech_debt>` — 引擎扩展成本（按 §0.1 schema 归组）

### 3 大核心项（三件套，已获批；本期前置引擎工作）
| # | 扩展 | schema 落点 | 触及卡 | 引擎工作量估计 |
|---|---|---|---|---|
| T1 | **splash 溅射** | units.json `splash_radius`；`arena.gd` 攻击结算阶段：命中 `current_target` 后对其 `splash_radius` 内合法敌方同施伤 | fire_spirit, valkyrie, bomber, wizard, executioner, ice_wizard, princess（+retrofit baby_dragon） | **中**：仅改攻击结算一处，收集式施伤，确定性易单测 |
| T2 | **building-target 只索敌建筑** | units.json `target_priority:"buildings"`；`arena.gd` `_acquire_target`：该类跳过敌方单位、直锁 `nearest_enemy_tower`（仍可选保留 aggro 拉扯或完全无视） | bone_ram, royal_giant, hog_rider, battle_ram, balloon, lava_hound（+可选 retrofit giant/golem） | **中**：`_acquire_target` 分支 + 索敌优先级；注意与 aggro/分心的交互要定清 |
| T3 | **status 状态效果** | 施加源 `on_hit_status`、spell 块 `status:{kind,dur,mag}`；`unit.gd` 加状态计时层(slow 改 move/attack_speed、stun/freeze 停动/攻)，`arena.gd` tick 递减 | ice_spirit, electro_spirit, giant_snowball, freeze, ice_wizard, electro_wizard | **中–高**：Unit 加状态字段+tick 衰减+对移动/攻击/冷却的钩子；确定性需固定结算序 |

### 2 小项
| # | 扩展 | 触及卡 | 说明 |
|---|---|---|---|
| T4 | **法术在目标点造兵** | goblin_barrel | 现 `spawn_unit` 已能在 pos 造兵；需确认「法术类卡可落敌方半场目标点」的 `Player` 部署校验（纯法术不受己方半场限，`arena.gd:97` 注释已留口子）。**小改** |
| T5 | **精灵简化**（不做真 suicide） | ice/fire/electro_spirit | 简化为「低血快兵，撞上打一下靠反击/塔火自然死」，**不新增 max_attacks**；若要"打一下即消失"再评估。**零–小改** |

### 2 延后（仅作觉醒，不进基础卡）
| # | 扩展 | 用途 | 决定 |
|---|---|---|---|
| T6 | **death_aoe 死亡范围伤** | balloon 觉醒(落地炸弹) | 基础 balloon 不含;觉醒才需，Phase 4 标注、S8 后做 |
| T7 | **ramp-up 持续命中递增伤** | inferno_dragon 觉醒 | 基础飞龙用固定高 DPS;ramp 作其签名觉醒，延后 |

> 明确**不做**（超三件套、无卡依赖）：真建筑类(寿命/周期造兵)、敌方半场自由部署(真桥头 spam/矿工)、隐身、护盾、连锁弹射(除 electro_wizard 觉醒)、DoT 中毒、法术打塔。

---

## Retrofit 建议（改现有行为，**待你拍板**）

| 项 | 改动 | 收益 | 风险 |
|---|---|---|---|
| **R-A** `baby_dragon` 加 `splash_radius 1.5` | 从"单体飞行肉"→"空中反 swarm" | **修好 RPS 三角里"空中清群"这条边**（01/02 核心目标） | 小幅增强现有 epic，需 probe 复衡；推荐做 |
| **R-B** `giant`/`golem` 改 `target_priority:buildings` | 变"真·只拆塔 beatdown win-con"（现在会打兵） | 更正统 beatdown 手感、与新 win-con 一致 | **改现有 PvE 平衡与 AI 预期**，影响面较大；建议先 R-A，R-B 单独评估 |

---

## 交给 Phase 4 的清单
1. **觉醒设计**：为**全部 epic + legendary（新旧共 16 张）**设计 signature 觉醒——新 6 epic + 5 legendary 概念已在上表起草；旧 4 epic(musketeer/baby_dragon/lightning/heal)+1 legendary(golem) 待补。common/rare 保持轻量 rank_unlock（count+/radius+/stat）。
2. **meta 分析**：2–3 个预期强势流派组合 + 各自 counter + 兜底卡。
3. **上线后平衡原则**：何时调数值 vs 调机制。
4. 觉醒里凡用 T6/T7 的显式标注延后依赖。
