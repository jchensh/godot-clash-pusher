# DESIGN_V5_S7_UI — KAN-58 闯关养成 UI 整合设计稿

> **状态**：设计稿（仅规格，未写代码）。施工待 N7 瘦客户端落地后进行（数据源届时由本地 `PlayerData` 换为服务器状态缓存，读写形状不变 → 接线为薄层、非重写）。
> **范围**：闯关地图 / 养成（升级·升阶·解锁）/ 钱包 / 挂机领取 / 战力提示 / deck builder 接已解锁卡。
> **权威逻辑均已存在且过单测（270/270）**：本稿只定义「显示层怎么读这些逻辑、长什么样、点了怎么走」。

---

## 0. 已决策（本轮 + PLAN_V5）

| 项 | 决定 |
|---|---|
| 本轮交付 | **只出设计稿**，不写场景代码（代码等 N7 后统一接） |
| 基地(Home Hub)入口 | **替换主菜单 "START 选关"**：`menu_start` → 进基地，基地再分发到 闯关/养成/卡组 |
| 闯关地图形态 | **竖向关卡列表**（cleared/当前/locked 三态 + 星级），承接现有 `level_select` 一脉，不做蜿蜒路径图 |
| 数据源 | 本阶段读本地 `PlayerData`；N7 后换服务器缓存（同 read/write 形状） |
| 战后结算 | 用**「领奖开箱」动画**（非纯数字滚动），见 §5 |
| deck builder 战力 | 给**「达标/未达标」颜色提示**（对比本关推荐战力），见 §8 |
| 养成卡格排序 | 做**多维可选排序**（稀有度/费/等级·星级/可养成优先）→ 涉及功能开发，独立 Story **KAN-67**，见 §6.C1 |
| 阶 pip 上限 | 按 `_max_rank` **动态**（`level_cap_per_rank` 最大 key），不写死 |

---

## 1. 设计语言（沿用 V3 PixelUI 标杆，不另起炉灶）

- **画布**：720 × 1280 竖屏。坐标按现有场景惯例硬定位（见 `main_menu.gd` / `level_select.gd`）。
- **背景**：`assets/ui/menu_bg.png` 夜色战场，`STRETCH_KEEP_ASPECT_COVERED`，`mouse_filter = IGNORE`。
- **色板**（`view/ui/pixel_ui.gd` 权威常量，**禁止硬编码新色**，动态色走 `sbpixel`）：
  | 常量 | hex | 用途 |
  |---|---|---|
  | `COL_PARCHMENT` | `#e7decb` | 主文字 |
  | `COL_MUTED` | `#a79fc0` | 次文字 |
  | `COL_GOLD` | `#ecb94e` | 标题/强调/CTA 字 |
  | `COL_GOLD_INK` | `#2c1f06` | 金按钮上的深字 |
  | `COL_HINT` | `#6f6888` | 脚注/弱提示 |
  | `COL_OUTLINE` | `#3a2a08` | 标题描边 / 像素分隔 |
- **按钮**：`PixelUI.style_button(btn, kind, font_size)`，kind = `gold`(主 CTA) / `stone`(常规) / `dark`(弱化/返回)。
- **面板/卡片**：中性用 `PixelUI.panel_box("stone"|"inset")`；**带语义色**（稀有度/星级/阶/难度）用 `PixelUI.sbpixel(bg, border_w, border_col)` → **无圆角像素方块**（这是本游戏的「像素感」来源，所有自绘块一律 0 圆角）。
- **手感 juice**（沿用 main_menu/level_select）：按钮 `button_down`→`scale 0.96`、`button_up`→`1.0`，`create_tween().tween_property(...,0.07)`；点击 `AudioManager.play_sfx("ui_button_press")`。
- **文本走 i18n**：所有可见串走 `tr(key)`，新串补进 `config/i18n.json`（见 §9 串表）。

---

## 2. 导航图

```
main_menu
  └─[menu_start 改为「基地」]→ base_camp(新)
        ├─ 闯关 (gold CTA) ────→ stage_map(新, 竖向列表)
        │                            └─[挑选某关]→ deck_builder → battle → 战后回 stage_map(刷新星级/钱包)
        ├─ 养成 ───────────────→ card_collection(新, 卡格网格)
        │                            └─[选卡]→ card_detail(新, 升级/升阶/解锁)
        ├─ 卡组 ───────────────→ deck_builder(现有, 改为只列已解锁卡)
        ├─ 挂机领取 (基地内嵌, 不跳场景)
        └─ 返回 ───────────────→ main_menu
```

