# ART_ASSETS.md — V3 美术素材规划（V3-7 美术圣经雏形）

> 状态：V3-7「美术圣经」工作草稿（正式决策 42 待落 [HISTORY.md](../HISTORY.md)）。**风格/题材已敲定**（用户 2026-06-16）；素材映射为**建议初稿**，开工 V3-7a 垂直切片时按实机核定。

## 1. 风格 & 题材（已敲定）
- **题材 = 黑暗中世纪幻想（Dark Medieval Fantasy）**：骑士 / 法师 / 亡灵 / 兽人 / 吸血鬼。**无机甲、无火器、无现代元素**。卡牌命名与整体调性一律跟随此设定。
- **美术 = 像素精细写实**（itch「Pixel Grit Series」为主轴），3-4 / 侧视角，竖屏战场。
- **调性 = 暗色地表 + 较亮角色**（对比让单位突出）。
- CR 式题材混搭收敛 → 非中世纪卡牌**改名换概念**（见 §6）。

## 2. 目录约定
- `assets/` = 工程**正式选用**素材（游戏导入/运行用）。子目录：`units / towers / terrain / map / fx / bosses`。
- `testAssets/` = **原始素材库 / 暂存**（含 `.aseprite` 源、备选、付费 bundle 全量）。**不一定入库**（见 §8 版权）。

## 3. 主风格取舍
- **采用**：Pixel Grit 角色 / 怪物 / boss（vampire_lord）+ Magical Effects（特效）+ Pre-Assembled buildings（塔）+ 暗色俯视地形系列（Lonesome **Summer** / Grand Forests / World Map）。
- **弃用**：`pixelCrawlerEntities`（Q 版 top-down，视角/风格不符）、Lonesome 的 **PICO-8 / Winter** 受限色版。

## 4. 单位映射（10 逻辑单位 → `assets/units/`）
| 逻辑 id | 素材 | 状态 | 备注 |
|---|---|---|---|
| knight | `Heavy_Knight_*`（Combat/Non-Combat/Thrust） | ✅ 直接 | 主力近战 |
| archers | `Archer_Combat/Non-Combat` | ✅ 直接 | 远程双发 |
| goblins | `goblin` / `goblin_slinger` | ✅ 直接 | 快攻群 |
| skeletons | `skelly` / `skelly_warrior` | ✅ 直接 | 廉价群 |
| mini_pekka | `axe_warrior_*` | 🔁 换皮 | 高伤近战 → 狂战士 |
| musketeer | `Mage_Hooded_BROWN_*` | 🔁 换概念 | 远程 → 女巫/法师（无火器） |
| giant | `orc_champion` | 🔁 换皮 | 坦克 → 食人魔（无真巨人） |
| minions | `fire_skull` / `wraith` | 🔁 替 | 空军 → 怨灵/火颅（单体，生成多只） |
| baby_dragon | `fire_skull` | ⚠️ 暂替 | 无真龙，暂用火颅 |
| golem | （缺）`orc_champion` 放大暂替 | ❌ 缺 | 待补 stone golem / AI |
| **敌人池（额外）** | `orc / orc_soldier / orc_archer / skelly_archer / mummy / zombie / slime / wraith` | — | roguelite 敌方多样性 |

## 5. 塔 / 地形 / 特效 / Boss
- **塔** `assets/towers/`：`building1-8`（全留待挑）→ 建议王塔取大体量（如 building1），公主塔取中等。
- **地形** `assets/terrain/` + `assets/map/`：
  | 用途 | 素材 |
  |---|---|
  | 战场地面/河/桥（近景） | Lonesome Summer：`FLOOR` / `RIVER_and_WATER_EDGES` / `COBBLESTONE_PATH`（桥）/ `WALLS_*` / `DETAIL_OBJECTS` |
  | 河水动画 | `simple_water_spritesheet`（64×48，逐帧） |
  | 战场树木点缀 | `Grand_Forests_TEMPERATE` |
  | roguelite 节点地图背景 | `world_map_tiles_SUMMER` + `Clouds-Fog-of-War`（迷雾）+ `Boat_and_Wagon_units` |
