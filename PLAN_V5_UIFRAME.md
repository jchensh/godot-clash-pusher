# PLAN_V5_UIFRAME.md — 客户端 UI 体系改造施工图（层级骨架 + 弹窗基类，Jira KAN-97/98）

> 2026-07-05 用户回报「半透明界面经常错误穿透、能点到下层按钮」→ 全面盘查 view/ 层 17 个场景/组件 → 结论：**客户端只有样式库（PixelUI 管好看）、没有层级骨架（没人管谁在上面、谁收点击）**，穿透是结构性的。用户已拍板按本方案改造（F1→F2→F3），**待用户指示开工**。

## 0. 盘查现状地图（2026-07-05，代码级核实）

| UI 形态 | 实例 | 实现方式 | 输入拦截 | 状态 |
|---|---|---|---|---|
| 全屏场景 | 15 个场景（main_menu/battle/stage_map…） | 根 Control/Node2D 全代码搭建 | 场景切换互斥 | ✅ 无层级问题 |
| 背景/装饰 | PixelUI.add_background、钱包条、名片 | mouse_filter=IGNORE | 不吃输入 | ✅ |
| 滚动列表 | 组卡/创号/图鉴/闯关 ×DragScroll | `Node._input` 前置拦截（绕 GUI） | 自研 | ⚠️ 已撞两刀（KAN-96），遮挡判定已补但仍是并行输入系统 |
| 模态弹窗 | reward_chest / run_scene `_dim` 弹层 | 全屏 Control STOP（各自手搓） | GUI 正统 | ⚠️ 写法三家三样，无基类无规约 |
| 结算演出层 | battle/net_battle `_result_layer` | 全屏 STOP + `_draw` 演出 | GUI | 🔴 **net_battle 树序 bug（KAN-98）**：结算层建于 `_ready`、手牌按钮建于进房后 → 按钮树序在结算层之上，暗幕拦不住卡牌区点击 |
| 教程覆盖 | battle_scene `_draw` 暗幕 | 无 Control 实体，`_input` 手搓吞 tap | 前置 `_input` | ⚠️ 视觉与输入实体分离，机制脆 |
| toast | base_camp/card_detail/account_create/deck_builder ×4 | Label IGNORE + tween | 不吃输入 | ✅（但 4 处复制粘贴） |
| 跳字 | 战斗伤害数字（`_draw` 派生） | 无实体 | 不吃输入 | ✅ 保持 |

**根因三条**：①全项目 0 个 CanvasLayer、无统一弹窗/toast 通道，层级=各场景 add_child 树序潜规则；②Godot Control 输入命中按**树序**而非 z_index/绘制序——"视觉在上≠点击在上"（KAN-98 实锤）；③三套输入系统并行互不知晓（GUI mouse_filter / DragScroll 前置 `_input` / 场景手搓坐标判断），撞车是必然（KAN-96 实锤）。

## 1. 目标设计（轻量骨架，不推翻 PixelUI 样式库）

- **`view/ui/ui_layers.gd`（autoload `UI`，第 3 个 autoload）**：常驻 CanvasLayer 栈——`MODAL=50`（弹窗/结算/教程）< `TOAST=90`（提示/跳字，恒 IGNORE 不挡手）。场景自身留 layer 0，战斗 HUD 现状不动。CanvasLayer 的 GUI 事件按 layer 从高到低分发 → **modal 开着时下层从机制上收不到点击**，不再靠每个弹窗自觉 STOP。场景切换自动清 modal 层（防残留）。
- **`view/ui/modal.gd`（弹窗基类）**：全屏 Control + 自带暗幕（ColorRect STOP，alpha 可配）+ 内容根 + `closed` 信号 + 可选"点暗幕关闭/跳过"回调。入口 `UI.modal(node)`。
- **toast 统一入口 `UI.toast(msg, col)`**：替换 4 处复制粘贴；`UI.float_text()` 备给非战斗界面跳字（战斗伤害数字仍走 `_draw`，不迁）。
- **DragScroll 双保险**：按下代管前 `UI.modal_open() or 现有 hovered 遮挡判定` 任一命中即不代管。
- **规约（F3 固化）**：新 UI 必须声明层级；禁止用兄弟树序当层级；z_index 只管绘制、要挡点击必须配 mouse_filter；覆盖类 UI 一律走 `UI.modal`。