- `天梯对战` / `roguelite` / `新手战役` / `设置` 维持现状，不在 S7 范围。
- **场景文件新增**：`view/base_camp.gd(+.tscn)`、`view/stage_map.gd(+.tscn)`、`view/card_collection.gd(+.tscn)`、`view/card_detail.gd(+.tscn)`。沿用「脚本里 `_build()` 程序化建节点」的现有范式（与 main_menu/level_select 一致，不用编辑器拖场景）。

---

## 3. 共享组件（先定义，三屏复用 —— 收敛实现、统一观感）

> 建议落在 `view/ui/` 下做静态工厂（仿 `pixel_ui.gd` 风格，`extends RefCounted` + 静态方法，preload 调用），避免三屏各写一遍。命名暂定 `view/ui/hud_widgets.gd`。

| 组件 | 形态 | 数据 | 备注 |
|---|---|---|---|
| **钱包条 `wallet_bar`** | 顶部横条：金币图标+数 / 宝石图标+数 / 右侧齿轮 | `PlayerData.gold` / `.gems` | 基地/养成/详情三屏常驻顶部；金=`COL_GOLD`，宝石=`COL_MUTED` 边框 |
| **星级 `stars(n, max)`** | `★` 实(`COL_GOLD`) / 空(`COL_OUTLINE`)，max 由 stage `stars` 配置条数定 | `PlayerData.stages[id].stars` | 关卡行 + 战后结算复用 |
| **成本药丸 `cost_pill`** | 图标+数字小块，足额=亮、不足=红 | 比 `gold`/`shards` | 金币=coin 图标，碎片=puzzle 图标 |
| **阶 pip `rank_pips(rank,max)`** | 5 个 11px 方块，实=`COL_GOLD` 空=暗紫 | `card.rank` / `_max_rank` | 详情页 |
| **数值条 `stat_bar`** | 标签 + 右值 + 进度槽（inset 像素槽） | `card_power` / 单位 hp·atk | 详情页；归一化到该卡满阶满级为 100% |
| **锁罩 `locked_overlay`** | 暗化 + 居中 `ti-lock` + 解锁条件串 | `StageProgress.is_unlocked` / `card.unlocked` | 关卡行 + 卡格 |

---

## 4. 屏 A — 基地 Base Camp（新中枢）

**目标**：单机闯关养成主循环的「家」。一眼看到 钱包 / 战力 / 挂机待领 / 下一步去哪。

### 布局（720×1280，y 自上而下）
```
[0,0]   钱包条 wallet_bar（金币 12,480 · 宝石 36 · 齿轮→设置）         高 ~88
[~120]  战力区：小标签「队伍战力」+ 大金字 team_power（描边）          
        + 副行「较上次 +260 ↑」（涨绿/跌灰）
[~360]  挂机卡 idle_card：时钟图标 + 「挂机收益 第N章产出」
        + 「+1,240 金币 · 已封顶 8h」+ [领取] gold 小按钮（见 §7 挂机）
[~520]  主 CTA：[闯关 · 第N章] gold 大按钮（384×112，居中）→ stage_map
[~660]  次级三按钮一行：[养成] [卡组] [天梯]（stone，等宽 3 列）
[~1200] 脚注 app_footer
```
- 战力大字用 main_menu `_title` 同款描边（4 向 `COL_OUTLINE` offset + `COL_GOLD` 正文）。
- 主 CTA 文案动态：取 `StageProgress.next_stage(pd)` 所属章 → `闯关 · 第N章`；全通关 → `闯关 · 已通关`。
- 进基地时机：`_ready()` 里 `ConfigLoader.load_all()` + 载 `PlayerData`（N7 前 `SaveSystem` 本地档；N7 后 session 缓存）。

### 状态
- 挂机待领 = 0 → 挂机卡降为暗色、`[领取]` 隐藏，副行显示「产出中…」。
- 战力副行：首次进无基线 → 隐藏 `±` 行。

---

## 5. 屏 B — 闯关地图 Stage Map（竖向列表）

**目标**：线性推进一目了然，当前关高亮可挑战，已通关看星，未解锁看条件。

### 行结构（每行一关，承接 `level_select` 卡片范式但更紧凑）
- **顶部头条**：`第N章 · 章节名` + 副行 `系数 ×coef · 推荐战力 X` + 右侧 `章节星 14/15`（`StageProgress.chapter_stars`）。
- **关卡行三态**（数据全来自 `StageProgress` + `PlayerData.stages`）：

