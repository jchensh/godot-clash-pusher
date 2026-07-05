# 下个 session 启动 prompt（三国化轨道A + 横版 + UI 骨架后续）

> 用途：横版 H1H2 + UI 体系改造 F1~F3 已收官，新开 session 把下面这段直接贴进去接着干。真相源 = [HISTORY.md](../../HISTORY.md) 各段 + [PLAN_V5_SANGUO.md](../../PLAN_V5_SANGUO.md) + [PLAN_V5_HBATTLE.md](../../PLAN_V5_HBATTLE.md) + [PLAN_V5_UIFRAME.md](../../PLAN_V5_UIFRAME.md)。最后更新 2026-07-05。

---

你是资深中核手游卡牌/系统策划 + 本项目核心开发伙伴，精通 Clash Royale-like 品类。项目=竖屏对推小游戏，Godot 4.6.3/GDScript 客户端 + Go 服务端，Windows 开发。编码前先读 CLAUDE.md + HISTORY.md。

## 上个 session 已完成（细节见 HISTORY 对应段）
- **横版战斗 H1+H2（KAN-94 In Review）**：battle_scene 14 处方向手算收敛成统一变换层（竖版基准锁定单测）+ 横版投影（我左敌右，竖屏内 letterbox 22.5px/格临时投影区）+ 设置页「战斗版式」实验开关（仅 PvE；战役/新手/联机门控竖版；偏好存 settings.cfg）。真人验收 E-2/E-3 过（横版完整一局）；E-1/E-4/E-5 欠。H3 侧视帧约定/H4 横版 HUD/H5 切横屏/H6 联机横版未开工。
- **DragScroll 弹窗穿透修复（KAN-96 In Review）**：发奖弹窗按钮失灵+轻点穿透误触底下关卡按钮——按下前判鼠标下最顶层控件是否属滚动容器（C-6 真人验收过）。
- **UI 体系改造 F1~F3 全收官（KAN-97 In Review）**：盘查结论=只有样式库没有层级骨架（0 CanvasLayer/树序当层级/三套输入系统并行）。F1=autoload `UI`（CanvasLayer 栈 MODAL=50<TOAST=90，UI.modal/toast 入口，场景切换自动清）+ Modal 基类（幂等 _assemble/暗幕/closed/bg_click_cb）+ 双结算层迁入（**KAN-98 net_battle 结算拦不住手牌根治**，In Review）+ DragScroll 让路。F2=chest 继承 Modal + run 弹层走 UI.modal（_dim 删）+ 4×toast 转发 UI.toast + battle 教程覆盖补输入实体（tap 步 STOP/action 步 IGNORE，删前置 _input）。F3=四条规约入 CLAUDE.md 第 4 条架构铁律 + pixel_ui.gd 头。⚠️ test_runner 是离线树（_ready/push_input/绝对路径不可用）——Modal 幂等双入口装配、DragScroll 走 main_loop 相对路径找 UI，写 view 组件测试时注意。
- **Jira 已恢复由我经 Atlassian MCP 维护**（KAN-90~98 全补账：90/91/92=三国化 A1A2/A2.5/A3 In Review、93=A4 待办、94 横版、95 BGM、96 DragScroll、97 UI 改造、98 net 结算 bug；KAN-88 追加增强觉醒、KAN-87 挂起备注）。transition id：11=Idea/21=待办/31=进行中/41=In Review/51=完成；类型名中文（故事/任务/缺陷）；parent 挂 KAN-50。
- 全部已提交推送 master（69bfe6a→82fdc44→f02ce97→70d8515→5d1457b→cfc6d42）。客户端单测 **374/374**。docker 未动过（本轮全是 view/工程层）。

## 待办/欠账
- **真人验收台账 = docs/ACCEPTANCE_SANGUO.md**（用户欠、勾进度在里面）：A 组文案 4 例（部分过）/ B 组精灵 5 例（部分过）/ C 组滚动 C-1~C-5（C-6 过）/ D 组 BGM 2 例 / **E 组横版 E-1/E-4/E-5**（E-2/E-3 过）/ **F 组 UI 改造 8 例**（重点 F-2 联机结算点手牌无反应=KAN-98、F-7 新手教程不误出牌）/ A3 表评审 / S8e 老账。验收过+用户拍板 → 对应 Jira（KAN-90/91/92/94/95/96/97/98/59）→ Done。
- **已知剩余开发工作**（用户定优先级）：
  1. **三国化 A4（KAN-93）**：遭遇/奖励回填（15 遭遇模板全旧 16 卡、100 关奖励只掉 8 旧卡碎片——32 新卡 PvE 零曝光零获取，纯配置可先行）+ 世界观文本（游戏名/章节名 黄巾→讨董→…→三分）+ 正式素材分批接入（依赖美术按 A3/48卡表交付）。
  2. **横版 H3~H6（KAN-94）**：H3 精灵侧视帧约定（联动美术交付口径，建议早定防返工）→ H4 横版 HUD（mockup 先行）→ H5 战斗切横屏 → H6 联机横版真机。
  3. **数值线复盘重启（KAN-87 挂起 + KAN-88 Idea）**：probe 平衡 pass + CV 离群处理（inferno_dragon 超模/battle_ram 压 bone_ram）+ 5 项增强觉醒与 T6/T7/chain 延后件。
  4. **UI 整体大改版**（A3 决策 9 预留「后续另立项」，未立项）。
  5. V4-S5 赛季+排行榜暂缓中（KAN-41 To Do）。

## 铁律（务必遵守）
- **改 logic/ 或 config/ 后 `docker restart server-verifier-1`**；**加/删卡再另重启 api+gateway**。dockers 常开。
- 配置改完跑 `uv run --with openpyxl python tools/build_config.py --from-json` + `--check`；音频走 build_audio_config.py 同两步。card_progression/arena 不进 Excel 镜像。
- **UI 层级铁律（新）**：覆盖类 UI 一律继承 view/ui/modal.gd 经 `UI.modal()` 推入；提示走 `UI.toast()`；禁手搓全屏 Control 靠树序压层；前置 _input 拦截器必须查 `UI.modal_open()` 让路。细则 pixel_ui.gd 头。
- **三国化包装铁律**：卡 ID/数值/机制冻结；卡名改动 i18n+cards.json 两处同步；稀有度内部枚举不动；faction 不产克制；顶级人物留库。稀有度≠强度；每卡必须能被 counter。
- 一步一确认；每步更 HISTORY.md + 对应 PLAN 文档 + Jira（经 MCP：开工转进行中、完成+验收+用户同意才 Done）；真人验收欠账记 ACCEPTANCE_SANGUO.md；仅用户说"提交"才 git commit+push。
- Windows 跑单测：godot 用完整 winget console exe 路径 + `--headless --path . --script res://tests/test_runner.gd`；heredoc 在 git bash 会截断，python 脚本先写文件再执行。

## 这次要做
先读 CLAUDE.md + HISTORY 最新各段建立认知，然后按我口头指定的候选项开工（A4 回填 / 横版 H3+ / 数值线复盘 / 其它）。plan-first、一步一确认。