## 2. 施工步骤（每步 commit + 停下确认）

| 步 | 内容 | 验收 |
|---|---|---|
| **F1 层级骨架 ✅ 2026-07-05** | `view/ui/ui_layers.gd`（autoload `UI`：MODAL=50/TOAST=90 + UI.modal/toast 入口 + 场景切换自动清弹窗）+ `view/ui/modal.gd` 基类（幂等 `_assemble` 装配：暗幕/STOP/全屏锚；子类覆写 `_build()`）+ battle/net_battle 结算层迁入 MODAL（`dim_alpha=0`，演出黑幕仍由 `_draw` 渐入——**KAN-98 根治**）+ DragScroll 双保险（modal 开着一律让路）+ 顺手修教程 `_input` 结算期吞点击隐患。**实施笔记**：test_runner 在 `_initialize` 跑=离线树（`_ready`/`push_input`/绝对路径/`get_viewport` 均不可用）→ Modal 装配做成幂等双入口、DragScroll 找 UI 走 `Engine.get_main_loop().root` 相对路径、输入隔离降级为结构断言（层值/STOP/全屏锚——分发本身是引擎行为）| 单测 ✅（+6，372/372：层值序/开闭/closed 信号/暗幕装配/隔离结构/DragScroll 让路/toast）；真人 ⬜ 台账 F 组（联机结算演出期点卡牌区无反应、结算按钮可点） |
| **F2 存量迁移 ✅ 2026-07-05** | ①reward_chest 继承 Modal（暗幕仍自绘垫底 `dim_alpha=0`；`_gui_input` 跳过→覆写 `_on_bg_click`；stage_map 改 `UI.modal(chest)`）②run_scene 奖励/结算覆盖层：场景内 `_overlay+_dim` 树序压层 → Modal 实例 + `UI.modal`（`_dim()` 删除）③4×toast 改一行转发 `UI.toast`（base_camp/card_detail/account_create/deck_builder，场景级默认参数保留，字号统一 24；`UI.toast` +hold 参数）④battle 教程覆盖补输入实体：`_tut_layer` Modal（dim=0，视觉仍 `_draw`）——tap 步 STOP 吞点击 / action 步 IGNORE 放行出牌 / 结束或进结算自动撤层，删前置 `_input` 手搓；Modal +`bg_click_cb`（免子类的点空白回调） | 单测 ✅（+2，374/374）+ 全 view 脚本编译检查 + 实跑冒烟；真人 ⬜ F 组 F-5~F-8（开箱全流程/肉鸽弹层/新手教程/toast 抽查） |
| **F3 规约固化** | 规约写进 CLAUDE.md（架构铁律区）+ pixel_ui.gd 文件头；HISTORY 记档 | 文档评审 |

## 3. 风险

- autoload 增加（I18n/AudioManager→+UI）：headless 单测环境 autoload 可用性需首步验证（test_runner 是 --script 模式，必要时基类做成可独立实例化、autoload 只是持有者）。
- 教程暗幕迁移涉及新手引导流程（S9 已真人验收过）——F2 单列回归用例，别破新手局。
- 战斗内 HUD（手牌/圣水条）刻意不动：属场景绘制，与弹窗层级正交；横版 H4 再重排。

## 4. Jira

- **KAN-97** UI 体系改造 F1~F3（任务，待办）——本施工图对应单。
- **KAN-98** net_battle 结算暗幕拦不住手牌（缺陷，待办）——随 F1 根治，不单独打补丁。
- 关联已修先例：**KAN-96**（DragScroll 穿透，In Review）。
