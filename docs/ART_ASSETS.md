# ART_ASSETS.md — V3 美术素材规划（V3-7 美术圣经雏形）

> 状态：**美术圣经定稿**（V3-7b-6，决策 42 升级）。风格/题材已敲定（用户 2026-06-16）；单位/塔/FX/地形/卡面映射经 **V3-7b 量产实机核定**，权威实现见 `view/sprite_db.gd`（单位 manifest）+ `view/battle_scene.gd`（绘制/FX/投射物/地形/卡面）。后续加单位/换皮照本节规格改表即可。

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

## 4. 单位精灵 manifest（✅ 量产定稿 · V3-7b）
> **权威实现** = `view/sprite_db.gd` 的 `DB`（`unit_id → {scale, walk/attack:{tex,fw,fh,cols,row,row_up?,n,fps,sc?}}`），`battle_scene._draw_units` 查询作画（架构 A：immediate `_draw`+`draw_texture_rect_region`，逐帧动画、染队伍色、逻辑零改）。换皮/加单位 = 改 `DB`。
> **保真度（决策）= 务实**：每单位 walk + attack 两态；死亡复用现有 FX；idle 并入 walk。**朝向 = 混合**：方向族按 owner 取行（玩家=朝上/背面 `row_up`、敌=朝下/正面 `row`），对称族不分。