| 态 | 判定 | 样式 |
|---|---|---|
| **已通关** | `stages[id].cleared` | 绿边 `sbpixel`，序号块绿，标题+`stars(n,max)`，右侧 `ti-circle-check`；点 → 可重打（deck_builder） |
| **当前/下一关** | `id == next_stage(pd)` | 金边高亮 + 略放大，序号块金，副标「下一关」或「BOSS」，右侧 `[挑战]` gold 小按钮 |
| **未解锁** | `!is_unlocked(id)` | 暗紫边 + 半透，序号块 `ti-lock`，副标「通关 X 解锁」，不可点 |

- 章节内关卡按 `(chapter, index)` 升序（`StageProgress.ordered`）。
- 列表可竖向滚动（`ScrollContainer`），章节头随滚动。后续章节折叠为 `第N章 ?` 暗条占位。
- **挑战流**：点关 → `GameState.stage_id = id` → `deck_builder`（带本关 coef/encounter/ai_difficulty）→ battle → 战后 `StageProgress.apply_result(id, stars, pd)` + `grant_stage_reward(...)` → 回 map，刷新该行星级 + 钱包条。

### 战后结算浮层 —— 「领奖开箱」动画（已决策，轻量复用本屏，不新建场景）
- **通关序列**（约 1.2~1.8s，可点击跳过直达末态 —— 二次点击立即收束，不强制看完）：
  1. 暗化幕 + 居中宝箱（像素 9-slice 箱，金边 `sbpixel`）。
  2. 宝箱抖动 2~3 下（`scale` 小幅 tween + `ui_chest_shake` sfx 占位）→ 弹开（箱盖上移 + 金光像素粒子，复用现有 FX 范式，**不引入物理**）。
  3. `stars(n,max)` 逐颗点亮（每颗 `scale` 弹一下 + `ui_star` sfx），首通三星给额外金闪。
  4. 奖励逐项飞出滚动：`金币 +X`（coin 图标飞入钱包条 + 数字滚动）/ `碎片 +Y`（按卡）/ 首通额外奖。数字用 `tween_method` 整数滚动。
- **末态按钮**：`[继续]`（回 stage_map，刷新该行星级 + 钱包条）/ `[下一关]`（`next_stage` 非空 → 直接进下一关 deck_builder）。
- **数据**：奖励数值来自 `grant_stage_reward(id, first, config, rng)` 返回的实发 dict（`{gold, gems, shards}`）；首通 vs 重复由 `first` 决定箱体规格（首通=金箱大开，重复=小箱）。
- **失败**：无开箱；`stars(0,max)` 灰显 + 「再战」/「调整卡组」/「返回」。

---

## 6. 屏 C — 养成 Card Collection + Detail

### C1. 卡格网格 card_collection
- 顶部钱包条。标题「养成」。
- 网格 2 列（竖屏宽，2 列 tap 友好；遵守窄屏≤2列）卡格，每格：卡图 + 稀有度边框色 + `Lv.x` 角标 + 阶 pip 缩略。
- **已解锁** = 正常；**未解锁** = 锁罩 + 碎片进度 `12/50`（`card.shards` / `unlock_shards[rarity]`）。
- **可升级/可解锁红点**：该卡 `upgrade_card` 可行（金够且未达本阶上限）或 `can_unlock` → 右上角金点提示「有可做的养成」。
- 点格 → `card_detail`。

#### 排序控件（独立 Story **KAN-67**，涉及功能开发 → 不在 KAN-58 范围，本设计稿仅占位 UI）
- 卡格上方一行**分段排序按钮**（或下拉），可选排序键：
  1. **稀有度** rarity
  2. **圣水费** card cost
  3. **当前等级 / 星级** level（可含 rank 次序）
  4. **可养成优先** —— `can_unlock || (upgrade_card 可行)` 的卡置顶
- 升序/降序切换 + 记住上次选择（写本地偏好，非权威）。
- **工程**：逻辑层加纯函数排序器（headless 单测：各 key 排序正确、可养成优先置顶规则、稳定排序），view 接控件即时重排。
- KAN-58 实现 C1 时**预留排序栏位置**即可（默认按稀有度），具体排序逻辑由 KAN-67 落地。

