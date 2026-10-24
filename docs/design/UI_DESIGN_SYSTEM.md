# 天空牧场 UI 设计系统

> **给谁读**：改任何客户端界面（配色、按钮、面板、弹窗、HUD）的人和 agent，动手前先读本文。
> **真相源**：色值以代码为准——`view/ui/pixel_ui.gd`（色板常量 + 样式工厂）与 `tools/gen_ui_assets.py`（9-slice 贴图生成）。本文与代码不一致时以代码为准，并顺手修正本文。
> **人看版**：[ui_design_system.html](ui_design_system.html)（同内容的可视化页面，浏览器直接打开）。
> **来由**：决策 49 UI 换肤方案 B「天空牧场」（KAN-125）；2026-10-24 从代码提取成文，同日修完夜色残留两条高优先级偏离（merge `3d6a018`）。

## 1. 基调

- 竖屏 **750 × 1334** 画布；全局一款字体 **站酷快乐体**（`project.godot` → `theme/custom_font`）。
- **浅底深字**：淡天蓝底、白卡面板、圆角加立体边。主文字是深青蓝，不用黑。
- **强调色是天空蓝**；唯一的暖色（黄）只给本屏最重要的主行动按钮。
- 夜色像素风（V3 时代深底）已全面退役：❌ 新代码禁止深色底（三通道都 < 0.4 的 `Color(...)`）。

## 2. 色板（`PixelUI` 常量）

⚠️ 常量名是夜色时代遗留，**按注释取色，别按名字猜**：`COL_GOLD` 实际是天空蓝，`COL_PARCHMENT` 实际是深青蓝主文字。

### 2.1 基础

| 语义 | 常量 | 值 | 用途 |
| --- | --- | --- | --- |
| 主文字 | `COL_PARCHMENT` | `#3a5a74` | 正文、按钮字、浅底上的一切文字 |
| 次文字 | `COL_MUTED` | `#7f9cb3` | 副标题、说明 |
| 脚注 | `COL_HINT` | `#9ab4c8` | 计数、弱提示 |
| 强调 | `COL_GOLD` | `#3d9be0` | 标题、强调、toast 默认色 |
| 标题描边 | `COL_OUTLINE` | `#1f5c8c` | 标题描边 |
| 黄按钮字 | `COL_GOLD_INK` | `#5c430e` | gold 按钮上的字 |
| 白卡 | `COL_PANEL_BG` | `#ffffff` | 面板底 |
| 凹槽 | `COL_INSET_BG` | `#ddeefb` | 白卡内列表底、按下态 |
| 面板描边 | （散装） | `#a9d3ee` | 面板/分隔线描边，代码里写 `Color("a9d3ee")` |

### 2.2 状态底色（2026-10-24 新增，替代夜色深底）

全部是「底 + 描边」成对，用 `PixelUI.sbpixel(底, 宽, 描边)`；上面的字一律 `COL_PARCHMENT`（单测保证对比度 ≥ 4.5:1）。

| 用途 | 底 | 描边 |
| --- | --- | --- |
| 路线·已通关 `COL_NODE_DONE_*` | `#e4f4dc` | `#7cc36a` |
| 路线·当前 `COL_NODE_CURRENT_*` | `#fff8e1` | `#3d9be0` |
| 路线·未到 `COL_NODE_FUTURE_*` | `#eef6fc` | `#cfe3f2` |
| 路线·Boss `COL_NODE_BOSS_*` | `#fde3e2` | `#e24b4a` |
| 兵种卡 `COL_TROOP_*` | `#dceefc` | `#7fb4d9` |
| 法术卡 `COL_SPELL_*` | `#efe4fb` | `#b48fe0` |
| 已填卡槽 `COL_SLOT_FILLED_*` | `#ffffff` | `#a9d3ee` |
| 空卡槽 `COL_SLOT_EMPTY_*` | `#ddeefb` | `#cfe3f2` |
| 禁用按钮 `COL_DISABLED_*` | `#cfdde9` | `#8aa4ba` |

常量名后缀：`_BG` = 底，`_BD` = 描边。