- **特效** `assets/fx/`（映射建议）：
  | 技能/事件 | 素材 |
  |---|---|
  | fireball / 火系 | `Fire_Explosion*` / `Large_Fire*` |
  | lightning | `Lightning_Blast*` / `Lightning_Energy*` |
  | zap | `Red_Lightning_Blast*` / `Elemental_Spellcasting*` |
  | heal | `Elemental_Spellcasting*`（取绿）/ `Staff_Attack_Effect` |
  | 命中火花（V3-6b 已留钩子） | `Slash_Attack_Effect_1` |
  | 死亡 / 爆炸 | `zombie_burster_*_Explosion` |
  | 冰/减速（未来积木） | `Ice-Burst*` |
- **Boss / roguelite** `assets/bosses/`：`vampire_lord_*`（IDLE/WALK/MELEE/BITE/CAST/AOE/DEATH 全套）；`vampire_spawn_fem/masc_*` 正好做 **golem 亡语裂兵**（`on_death_spawn`）。

## 6. 卡牌「黑暗中世纪化」命名（中英对照，✅ 定稿）
> ✅ 已定稿（用户 2026-06-16，按主推）。**中文名已写入 `config/cards.json` 的 `name`**；英文名 = ② 多语言的英文种子。`id` 一律不变。

| 原 id | 英文名 | 中文名 | 改动 |
|---|---|---|---|
| knight | Knight | 骑士 | 保留 |
| archers | Archers | 弓箭手 | 保留 |
| goblins | Goblins | 哥布林 | 保留 |
| skeletons | Skeletons | 骷髅兵 | 保留 |
| giant | Ogre | 食人魔 | 巨人→食人魔 |
| mini_pekka | Berserker | 狂战士 | 去机甲 |
| musketeer | Sorceress | 女巫 | 去火器 |
| minions | Wraiths | 怨灵 | 飞兵→怨灵 |
| baby_dragon | Cinder Skull | 余烬火颅 | 去龙（待补真龙可改回） |
| golem | Undead Colossus | 亡灵巨像 | 去石头人（待补素材） |
| fireball | Fireball | 火球术 | 保留 |
| arrows | Arrow Volley | 箭雨 | 保留 |
| zap | Spark | 电火花 | 微调 |
| lightning | Lightning | 闪电术 | 保留 |
| log | Rolling Boulder | 滚石 | 滚木→滚石（更暗黑） |
| heal | Mending | 治愈术 | 保留 |

## 7. 缺口 & 补法
- **golem 石头人 / 真巨人 / 真龙**：当前无对应 → 换皮（重甲兽人放大 / 火颅）暂行；后续找同风格素材或 AI 生成补齐。
- **地形↔角色明暗协调**：地形偏暗、角色偏亮，切片实测；必要时调地形亮度或给角色加描边/底影。
- **视角统一**：全部按 3-4/侧视；弃用的 top-down 包不混入。

## 8. License / Credits（⚠️ 入库前必读）
- **地形**（Lonesome / Grand Forests / World Map）：标注 **No Attribution Required** → 可商用、免署名、可再分发。
- **Pixel Grit bundle**（角色 / 特效 / boss）：itch **付费** bundle。付费像素 bundle 的 EULA 通常 = **可用于游戏成品，禁止再分发源素材**。
- ⚠️ **把付费源素材放进公开 GitHub = 再分发，可能违反 EULA**。提交前须决定：(a) 仓库转私有；(b) `.gitignore` 掉 `testAssets/`（及可能 `assets/`）；(c) 仅提交可分发部分（No-Attribution 地形）。
- 发行前补 `CREDITS` 清单。

## 9. 多语言（i18n）— ✅ 已实现（V3-7②，见 HISTORY 决策 43）
> 实际方案 = `config/i18n.json` + `I18n` autoload 运行时构建 `Translation`（非 CSV 编辑器导入，headless 友好）+ Fusion Pixel 像素中文字体 + 设置页中英切换/存盘、默认中文。下方为初版规划，存档。
- **方案**：Godot `TranslationServer` + CSV/`.po`；UI / 卡牌 / 提示文本走翻译 key。
- **范围**：提取 view 层硬编码英文 → key；卡牌名用 §6 中英；设置界面加**中/英切换**并存盘。
- **建议**：作为**独立一步**（V3-7 期或紧随），不混进素材整理；开工前单独确认范围与排期。

## 10. 待决策
1. §6 卡牌改名定稿。
2. 塔选哪两个 `building`。
3. 多语言：何时做、是否本阶段就上切换功能。
4. **git 提交策略**（§8 版权）。