### C2. 养成详情 card_detail（核心交互屏，见上方 mockup 第三张）
**布局**
```
[顶] 钱包条（含金币，升级要花）
[卡区] 左：卡图 96×120 + 稀有度边框 + 底标「稀有 RARE」
       右：名 + Lv.x / 阶 pip(rank_pips) / 战力条 / 生命条(stat_bar ×2~3)
[技能解锁条] 绿左边框：「阶R解锁：<技能名>（效果摘要）」—— 下一阶将解锁的积木预告
[双按钮] [升级 Lv.x+1  💰cost]   [升阶 阶R+1  🧩shards 💰gold]
```

**升级按钮**（`PlayerData.upgrade_card`）
- 主标「升级 Lv.{level+1}」，cost_pill = `upgrade_cost(card_id, config)`（金币）。
- **禁用态**：
  - `level >= level_cap(rank)` → 文案「需升阶解锁」，按钮暗，提示「本阶等级已满」。
  - `gold < cost` → cost_pill 红，按钮可点但点了弹「金币不足」抖动 + sfx，不扣。
- 成功：扣金 + `level+1`，战力条/数值条 tween 增长，金币条滚动减少，`ui_upgrade` sfx（占位）。

**升阶按钮**（`PlayerData.rank_up_card`）
- 主标「升阶 阶{rank+1}」，cost = `rank_up_cost(card_id, config)` → `{shards, gold}` 两个 cost_pill。
- **禁用态**：
  - `rank >= _max_rank` → 「已满阶」，按钮暗。
  - 碎片或金不足 → 对应 pill 红 + 点击抖动拒绝。
- 成功：扣碎片+金 → `rank+1`，阶 pip 点亮一格 + 等级上限抬升提示 +「技能解锁」横幅（`CardProgression.effective_skills` 新增的积木，文案从 `card_progression.json` 的 `rank_unlocks[r]` 取）。

**解锁态**（卡未解锁时 detail 顶替双按钮）
- 显示碎片进度大条 `shards/need`，足额 → `[解锁]` gold 按钮（`unlock_card`）；不足 → 灰 + 「再集 N 碎片」。

---

## 7. 挂机领取（基地内嵌组件，不跳场景）

- 数据：`PlayerData.idle_pending(now_ts, config)`（待领），`idle_rate_per_hour`（速率），封顶 `idle.cap_hours`。
- `now_ts` **由 view 注入**（N7 前本地时钟；N7 后服务器时钟，改本地时钟无效）—— 逻辑层不取系统时间。
- 显示：`+{pending} 金币 · {满/未满}封顶 {cap}h`；待领>0 → `[领取]` 亮，点 → `collect_idle(now_ts, config)` → 金币条滚动 + 卡重置为「产出中…」+ 金币飞入动画 + sfx。
- 待领=0 → 按钮隐藏。

---

## 8. deck_builder 改造（现有场景，最小改动）

- 现：列固定/全部卡。改：**候选池 = `PlayerData.unlocked_card_ids()`**（只列已解锁）。
- 每张候选卡角标显示 `Lv.x`（出战即按该卡 level/rank 注入数值乘区 —— 战斗内计算已在 S1/S4 接通）。
- 顶部加「队伍战力 = `team_power(选中卡组, config)`」实时数（选/换卡即刷新）—— 给玩家「这套够不够打推荐战力」的判断锚点。
- **战力达标颜色提示（已决策）**：从闯关地图进 deck_builder 时携带本关「推荐战力」（`GameState`），实时对比：
  - 战力 ≥ 推荐 → 绿（`#7cc36a`）+ `ti-circle-check`「达标」；
  - 0.8×推荐 ≤ 战力 < 推荐 → 琥珀（`COL_GOLD`）「略低」；
  - < 0.8×推荐 → 红（`#e24b4a`）+ `ti-alert-triangle`「偏低」。
  - 纯展示提示、**不卡门槛**（仍可强推）。从养成/主菜单进（无关卡上下文）→ 只显数字、不着色。
- **不在 S7 加**「按战力/费用限制组卡」（PLAN_V5 §12 待定项，留 S8 评估）。仅显示战力 + 达标提示，不阻止出战。

---

## 9. 数据绑定速查表（view → logic，全部已实现）