### 2.3 暗幕

- `COL_DIM #1f3a52` @ `DIM_ALPHA 0.5`（深青蓝半透）。`modal.gd` 默认暗幕即取此值。
- **暗幕上不直接写字**：天空蓝、深青蓝字在暗幕上都看不清。自绘暗幕的弹层（如领奖宝箱、run 奖励/结算层）必须垫白卡（`panel_box("stone")`），内容放卡里。

### 2.4 语义与稀有度（散装于 `hud_widget.gd` 等）

| 语义 | 值 |
| --- | --- |
| 达标 / 已通关 | `#7cc36a`（浅底 `#e4f4dc`） |
| 不足 / 偏低 | `#e24b4a` |
| 红点 | `#e5453a` |
| 稀有 | `#7c94c8` |
| 史诗 / 宝石 | `#b48fe0`（边 `#7c5ea8`） |
| 金币图标 | 面 `#cda743` · 亮 `#f0d480` · 暗 `#8a6418` · 边 `#3a2a08` |

### 2.5 战斗（`battle_scene.gd` / `net_battle_scene.gd`）

- **阵营色只看「我/敌」，不看 side**：我方恒蓝 `(0.13,0.42,0.78)`，敌方恒红 `(0.82,0.24,0.20)`；塔、血条、HUD 一致。
- 圣水紫 `(0.80,0.33,0.96)`，10 格；费用角标同色。王冠金 `(0.925,0.725,0.305)`。
- 拖拽落点：合法绿 `(0.45,1.0,0.55)`、非法红 `(1.0,0.42,0.40)`，半透明填充同色。
- HUD 底板 `(0.93,0.97,1.0,0.96)`，上沿 2px 描边 `(0.66,0.83,0.93)`；手牌底 = stone 面色，选中卡暖黄 `(1.0,0.87,0.45)` 并上浮。

### 2.6 场景背景

`PixelUI.add_background(parent)`：竖向三段渐变 `#bfe3fb`（天空）→ 62% `#eaf6ff` → `#d6efc9`（草地）+ 5 朵白云；每个菜单场景最底层都用它。战斗场地底色单独用 `COL_BG (0.85,0.93,0.98)`。

## 3. 组件

### 3.1 按钮 `PixelUI.style_button(btn, kind, font_size)`

48px 9-slice 贴图，圆角 12，贴图边距 14，内边距上下 10 / 左右 20。每个按钮由「面·上沿亮·下沿暗·外描边」四色组成，**按下时亮暗对调**（凹陷反馈）。禁用态不换贴图，字色降到 45% 透明度。

| kind | 面 | 亮 | 暗 | 边 | 用途 |
| --- | --- | --- | --- | --- | --- |
| `stone` | `#dceefc` | `#f2faff` | `#bcd9ef` | `#7fb4d9` | 普通、次要操作、列表项 |
| `gold` | `#ffcc4d` | `#ffe08a` | `#e9b23a` | `#a87b1a` | 主行动 CTA（字 `COL_GOLD_INK`） |
| `dark` | `#cfdde9` | `#e2edf5` | `#b7c9d9` | `#8aa4ba` | 返回、取消、关闭 |

- `gold` 每屏最多一个；出现两个时次要的降成 `stone`。
- 主操作放拇指区（屏幕下 1/3）。
- 改按钮色：改 `tools/gen_ui_assets.py` 后重跑 `uv run --with pillow python tools/gen_ui_assets.py`，产物入 git。

### 3.2 面板 `PixelUI.panel_box(kind)`

64px 9-slice，圆角 16，描边 2，贴图边距 18，内容边距 16。`"stone"` = 白卡（对话框、卡槽、信息卡）；`"inset"` = 凹槽（白卡内的列表底、输入区）。

### 3.3 动态色块 `PixelUI.sbpixel(bg, border_w = 3, border_col)`

按数据变色的块（难度、稀有度、阵营、状态行）不生成贴图，用 StyleBoxFlat：圆角 10；描边色缺省 = 底色加深 18%。