| 单位(body) | 走 sheet / 帧网格（行） | 攻 sheet / 帧网格（行） | 朝向 | 备注 |
|---|---|---|---|---|
| knight_body 骑士 | Heavy_Knight_Non-Combat **24×24/4列**（row0 正·row16 背） | Heavy_Knight_Combat 32×32/4列（row8 劈砍） | 方向 | ⚠️ 非 32px/3列（③ 切片曾误用，已修） |
| archer_body 弓箭手 | Archer_Non-Combat 16×16/4列（row0·row14） | Archer_Combat 32×32/4列（row4 射击） | 方向 | 英雄 Combat/Non-Combat 双 sheet、帧尺寸可不同 |
| musketeer_body 女巫 | Mage_Hooded_BROWN 16×16/4列（row0·row14） | Mage_Hooded_BROWN-Combat 32×32/**2列**（row4 施法） | 方向 | 去火器 |
| mini_pekka_body 狂战士 | axe_warrior_combat_32x32 32×32/4列（row16·row14） | 同 sheet（row0 挥斧+斧光） | 方向 | 单 sheet 走+攻 |
| goblin_body 哥布林 | goblin **16×16/4列×14**（row2 正·row0 背） | 同 sheet（row9 突刺） | 方向 | 64×224 怪物族 |
| skeleton_body 骷髅 | skelly 16×16/4列×14（row0） | 同 sheet（row8 突刺） | 正面(不分) | 同族；末两行=死亡动画(暂未用) |
| giant_body 食人魔 | orc_champion 16×16/4列×14（row0） | 同 sheet（row8 挥击） | 正面(不分) | 同族、放大；去真巨人 |
| golem_body 亡灵巨像 | orc_champion（放大 scale1.6） | 同上 | 正面(不分) | ⚠️ 缺真素材暂换皮 |
| minion_body 怨灵 | fire_skull **16×16/4列×10**（row0） | 同 sheet（row4） | 对称(不分) | 飞行；对称免翻转 |
| baby_dragon_body 火颅 | fire_skull（放大 scale1.7） | 同上 | 对称(不分) | ⚠️ 缺真龙暂换皮 |

> **64×224 怪物族**（goblin / skelly / orc·orc_soldier·orc_archer·orc_champion / zombie / mummy / wraith / goblin_slinger / skelly_*…）统一 **16×16 / 4列 × 14 行**，但**各子包行语义略不同**（goblin row0=背、skelly row0=正），逐个核定。
> **敌人池额外单位**（orc_soldier / orc_archer / skelly_archer / mummy / zombie / slime / wraith）留 roguelite 敌方多样性，未来加进 `sprite_db.DB` 即可（同族网格已知）。
> **卡面肖像**（手牌/draft/组卡）：兵牌用各自 walk 正面帧（`SpriteDB.card_portrait_tex`，自然色）。

### 4.1 帧网格坐定方法 / 朝向约定 / 渲染前提（量产经验）
- **帧网格怎么定**：① 临时脚本透明间隔自动探测（全透明行/列=帧间隔→推内容带；无间隔则按宽度猜列+整除性验证）；② 带**行列号**网格放大图肉眼核「哪行=走/攻、朝上/朝下」；③ 选中帧拼贴预览自查无错位/死亡帧。**探测脚本是临时物、验后即删、不入 git**（同 balance probe 约定）。坐实要点：很多英雄 Non-Combat sheet 高度**不能被 32 整除**（骑士 744=24×31→帧 24px；mage/archer 496=16×31→帧 16px），盲设 32 必错位。
- **朝向约定**：竖屏对推，`y` 小=敌方底线(屏上)、`y` 大=玩家底线(屏下)。玩家兵朝上推进→取**背面行**(`row_up`)，敌兵朝下→**正面行**(`row`)；对称单位(火颅)不分。卡面肖像统一取正面行。
- **渲染前提**：`project.godot` `rendering/textures/canvas_textures/default_texture_filter=0`（最近邻），像素锐利；TextureRect 肖像显式设 `TEXTURE_FILTER_NEAREST`。
- **染色**：单位/塔用 `modulate` 染队伍色（玩家偏蓝/敌偏红）+ 复用受击闪白；卡面肖像用自然色（白 modulate）。

## 5. 塔 / 地形 / 特效 / Boss（✅ 量产定稿，as-built 加粗）
- **塔** `assets/towers/`：**王塔=`building1`（大城堡 192×128）/ 公主塔=`building6`（单体小堡 64×64）**；保持原始长宽比+底部贴地（不压扁）、王塔系数更大保主次、王塔顶画金王冠、摧毁=压低 42%+暗色废墟堆、温和队伍色。building2/3/8=城镇组合图(不用)。
- **地形** `assets/terrain/`（逐逻辑格铺 16px tile，与河行/桥列对齐）：
  | 用途 | as-built 素材 / tile |
  |---|---|
  | **地面** | Lonesome `FLOOR` (4,1)/(4,2) 纯土双变体（敌方半场微暖调辨上下） |
  | **河水（动画）** | `simple_water_spritesheet`（4×3=12 帧，按 `_elapsed` 循环） |
  | **桥** | `COBBLESTONE_PATH` (1,1)/(2,1) |
  | 树木点缀 / 节点地图 | `Grand_Forests_TEMPERATE` / `world_map_tiles_SUMMER`+`Clouds-Fog-of-War`+`Boat_and_Wagon`（**未用，留 V3-5/9**） |
- **特效** `assets/fx/`（as-built；命中按卡区分，仅玩家出牌路径触发）：
  | 技能/事件 | as-built |
  |---|---|
  | 召唤兵落地 | 程序化中性尘土环（非火） |
  | fireball 火球 | **`Fire_Explosion_28x28`（12 帧）** |
  | lightning 闪电 | **`Lightning_Energy_48x48`（9 帧）** |
  | zap 电火花 | **`Red_Energy_48x48`（9 帧）** |
  | arrows 箭雨 / log 滚石 / heal 治疗 | **程序化**（落箭 / 褐尘 / 绿环+十字；无单帧贴图） |
  | 塔摧毁 | `Fire_Explosion` 大火 + 震屏 |
  | 远程投射物 | 弓手=程序化箭 / 女巫=紫法术弹 / 火颅=`fire_skull_fireball`（12 帧）|
  | 命中火花 | 程序化径向短线（`Slash_Attack_Effect` 未接） |
  | 冰/减速（未来积木） | `Ice-Burst*`（未用） |
- **Boss / roguelite** `assets/bosses/`：`vampire_lord_*`（IDLE/WALK/MELEE/BITE/CAST/AOE/DEATH 全套）；`vampire_spawn_*` 适合 golem 亡语裂兵。**均未接入，留 V3-5 / 后续**。

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

## 7. 缺口 & 后续美化（V3-7b 量产后更新）
- **golem 石头人 / 真巨人 / 真龙**：无对应 → 换皮（orc_champion 放大 / fire_skull 放大）暂行；后续找同风格素材或 AI 生成补齐。
- **AI(敌方)法术命中大 FX**：当前只玩家出牌路径挂 FX；敌方法术只见伤害数字/闪白。需「同帧多兵聚集掉血」启发式推断爆点（决策 30），较复杂，留可选后续。
- **河岸硬边**：河水用平铺满水 tile、与地面是硬边界（未用 RIVER_and_WATER_EDGES 的自动拼边/水草过渡），留后续美化。
- **死亡动画**：怪物族末两行是死亡帧（skelly 散骨等），当前死亡只用现有 FX（务实保真度），未接专属死亡动画。
- **idle 动画**：并入 walk（本游戏兵几乎一直推进），未做专属待机。
- **地形↔角色明暗**：地形偏暗/角色偏亮，实机 OK；桥(鹅卵石)与水蓝调略近，若难分可换更暖桥 tile 或调地面色。
- **命中火花/Slash FX**：命中火花为程序化短线，`Slash_Attack_Effect` 未接。
- **视角统一**：全部 3-4/侧视；弃用 top-down 包不混入。

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
1. ~~§6 卡牌改名定稿~~ ✅ 已定稿（V3-7①）。
2. ~~塔选哪两个 `building`~~ ✅ 王=building1 / 公主=building6（V3-7b-2）。
3. ~~多语言~~ ✅ 已实现（V3-7②，中英切换+默认中文）。
4. **git 提交策略（§8 版权，⚠️ 仍未决）**：付费 Pixel Grit 源素材已随 `assets/`+`testAssets/` 进公开仓库 = 可能违反 EULA。上架/公开前须决定：转私有 / `.gitignore` 掉付费源 / 仅留 No-Attribution 地形 + 补 `CREDITS`。