| UI 元素 | 调用 |
|---|---|
| 钱包金币/宝石 | `pd.gold` / `pd.gems` |
| 队伍战力 | `pd.team_power(deck_ids, config)` |
| 单卡战力 | `pd.card_power(id, config)` |
| 关卡解锁/下一关/全通 | `StageProgress.is_unlocked/next_stage/is_all_cleared` |
| 关卡星级 | `pd.stages[id].stars` ；判定 `StageProgress.judge_stars(stars_cfg, outcome)` |
| 章节星 | `StageProgress.chapter_stars(ch, pd)` |
| 升级成本/上限/执行 | `pd.upgrade_cost` / `pd.level_cap(rank)` / `pd.upgrade_card` |
| 升阶成本/满阶/执行 | `pd.rank_up_cost` / `pd._max_rank` / `pd.rank_up_card` |
| 升阶解锁的技能 | `CardProgression.effective_skills(base, rank_unlocks, rank)` + `card_progression.json` 文案 |
| 解锁判定/执行 | `pd.can_unlock` / `pd.unlock_card` |
| 关卡奖励发放 | `pd.grant_stage_reward(id, first, config, rng)` |
| 挂机待领/领取 | `pd.idle_pending(now_ts, config)` / `pd.collect_idle(now_ts, config)` |
| 已解锁卡池 | `pd.unlocked_card_ids()` |

> 注：N7 后，「执行类」调用（升级/升阶/解锁/领奖/挂机领取）改为走服务器 API（服务器算成本+校验+落库），view 拿返回的新状态刷新；「查询类」（战力/成本预览/星级）仍可本地算做即时预览。读写形状一致 → 接线为薄层。

---

## 10. i18n 新串（补进 config/i18n.json，施工时填）

`base_title` 基地 / `team_power` 队伍战力 / `idle_title` 挂机收益 / `idle_collect` 领取 / `idle_capped` 已封顶 / `stage_map_title` 闯关 / `stage_locked_hint` 通关 %s 解锁 / `stage_challenge` 挑战 / `stage_boss` BOSS / `card_collection_title` 养成 / `card_upgrade` 升级 / `card_rankup` 升阶 / `card_unlock` 解锁 / `rank_skill_unlock` 阶%d解锁：%s / `level_capped` 需升阶解锁 / `gold_short` 金币不足 / `shards_short` 碎片不足 / `need_more_shards` 再集 %d 碎片 …（最终以施工时补全为准）

---

## 11. 施工子步建议（代码阶段，N7 后；每步停确认 + 单测 + commit）

> 表现层为主，逻辑已覆盖。**headless 单测**覆盖「状态机/绑定取值正确」（哪些关解锁、按钮禁用条件、成本显示），**真人验收**覆盖「点通/观感/动画」。

1. **S7a 共享组件** `hud_widgets.gd`（钱包条/星级/cost_pill/rank_pips/stat_bar/锁罩）+ i18n 串。单测：组件取值函数（如星级映射、成本足额判定）。
2. **S7b 基地 base_camp** + 主菜单入口替换 + 挂机内嵌。单测：CTA 文案随 next_stage、挂机待领显示逻辑。真人：进基地点通。
3. **S7c 闯关地图 stage_map** + 三态行 + 战后**领奖开箱动画**浮层 + 挑战流接 deck_builder/battle。单测：三态判定、星级回写、开箱奖励取值=`grant_stage_reward` 返回。真人：推一关看开箱+星级刷新+可跳过。
4. **S7d 养成 collection + detail** 升级/升阶/解锁全交互 + 红点（C1 预留排序栏，默认稀有度）。单测：按钮禁用矩阵（满级/满阶/不足）、阶 pip 上限=`_max_rank`。真人：升级升阶解锁各点通、数值条动。
5. **S7e deck_builder 改造**：已解锁池 + 实时战力 + **达标颜色提示**。单测：候选池=unlocked、达标色阈值（≥/0.8×/<）。真人：组卡看战力着色。

> **KAN-67（独立 Story，To Do）**：养成卡格多维排序，在 S7d 把 C1 立起来后再做（逻辑层排序器 + 控件 + 单测）。不阻塞 KAN-58。

---

## 12. 开放问题 —— 已决策（2026-06-27）

- ✅ 战后结算 → **领奖开箱动画**（可点击跳过）。见 §5。
- ✅ 养成卡格排序 → **多维可选**（稀有度/费/等级·星级/可养成优先），拆为独立 Story **KAN-67**（涉及功能开发）。见 §6.C1。
- ✅ deck builder 战力 → **达标/未达标颜色提示**（绿/琥珀/红 对比推荐战力，不卡门槛）。见 §8。
- ✅ 阶 pip 上限 → **动态 `_max_rank`**（取 `level_cap_per_rank` 最大 key），不写死 5。见 §6.C2 / §3。

> 余下可在施工时即兴定的小项（不阻塞）：养成卡格默认排序键（暂定稀有度，KAN-67 再调）、开箱粒子 FX 精度（首版可简化为金闪 + 缩放，不强求粒子系统）。