### 3.4 HUD 小件 `view/ui/hud_widgets.gd`

纯 `_draw` 程序化、零贴图：钱包条 `wallet_bar`、星级 `stars_row`、花费药丸 `cost_pill`、阶 pip `rank_pips`、数值条 `stat_bar`。数字一律千分位 `format_int`。战力三档色：≥ 推荐绿 / ≥ 0.8× 推荐天空蓝 / 更低红（`power_tier_color`）。

## 4. 字号

字号目前散在 30 多级（10~96），以下 7 级是按使用频率整理的**推荐阶梯**，新代码就近取用：

| 级 | 字号 | 用途 |
| --- | --- | --- |
| display | 76 | 主菜单标题、结算大字 |
| h1 | 52 | 场景标题 |
| h2 | 36 | 弹窗标题 |
| button | 30 | 主按钮（`style_button` 缺省 34，实际多传 22–30） |
| label | 26 | 卡名、关卡名 |
| body | 22 | 正文（最常用） |
| caption | 18 | 脚注、计数 |

标题用引擎原生描边：天空蓝字 + 白色 `font_outline_color` + `outline_size 10`；❌ 不用偏移叠字假描边（圆体字下会重影）。toast 固定 24 号。

## 5. 层级（`view/ui/ui_layers.gd` / `view/scene_router.gd`）

| CanvasLayer | 内容 | 要点 |
| --- | --- | --- |
| 100 | 转场黑幕 `Router` | 切场景期间挡输入，防连点 |
| 90 | 提示 `UI.toast()` | 24 号字，停 1 秒后 0.5 秒淡出；不挡点击 |
| 50 | 弹窗 `UI.modal()` | 继承 `view/ui/modal.gd`；默认暗幕见 2.3；结算层可设 `dim_alpha = 0` 自己演出 |
| 0 | 场景 | 背景 → 内容 → HUD |

覆盖类 UI 一律走 `UI.modal()`，❌ 禁手搓全屏 Control 靠树序压层；铺满必须用 `set_anchors_and_offsets_preset`。细则见 `pixel_ui.gd` 文件头与 CLAUDE.md「架构铁律」。

## 6. 改界面时的规则

1. 颜色从 `PixelUI` 常量取；色板里没有的语义先加常量（并补 `tests/test_pixel_ui_palette.gd` 的对比度断言），别在场景里散写新色值。
2. 浅底上的字用 `COL_PARCHMENT`；❌ 不用白字（白字只用于深色实心徽章，如红点数字）。
3. ❌ 不在暗幕上直接写字，垫白卡。
4. 按钮用 `style_button` 三种 kind；自定义禁用态用 `COL_DISABLED_*` + 字色 `Color(COL_PARCHMENT, 0.45)`。
5. 改完跑客户端单测（含 `test_pixel_ui_palette` 的对比度与夜色字面量守门）+ `gdlint`，界面效果交真人验收。

## 7. 已知未统一处（待排期）

| 优先级 | 问题 | 位置 |
| --- | --- | --- |
| 中 | 夜色残留：建筑弹窗面板深紫底、主菜单两处标签底、王国三处自绘标签底、锁罩 | `kingdom_building_modal.gd:34`、`main_menu.gd`（2 处）、`kingdom.gd`（3 处）、`hud_widget.gd`（锁罩） |
| 中 | 当前关卡行底色深棕 `#96701e`，建议改用 `COL_NODE_CURRENT_*` | `stage_map.gd:19` |
| 中 | 常量名与颜色对不上（`COL_GOLD` 是蓝；`COL_CROWN` 注释仍写「= COL_GOLD」） | `pixel_ui.gd`、`battle_scene.gd` |
| 中 | 战斗色常量重复维护（阵营/圣水/卡面各两三份） | `battle_scene.gd`、`net_battle_scene.gd`、`hud_widgets.gd` |
| 低 | 字号未收敛到第 4 节阶梯 | 全 view 层 |
| 低 | 设计坐标两套：画布 750×1334，弹窗/toast 按 720×1280 换算 | `modal.gd`、`ui_layers.gd` |
