# HISTORY.md — 开发历史与进度记录

> **本文件用途**：给任何接手的人/agent（新开对话也一样）一个**准确、自足**的项目进度与历史。
> 阅读顺序：[PLAN_GRAND.md](PLAN_GRAND.md)（roadmap）→ [PLAN_V5.md](PLAN_V5.md)（**当前阶段权威规划**）+ [PLAN_V4.md](PLAN_V4.md)（V4 联网线参考）→ [CLAUDE.md](CLAUDE.md)（操作手册）→ 本文件（进度总览 + 决策日志 + 当前阶段逐步）。
> **完成阶段的详细逐步历史已归档**：V1/V2 → [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)；V3 → [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。本文件只保留**进度总览 + 决策日志 + 当前阶段**。已完成阶段的 PLAN（V1/V2/V3）也已归档到 `docs/`。
> **维护约定**：每完成一步（或重要决策/踩坑）在此追加（V4 阶段直接写本文件；V3 及更早的详细段只追加到对应 docs/ 归档），随该步 commit。

---

## 快速上手（新 agent 必看）

- **本机是 Windows**（工程根 `F:\godotTowerPush\master`，旧址 `F:\godotProject` 已于 2026-06-28 迁移;shell 用 Git Bash）。**文档历史里的 macOS 命令是早期 Mac 用户留下的**（V1/V2 时期），含义照搬即可：把 `HOME=/private/tmp/godot-home godot ...` 翻成本机的 Godot 完整 exe 路径（`~\bin\godot.cmd` 或 winget 安装的 console exe）。
- 跑全部单元测试（逻辑层验收主手段，带 `HOME` 隔离避免污染真实 home）。文档里的标准命令：
  ```bash
  HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd
  ```
  Windows 下用本机 godot exe 替换 `godot` 即可。退出码 0=全过；非 0=有失败（末尾打印明细）。
- 验证导入 / 生成 .uid：`HOME=/private/tmp/godot-home godot --headless --editor --path . --quit`。
- 测试框架：自写轻量 runner（零依赖）。新测试 `tests/test_*.gd`，`extends "res://tests/test_case.gd"`，方法名 `test_` 开头，自动发现执行。
- push / `brew` / `uv` 等下载走代理：`HTTPS_PROXY=http://127.0.0.1:7897`。

---

## 当前进度总览

| 步骤 | 内容 | 状态 | commit |
|---|---|---|---|
| 0 | 脚手架 + git + 工具链 | ✅ 完成 | `77909c9` |
| 1 | ConfigLoader + 三张 JSON | ✅ 完成 | `a632dcd` |
| 2 | Elixir 圣水系统 + SimClock 固定 tick | ✅ 完成 | `22b75cb` |
| 3 | Deck 循环抽牌 | ✅ 完成 | `1da44e3` |
| 4 | Unit + Lane 推进与碰撞 | ✅ 完成 | `2b5742b` |
| 5 | Tower + Battle 胜负判定 | ✅ 完成 | `b804f67` |
| 6 | SkillSystem 三积木 | ✅ 完成 | `a3cc5e5` |
| 7 | 显示层 MVP（白膜 + UI） | ✅ 完成 | 7a `b33957b` / 7b `304066b` |
| 8 | AIController 规则 AI | ✅ 完成 | `198798f` |
| 9 | 安卓导出 + 触摸 + 竖屏 | ⏸ 缓做（移至 V4 产品化阶段） | — |
| V2-1 | 3-lane 逻辑层 + 侧路公主倒转打王塔 | ✅ 完成 | `adf5cfe` |
| V2-2 | 3-lane 接通（Match+显示层+选 lane+AI 中路） | ✅ 完成（GUI 实机验收通过） | `a1af321` |
| V2-3 | 程序化美术换皮（兵种造型/塔/背景） | ✅ 完成 | `190dc04` |
| V2-4 | 动画与特效（攻击/受击/死亡/投射物/AOE爆点/塔摧毁，仅 view 层） | ✅ 完成（视觉验收通过） | `55c2fb7` |
| V2-5a | 主菜单 + 结算面板（场景闭环骨架，仅显示层） | ✅ 完成（视觉验收通过） | `6891f32` |
| V2-5b | 战斗内 HUD 美化（顶部条/圣水分段/卡面/血条变色，仅显示层） | ✅ 完成（视觉验收通过） | `032dd5f` |
| V2-6 | 规则 AI 升级（攻防结合 + 按 lane 选向 + 难度分级，逻辑层 + 单测） | ✅ 完成（单测覆盖） | `e916a00` |
| V2-7a | 扩卡池（+6 卡 / +4 单位 → 14 卡 / 9 单位，纯 JSON + 单测） | ✅ 完成（单测覆盖） | `dd2cbf1` |
| V2-7b | 多关卡（4 关）+ 选关界面（取代难度界面，关卡自带难度） | ✅ 完成（单测 + headless 烟测） | `dd2cbf1` |
| V2-7c | 组卡界面（自由选 8 张，覆盖关卡默认卡组） | ✅ 完成（单测 + headless 烟测） | `dcdb97e` |
| V2-8 | 数值平衡 pass（轻量：arrows→AOE + baby_dragon 提速，纯配置） | ✅ 完成（单测 + harness 测量；难度曲线交真人验收） | `72ff9c9` |
| V3-1 | **2D 战斗核心 reboot**（取代 lane：地形/流场绕桥/仇恨/软分离+攻击/塔反击/AI/显示层，a–h） | ✅ 完成（单测；画面待真人验收） | `ed08c37`/`4f7aaa8`/`816968a` |
| V3-2 | 空军（飞兵越河 + 对空克制 `attack_targets`） | ✅ 完成（单测；画面待真人验收） | `7ad503d` |
| V3-3 | 新技能积木（亡语召唤 `golem` / 治疗术 `heal`）→ 16 卡 / 10 单位 | ✅ 完成（单测） | `73f99c1` |
| V3-4a | Roguelite 骨架：RunState + 节点地图（线性连战链）+ 连战流转（二元永久死亡） | ✅ 完成（单测 + headless 跑通一条 run） | `9a6fc55` |
| V3-4b | 战间 draft 三选一（确定性候选、改写本 run 卡组、卡组可增长） | ✅ 完成（单测） | `239012b` |
| V3-4c | relic 系统（JSON 数值修正器、effective level 不污染 base、起手圣水） | ✅ 完成（单测） | `239012b` |
| V3-4d | boss/精英节点难度修正 + 局间 meta 解锁 + 存档（user:// 往返）+ 最简 run view | ✅ 完成（单测 + headless smoke；引擎内流程交真人验收） | `239012b` |
| V3-6a | 拖拽部署（CR 式）+ 落点 ghost/合法红绿 + 半场高亮 + 落地涟漪 + 入场缩放（仅 view） | ✅ 完成（单测 172/172；**真人实机 7/7 验收通过 2026-06-16**） | `1999797` |
| V3-6b | 战斗 juice：移动插值 + 受击闪白 + 浮动伤害数字 + 命中顿帧 + 震屏 + 命中火花（仅 view） | ✅ 代码完成（单测 172/172 零回归；手感待真人验收） | `8a09953` |
| V3-6c | HUD 反馈：分段圣水条 + 满槽脉动 + 卡面自绘(费用/不可用扫光/选中) + 下一张预览 + 王冠/倒计时强调（仅 view） | ✅ 代码完成（单测 172/172 零回归；外观待真人验收） | `819a713` |
| V3-6d | 胜负演出（调暗/标题 sting/王冠落入/比分滚动/按钮淡入）+ run 奖励·结算揭示动画（仅 view） | 🚧 代码完成（headless smoke + 单测 172/172 零回归；演出待真人验收） | `c22d601` |
| V3-7 准备 | 美术素材入库（`assets/` 选用 94 + `testAssets/` 库）+ ART_ASSETS 美术圣经雏形（题材=黑暗中世纪幻想） | ✅ 完成 | `6579207` |
| V3-7 ① | 卡牌黑暗中世纪化改名（`cards.json` name 中英定稿，id 不变） | ✅ 完成（单测 172/172；config check ok） | `0cb32f2` |
| V3-7 ② | 多语言 i18n（中英表 + autoload + 像素中文字体 + 6 场景接入 + 设置内切换/存盘） | ✅ 代码完成（6 场景 smoke + 单测 172/172；中文显示真人认可） | `0cb32f2` |
| V3-7 ③ | 美术垂直切片（骑士精灵 / building 塔贴图 / 火爆炸序列 FX + 像素 nearest filter；架构 A：immediate `_draw`+`draw_texture`，仅 view） | ✅ 完成（**真人 6/6 验收通过 2026-06-20**；单测 172/172） | `41c09d5` |
| V3-7b-1 | 量产·单位精灵全量（10 单位 manifest `view/sprite_db.gd` + 走/攻状态派生 + 朝向；修正 ③ 骑士帧 bug） | ✅ 完成（**真人 1-7 验收通过**；单测 172/172） | `4aacb21` |
| V3-7b-2 | 量产·塔（王=building1 / 公主=building6 + 保持长宽比贴地 + 金王冠 + 废墟态） | ✅ 完成（**MCP 截图验收**；单测 172/172） | `4aacb21` |
| V3-7b-3 | 量产·技能命中 FX 按卡区分 + 远程投射物（路线 A 冷却跳升检测；含投射物只射一发 bug 修复） | ✅ 完成（**MCP 计数器验证投射物持续开火** + 真人玩通无错；单测 172/172） | `4aacb21` |
| V3-7b-4 | 量产·地形 tile（Lonesome FLOOR 地面 / simple_water 12帧动画河 / COBBLESTONE 桥；逐逻辑格铺替纯色块） | ✅ 完成（单测 172/172 + smoke） | `f3c8abf` |
| V3-7b-5 | 量产·战斗手牌卡面（兵牌=单位精灵正面帧 / 法术牌=特效图标；draft·组卡卡面留 7b-5b） | ✅ 完成（**真人验收通过**；单测 172/172 + smoke） | `0e73300` |
| V3-7b-5b | 量产·draft 奖励卡 + 组卡界面卡面（Control+TextureRect 加单位/法术肖像；共享 `SpriteDB.card_portrait_tex`） | ✅ 完成（**真人验收通过**；导入解析+单测 172/172+deck_builder smoke） | `39c80ff` |
| V3-7b-6 | 美术圣经定稿（`docs/ART_ASSETS.md`：单位 manifest 帧网格/行/朝向 + 帧坐定方法 + 塔/FX/地形/卡面 as-built + 缺口/许可，决策 42 升级） | ✅ 完成（纯文档） | `eddba86` |
| V3-8 | 音频资源表 + 运行时音频机制（AudioConfig.xlsx→audio_assets.json→AudioManager） | ✅ 代码完成（audio config check；单测 177/177；headless editor 导入通过；真实素材待补） | `0c5ce0e` |
| V3-9 ① | 难度系统扩 5 档（rookie/easy/normal/hard/extreme）+ 标题/配色/5 关 + 降难度底 | ✅ 完成（梯度实测单调；单测 177/177；config check ok；手感交真人） | `0c5ce0e` |
| V3-R | 回归修复：寻路卡桥/塔射箭/亡语落水/攻击动画（真人验收通过 2026-06-21） | ✅ 完成（单测 180/180） | `14a29e5` |
| V3-UI | 像素 UI 设计系统(PixelUI 9-slice) + 6 屏全统一(主菜单/选关/设置/组卡/run/战斗HUD) + 选关返回 bug 修复 | ✅ 完成（真人验收通过 2026-06-21；单测 180/180） | `242b287` |
| V3-5a | 新手战役框架：CampaignState(可重试) + campaign.json 6 教学关 + 战役中枢 view + battle 战役模式 + 菜单入口（含修复选关混入 campaign 关 bug） | ✅ 完成（真人 1-6 验收通过 2026-06-22；单测 186/186） | `80cf141` |
| V3-5b | 新手引导覆盖层：tutorial.json 数据驱动 + battle_scene 引导(压暗/挖洞高亮/手指/气泡, tap+动作推进) | ✅ 完成（真人验收通过 2026-06-22；单测 186/186） | `4364dbb` |
| V4-S0 | 协议/Go 脚手架/Docker/Makefile/Go·GDScript 双端 pb（a proto + b Go cmd + c Docker + d Makefile + e Go pb 生成与 compose 跑通 + f godobuf 接入） | ✅ 完成（单测 190/190；docker compose 5 容器+pg 16.14+redis 验收通过） | `d79dd25`/`d5c71af`/`107fed9`/`8ced7fd`/`9001c2c`/`d4a2698`/`e13a466` |
| V4-S1 | 匿名 device_id 登录（a DB+migrations runner + accounts/profiles schema + b JWT HS256 access30d/refresh90d + device_id FindOrCreateByDevice + c HTTP server net/http + /v4/auth/{login,refresh} + d 客户端 net/auth.gd UUID4+token 持久化 + e 端到端真链路验收） | ✅ 完成（单测 197/197；Go unit 14 + integration 4 + smoke 真跑 PG 新增 row 全过；Jira KAN-37） | `db1e77d` |
| V4-S2 | 玩家档案云存档（a decks 表 migration + b profile repo·乐观锁 CAS·卡组校验 + c HTTP /v4/profile/{get,deck-update}·Bearer 鉴权 middleware·httpx 共享包 + d 客户端 net/profile.gd 离线缓存·冲突重取 + e 端到端真链路验收）；顺带根治 godobuf `Deck`↔V3 全局 `class_name Deck` 撞名（proto 改名 `DeckMsg`，wire 不变） | ✅ 完成（单测 204/204；Go unit + integration auth4+profile6（`-p 1` 串行）全过；smoke PG 实查 decks 落库；Jira KAN-38） | `923733a` |
| V4-S3 | lockstep 实时对战网络层★（a 确定性地基 advance_tick+state_hash + b 协议扩展+ladder 配置+matches 表 + c Go gateway WS+battle room·房间中继·哈希对帐·结算落库 + d 客户端 ws_client+battle_client + e 联机对战场景+LADDER 入口+端到端真链路 + f 心跳+断线重连重放+超时认输 + **g 两台 Windows 真机对战验收**） | ✅ **整阶段收官**（单测 217/217；Go battle 14 unit + integration 全过；端到端真 WS 856 比对 0 分叉 + PG 战绩落库 + 断线重连重放恢复；**两台真机完整对局+实时同步+胜负入库验收通过**；Jira KAN-39 Done） | a~e `7401b6c` / f `99c8d05` / 收尾 `6ea58d5` |
| V4-S4 | 匹配（Redis ZSET + ELO）（a profiles+rating·ELO 结算 + b 匹配器·Redis 队列·窗口放宽 + c Lobby 替代 Hub·FindMatch→配对→建房 + d 客户端匹配流程·会话·主菜单杯数 + e 日志打点+真匹配 smoke + **真机匹配验收**） | ✅ **整阶段收官**（客户端 221/221；Go unit + integration 全过含 Redis 首接入；端到端真匹配 smoke 235 比对 0 分叉 + ELO/杯数入库；**两台 Windows 真机 ELO 配对+完整对局+MMR/杯数入库验收通过**（room-2: 94 vs 97 → 1216/1184）；Jira KAN-40 Done） | a~e `81a1f89` / 收尾 `本提交` |
| **V5-S0** | 配置表骨架（stages/encounters/economy/card_progression 四表 + 样例）+ ConfigLoader 接表校验 + PlayerData 存档草案 + PLAN_V5 定稿 | ✅ 完成（单测 **228/228**；ladder_01 Excel 镜像 drift 为 V4 既有、另行处理；Jira KAN-51 Done） | `61aee91` |
| **V5-S1** | 出兵数值乘区管线（Unit.apply_stat_mult + SkillSystem 透传 + Match 注入双方 + Player 透传）；只缩 hp/damage，speed/range/tick 不动 | ✅ 完成（单测 **234/234**，228 旧测逐位零回归；Jira KAN-52 Done） | `bb9a3b0` |
| **V5-S2** | 玩家存档系统（PlayerData 钱包/卡牌养成/关卡/挂机 + SaveSystem user:// + ensure_cards）+ 战力计算（card_stat_mult/card_power/team_power）+ 解锁解算 | ✅ 完成（单测 **240/240**；Jira KAN-53） | `71b6e3d` |
| **V5-S3** | 闯关骨架 StageProgress（线性推进/解锁/星级判定）+ Match.setup_stage 接 stage（coef→敌方乘区·encounter→敌方卡组·ai_difficulty）+ stages base_level | ✅ 完成（单测 **246/246**，含 headless 跑通一关；Jira KAN-54） | `71b6e3d` |
| **V5-S4** | 卡牌升级（金币·数值曲线·等级上限受阶）+ 养成接进战斗（我方 per-card 乘区） | ✅ 完成（单测 **252/252**；Jira KAN-55） | `e73b348` |
| **V5-S5** | 卡牌升阶（碎片+金币）+ 技能积木解锁机制（CardProgression ops：count/num/unit_field）+ golem 示范 | ✅ 完成（单测 **261/261**，V3 亡语零回归；Jira KAN-56） | `e73b348` |
| **V5-S6** | 经济产出（首通/重复/通用奖励 + seeded shard_drop + 解锁新卡 + 挂机离线金币累计/封顶/领取） | ✅ 完成（单测 **270/270**；Jira KAN-57） | `e73b348` |
| **V5-N1+N2** | 在线地基（决策 48）：持久 WS 会话（登录门/心跳/驱逐/重连）+ 配置服务器化（gameconfig 版本包 + 登录下发 + 客户端薄缓存） | ✅ 完成（客户端 274/274 + Go gameconfig/session 全绿；真 docker 端到端自验：82KB 配置下发+解析+up_to_date 重连；Jira KAN-60/61） | `ada841e` |
| **V5-N3+N4** | 服务器权威经济（决策 48）：状态 + DB（钱包/卡牌养成/关卡进度，懒播种）+ 结算动作（升级/升阶/解锁，服务器算成本+校验+扣+落库） | ✅ 完成（客户端 278/278 + Go economy 单测/集成全绿；真 docker 端到端：服务器播种/拒绝刷/扣费升级；Jira KAN-62/63） | `df4b86a` |
| **V5-N5** | 通关发奖 + sanity（决策 48）：客户端报 (stage_id,stars)，服务器校验（关存在/stars≥1/stars≤starCap/线性解锁防跳关）+ 发首通/重复奖励 + shard_drop 概率掉落 + 记进度（stars max/highest 刷新）；镜像 player_data.grant_stage_reward + stage_progress | ✅ 完成（客户端 279/279 + Go economy +3 集成测全绿；真 docker 端到端 6 场景全过：首通/重复/0星拒/超上限拒/跳关拒(503)/首通碎片；Jira KAN-64） | `84a8071` |
| **V5-N6** | 挂机服务器时钟结算（决策 48）：服务器存 last_collect、按**服务器时间**算挂机产出落库（章节驱动产率 + 封顶）；now 全服务器定，改本地时钟无效；新号播种即计时 | ✅ 完成（客户端 280/280 + Go economy idle 纯函数 3 + CollectIdle 集成 2 全绿；真 docker 端到端 5 场景全过：注册即计时/未通关产0/累计/封顶8h/立即再领0；Jira KAN-65） | `824f3b0` |
| **V5-N7** | 瘦客户端化（决策 48）：`EconomyStateCache`（服务器权威养成状态的非权威本地缓存）+ `PlayerData.apply_server_state` 从服务器快照重建 + `SaveSystem` 本地档降为缓存镜像；开战 `for_battle()` 注入服务器拉来的 level/rank → 客户端算战斗数值 | ✅ 完成（客户端 285/285 +5 测；单测覆盖「改本地档不影响开战」；真 docker get_state 链路验过；真机验收留 S7；Jira KAN-66） | `本提交` |
| **V5-S7（设计）** | UI 整合设计稿 [docs/DESIGN_V5_S7_UI.md](docs/DESIGN_V5_S7_UI.md)：基地 Hub（替换 START 入口）+ 闯关竖向列表 + 养成 collection/detail + 钱包/挂机/战力 + deck builder 接已解锁卡。导航图 + 逐屏像素布局 + 共享组件表 + view→logic 绑定速查 + N7 后接 API 薄层说明 + i18n 串表 + S7a~S7e 子步。**仅设计稿、未写代码**（与 N6 并行不冲突；代码待 N7 后） | 🎨 设计稿完成；Jira KAN-58 正在进行；派生 KAN-67 | `42d9f62` |
| **V5-S7a+b** | UI 整合施工（接 N7 服务器权威）：**S7a** 共享 HUD 组件 `view/ui/hud_widgets.gd`（工厂 + 纯助手 format_int/power_tier/affordable/star_fill）+ `hud_widget.gd`（纯 `_draw` 节点：钱包条/星级/cost药丸/阶pip/数值条/锁罩，**0 贴图资源**，复刻 gen_ui_assets.slab 立体描边搬到运行时）；**S7b** 基地 Base Camp（替换主菜单 START 入口）+ app shell（登录→`EconomyStateCache.refresh` 拉服务器状态→展示钱包/队伍战力(本地算·按推荐着色)/挂机产出+领取）+ `GameState.config()/economy()` 静态持有（不引 autoload）+ `EconomyStateCache.collect_idle` 动作门面。读=服务器快照缓存，执行=API，展示算=本地 ConfigLoader | ✅ 完成（客户端 **290/290**，含 `test_hud_widgets` 纯助手单测；base_camp headless 净启无错；**真 docker 在线截图验收**：钱包/战力920绿/下一关推荐800/闯关·第1章/挂机封顶8h）；Jira KAN-58 正在进行 | `123866c` |
| **V5-S7c+d+e** | UI 整合收官：**S7c** 闯关地图 `stage_map`（竖向三态列表/章节星）+ 领奖开箱 `reward_chest` + `battle_scene` 接闯关模式（`setup_stage`→战后判星→`report_stage_clear` 上报）；**S7d** 养成 `card_collection`（全卡池/锁卡碎片进度/可养成红点）+ `card_detail`（升级/升阶/解锁走 `EconomyStateCache` 门面）；**S7e** `deck_builder` 已解锁池 + 实时战力达标着色 + mode-aware 路由。**★修复必现流程 bug**：stale `GameState.run/campaign`（玩过肉鸽后残留静态态）致闯关战误判肉鸽模式（战后弹肉鸽、不发奖不推进）→ `deck_builder` 开战前清 run/campaign + `level_select` 清 stage_id。**客户端日志**：全流程 `[V5]` 打点（场景/经济/战斗模式/动作）。**服务端日志**：api 请求中间件（`METHOD path→status`）+ economy handler 业务日志（acct/动作/结果），rebuild 后生效 | ✅ 完成（客户端 **290/290**；**真人全流程验收通过**：闯关 1-1 胜 3 星→首通 +300金+5宝石→进度推进 + 1-2 解锁→挂机产出→升级 giant；stale-run repro 验证修复=模式闯关；server rebuild 验请求日志）；真人验收过 → Jira KAN-58 **Done** | `6e9c53d` |
| **V5-S7+** (KAN-67) | 养成卡格多维排序：逻辑层纯函数 `logic/card_sort.gd`（键 rarity/cost/level/actionable + 稳定排序，5 单测）+ `card_collection` 顶部分段控件（4 键 + 升降序，切键套自然默认方向）+ 即时重排（用缓存重建网格、不重拉服务器）+ 记忆上次选择（`user://settings.cfg`）；`_actionable` 去重并入 CardSort 唯一定义 | ✅ 完成（客户端 **295/295**，+5 `test_card_sort`；真机：稀有度↔费切换即时重排观感正确）；Jira KAN-67 Done | `f38f5eb` |
| **V5-S8a** (KAN-59) | 内容铺量①遭遇模板池 3→**15**（按原型补 12 deck：亡灵海/快攻/双坦/法术压制/空军/远程风筝/综合/费用倾泻/boss 等，逐章排布见 PLAN §7）+ ConfigLoader 校验加固（archetype 9 枚举 + deck 8 张**互不重复**）。服务器经济配置驱动 → 两端自动吃到、无需改 Go | ✅ 代码完成（客户端 **300/300**，+5 `test_v5_encounters`；config check ok）；KAN-59 正在进行 | `844fb33` |
| **V5-S8b** (KAN-59) | 内容铺量②平衡 probe harness：**AIController 可选边**改造（构造第 4 参 `controlled_owner`；决策逻辑留「进攻规范帧」、仅读敌方坐标/出落点两处做河中线 y 镜像；opponent 默认边恒等→零回归）+ `tools/balance_probe.gd`（headless AI-vs-AI 确定性跑一局/扫战力门槛）+ `tools/run_balance_probe.gd`（章曲线预览跑批报告）。**实测发现**：双 normal AI 均防守→多数局超时、胜负由微小塔血差+卡组克制主导（对称 1.0× 近平局）→ S8d 宜用激进我方档 + 看 king_hp_pct 细分 | ✅ 代码完成（客户端 **305/305**，+5 `test_v5_probe` 含确定性/dominance/双边落点；`test_ai_controller` 7/7 零回归；对称诊断证镜像无偏置）；KAN-59 正在进行 | `844fb33` |
| **V5-S8c** (KAN-59) | 内容铺量③stages 铺到 **100 关**（生成器）：`config/stages_spec.json`（10 章紧凑 spec + 曲线参数）+ `tools/build_stages.py`（生成器 + `--check` 校验）→ `config/stages.json`（100 关：coef 1.0→2.842、rec 800→2275、boss ×1.1 saw-tooth、奖励随章放大、章 shard_card 解锁铺垫）。服务器经济/客户端 ConfigLoader 配置驱动两端自动吃到（gameconfig sha256 版本自动 bump；服务器需重启容器读新配置）。**钉了 2 样例的测试改配置驱动**：客户端 `test_v5_economy`/`test_v5_stage`、Go `repo_integration_test`（金币精确 + 碎片 `>=` 容差，因 StageClear 对首通/重复都 roll shard_drop） | ✅ 代码完成（客户端 **311/311**，+6 `test_v5_stages_content`，改 2 测配置驱动；Go vet clean + economy 单测过 + **集成测对真 docker PG 全过**（含改过的 `TestRepo_StageClear` + ShardDrop）；`--check` 一致）；KAN-59 正在进行 | `d7730dd` |
| **V5-S8d** (KAN-59) | 平衡 pass：①难度机制做实——**敌塔 HP 随 coef 放大**（`Match.scale_opponent_towers`，我方塔不缩放；probe `enemy_tower_mult` 镜像）+ 2 单测；②真关卡 probe 报告器 `tools/run_stage_balance.gd`（我方=hard 技术基准 + 养成乘区=rec/920 + 敌塔随 coef，量 @rec/-15%/-30% 胜负 + 王塔剩血）；③平衡报告 [docs/BALANCE_V5_S8.md]。**核心发现**：AI-vs-AI **不是可靠绝对裁判**（规则 AI 不主动推塔→早期关王塔满血却超时输；确认两次）；但**曲线形状被验证**（王塔剩血 100%(ch1~3)→0%(ch4+)，难度咬人在 ch4≈coef1.5，符合"早苟中养成"梯度）。曲线保持公式默认、不拟合 AI 假象；**手感绝对校准 → S8e 真人** | ✅ 代码完成（客户端 **313/313**，+2 敌塔缩放测；probe 报告产出）；KAN-59 正在进行 | `d7730dd` |
| **GM 工具** (KAN-68) | 开发作弊工具（决策48 服务器权威→**真改服务器 DB**）：服务器 `economy/gm.go`（`GMApply` 事务改 economy_* 表 + `POST /v5/gm/apply` JSON 请求/proto 响应）+ `cmd/api/main.go` env `GM_ENABLED` 门控（prod 必关）+ compose dev 默认开；客户端 `economy_client/economy_state_cache.gm_apply` + `settings.gd` GM 面板（8 按钮：金币/宝石/全卡碎片/解锁全部/满养成/通关全部/推进1章/重置）。走会话鉴权只能改自己账号 | ✅ 完成（Go `GMApply` 真 PG 集成测全过；客户端 **313/313** + settings headless；**真人点按钮验收通过**）；Jira KAN-68 Done | `d7730dd` |
| **V5-KAN49** | **联机视觉对齐**：把单机 `battle_scene` 的完整视觉（精灵/地形/juice/FX/HUD/演出/音频）搬进矢量白膜的 `net_battle_scene`，逻辑层零改动（lockstep 跑同一 `logic/match.gd`、接口同构）。联机特有 3 适配：①`match_obj.player→_client.local_player()`（side2 本方是 opponent）②owner/side 翻转（颜色/王冠/胜负/落点 owner/己方半场高亮 按 `_flip`）③sim 由 `battle_client.poll` 驱动、view 不调 `update()`，顿帧改**纯视觉**（冻结 `_elapsed` 增量、不影响 lockstep）。3 技术坑：side2 精灵朝向（翻转是平移不旋转像素→`spr_owner` 镜像）/result 是 side 语义（`mine = _flip?2:1`）/演出由 `_on_result` 服务端信号触发非本地判 | ✅ 完成（客户端 **313/313** 零回归；**真人双机对战验收通过**；后续 V5-S9 又补双方名片）；KAN-49 **Done** | `6513162` |
| **V5-S9 改动3** (KAN-70) | GM 解禁：去掉服务端 `GM_ENABLED` 门控，`/v5/gm/*` 始终挂载（所有部署含 prod）+ 同步 compose/注释/文档；仍走会话鉴权只改自己账号。⚠️ 取舍：线上任意玩家可自助刷资源（用户明确要） | ✅ 完成（go build/vet；真 docker api 日志 `GM endpoints mounted — always on`；真人验收过） | 本提交 |
| **V5-S9 改动1** (KAN-71) | 账号身份系统（服务器权威）：proto `LoginResp.is_new`/`Profile.{avatar_card_id,tutorial_done}`/`ProfileUpdateReq·Resp`/`TutorialDoneReq` + `ProfileSummary.avatar_card_id` + 双端 pb 重生成；migration `0007`（profiles +avatar_card_id/+tutorial_done）；profile repo `UpdateIdentity`/`SetTutorialDone` + 名字宽度校验（中文1·英数0.5≤10，+9 例 Go 单测）+ `/v4/profile/{update,tutorial-done}`；登录回 `is_new`；gateway 对手 summary 填头像。客户端 auth/profile/session 接新字段+门面 + 创号页 `account_create`（名字宽度计数 + 全部怪物卡头像网格）。**「需创号」用服务器 `avatar_card_id==""` 判定**（扛创号中途退出） | ✅ 完成（Go profile/auth 单测过 + 真 docker migrate→schema v7 落两列；客户端 editor 全编译干净 + **313/313**；真人验收过） | 本提交 |
| **V5-S9 改动1.1** (KAN-72) | 名片显示：`HudWidgets.nameplate`（怪物头像9-slice框+昵称+可选杯数）→ 主菜单顶部 / PVE 己方左下 / **PVP 双方**（对手头像走扩展的 `battle_client.matched/joined` 信号 + `ProfileSummary.avatar_card_id`） | ✅ 完成（editor 全编译 + **313/313**，`test_net_battle_client` 加头像断言；真人验收过） | 本提交 |
| **V5-S9 改动2** (KAN-73) | 新手引导自动化：登录路由 `!tutorial_done` → 强制单局引导战（复用单关 `campaign_01`+引导覆盖层）→ 战后「完成」`mark_tutorial_done`（服务器落库）→ 回菜单；主菜单移除新手战役入口（campaign 文件/关卡保留） | ✅ 完成（真人验收过） | 本提交 |
| **V5-S9 改动4** (KAN-74) | 主菜单重构：主菜单=天梯征途·闯关·养成·卡组·探险·设置（去退出+新手战役，两旧天梯入口合并为「天梯征途」，养成/卡组上提）；基地 `base_camp` 瘦身只留闯关+钱包+挂机+战力 | ✅ 完成（真人验收过） | 本提交 |
| **V5-S9 改动5** (KAN-75) | 天梯先选卡组再匹配：天梯征途→`deck_builder` ladder 模式→选好**存卡组槽1**（服务端 `lobby.lookupDeck` 按槽取卡组建房）→进匹配；主菜单/基地不再直达 `net_battle`。PVP 卡组池=全卡（公平）、战斗机制不动 | ✅ 完成（真人验收过） | 本提交 |
| **PVP 养成同步** (KAN-76/77) | 养成进 PVP 天梯（决策 2026-07-02：①完全生效不设上限 ②匹配暂不加战力维度、建房日志埋 `prog[lvlsum/ranksum]` 观察口 ③升阶技能积木也生效）。**确定性设计 = 双方 level/rank 由服务端权威下发**：`battle.proto` 新增 `CardProgress{card_id,level,rank}` + `JoinRoomResp.side1/side2_progress`(字段9/10)、双端 pb 重生成；服务端 `lobby.lookupProgress` 读双方卡组 8 张的 `economy_cards`（缺行 fallback 1/1 不 fail 匹配）→ `room.joinRespFor` 下发（重连重放同一 resp 自动带上）；客户端 `battle_client._inject_progress` 把双方 progress 变最小 PlayerData **对称注入** match 两侧 Player → 复用 PVE 管线（per-card 乘区 + `CardProgression` 升阶技能解锁），两端对同一方逐 bit 一致；空 progress 向后兼容白板。**顺带确定性加固**：`card_stat_mult` 阶乘 `pow()`→循环乘法（pow 跨平台末位 bit 不保证一致，进 lockstep 前消除）。塔不随养成缩放；本地 EconomyStateCache 不参与注入（防改缓存作弊） | 🚧 代码+单测完成（客户端 **318/318**：乘区精确锁定/双方注入/同养成 hash 全等/异养成必分叉/白板兼容；Go battle unit+integration 真 PG 过：`TestJoinRespCarriesProgress`+`TestLobby_JoinRespCarriesEconomyProgress`；docker 已重建 healthz 200）；**真人两机验收挂账**（用户 2026-07-02 定：先提交、验收欠着）[docs/ACCEPTANCE_V5_PVP_PROGRESSION.md](docs/ACCEPTANCE_V5_PVP_PROGRESSION.md)（6 例：下发日志对帐/乘区肉眼可见/golem 亡语双端触发/全程无 hash mismatch/断线重连不丢养成/白板零回归），验完再 Done | `c850a28` |
| **PVE 防作弊层1+层2** (KAN-78/79) | 堵「伪造 StageClear 秒推 100 关 / 改内存必赢」（用户 2026-07-03 拍板层1+2 一起做）。**层1 服务端 sanity**：`POST /v5/pve/start` 开战报到（服务器时钟 started_at + 从 economy_cards 读 deck 养成**权威快照** + 校验关存在/线性解锁/8 卡全 unlocked——顺带堵未解锁卡进战斗）→ migration `0008 pve_battles`；StageClearReq 加 `battle_id+BattleSummary`(proto 字段3/4 + PveStart/PveReport/PveCmd/PveHashRec 消息 + MsgId 68/69 + ErrorCode 504)，结算同事务消费会话：墙钟 elapsed≥`anticheat.min_stage_duration_s`(15s 堵秒推)/声称 ticks≤墙钟×1.15+5(无法时间压缩)/服务器实收 side1 指令≥1/星数与摘要逐星自洽(king_hp_pct/time_under)/一局一次消费(防重放)。**层2 录制+重放验证**：`Match.update` 加 pve_tick/in_tick/tick_observer + `Player.try_play_card` 加 play_observer + **落点量化毫 tile**(录制值=执行值) → `net/pve_recorder.gd` 录双方出牌(tick+相位 gap/in——玩家间隙出牌/AI tick 内出牌)+每 10 tick state_hash，战斗中周期批量 `POST /v5/pve/report`(服务器按到达时间记批次→时序真实性)；`logic/pve_replay.gd` 重放器**不跑 AI**(AI 指令也在流里)按「gap 牌→regen→in 牌→step」逐 bit 复现+hash 对帐；`tools/pve_verify.gd` headless CLI + Go `cmd/verifier`+`internal/verify`(轮询 pve_battles、SKIP LOCKED 多实例安全、抽样率可配、exec Godot 重放、verdict 交叉核对声称摘要——**哈希是真的但谎报时长/王塔血骗星也抓**、mismatch→accounts.ban_status=1 shadow 只记不罚) + `Dockerfile.verifier`(debian+Godot linux headless，项目运行时挂载+`--headless --editor --quit` 预热 class cache，代码更新 restart 即可) → **compose 第 6 容器**。`view/battle_scene` 闯关开战报到失败不让开战(断线即不可玩)+time_under 判星改 pve_tick/10 与服务器同源；`stage_map` 上报透传。**踩坑**：①AI in 相位 tick 戳 = pve_tick+1(出牌时计数未++)；②重放须跑到 battle over 才能复算胜负；③容器 class_name 解析需 headless editor 预热生成 global_script_class_cache | 🚧 代码+测试完成：客户端 **327/327**（录→放 hash 全等/篡改指令必分叉/改养成快照必分叉/录制器零侵入 sim/胜负时长复算一致/wire 往返）；Go unit+integration 真 PG 全过（校验矩阵 7 拒绝分支 + verifier 取队/PASS/MISMATCH+shadow/抽样/空队）；**端到端真链全通**（真实局 Windows 录 → 插库 → verifier 自动捞 → Linux 容器重放 → PASS 写回，顺带验证跨平台确定性）；**真人验收挂账**（用户 2026-07-03 定：先提交、验收欠着，Jira 挂 In Review）[docs/ACCEPTANCE_V5_PVE_ANTICHEAT.md](docs/ACCEPTANCE_V5_PVE_ANTICHEAT.md)（6 例），验完再 Done | 本提交 |

> **当前阶段 = V5 实时在线 F2P 闯关养成（决策 48，服务器权威）**。权威规划见 [PLAN_V5.md](PLAN_V5.md)；V4 联网地基（账号/lockstep/匹配）S0~S4 完成、决策 48 起转为 V5 主干（推翻决策 47「单机本地」）。以下 V4 段为历史记录。**V1/V2/V3 全部完成**——V1 机制白膜 → V2 3-lane + 程序化换皮 + AI 难度 + 内容平衡 → V3 2D 战斗 reboot + 空军 + 新积木 + Roguelite 主轴 + 交互手感 + 精灵美术 + 音频骨架 + 难度 5 档 + 像素 UI 设计系统 + 新手战役 + 引导。V1/V2 详细见 [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)，V3 详细见 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)。**V3-9 平衡剩余子项**（数值/节奏调优 + 设置/导出/上架打磨）与 V4 早期阶段（S0~S2 账号/档案）可并行。**V4-S0/S1 整体收官**：S0（7 commits / 6 子步 a~f）打底 + S1（1 commit / 5 子步 a~e）匿名 device_id 登录端到端通（客户端 UUID4 → protobuf → docker api → PG accounts/profiles → JWT/refresh → user://auth.cfg 落盘）。Jira KAN-36/KAN-37 同步 Done。**V4-S2 收官**：玩家档案云存档端到端通（客户端 `net/profile.gd` ↔ `/v4/profile/{get,deck-update}` ↔ PG decks/profiles；Bearer 令牌鉴权 + 乐观锁版本冲突 409 + 离线缓存兜底；顺带根治 godobuf `Deck` 与 V3 全局 `class_name Deck` 撞名隐患 → proto 改 `DeckMsg`，wire 不变）。Jira KAN-38 Done。**V4-S3 整阶段收官**：lockstep 实时对战网络层★（a 确定性地基 `Match.advance_tick`+`state_hash` → b 协议扩展+ladder 配置+matches 表 → c Go gateway WS+battle room → d 客户端 `net/ws_client`+`net/battle_client` → e 联机对战场景+LADDER 入口 → f 心跳+断线重连重放+超时认输 → **g 两台 Windows 真机对战验收通过**）。**端到端真 WebSocket 856 比对 0 分叉 + PG 战绩落库 + 断线重连重放恢复 + 真机完整对局实时同步胜负入库 → lockstep 整条路线（不重写 Go 战斗逻辑、两端各跑 logic+哈希对帐）验证成立**。Jira KAN-39 Done。**V4-S4 整阶段收官**：匹配（隐藏 MMR/ELO @1200 + Redis ZSET 队列 + 窗口放宽）——profiles 加 rating + ELO 结算 → Redis 匹配器 → Lobby 替代 Hub（FindMatch→配对→建房）→ 客户端匹配流程+会话+主菜单杯数 → 日志打点+真匹配 smoke → **两台 Windows 真机匹配验收通过**（room-2: acc 94 vs 97 ELO 配对+完整对局+MMR 1216/1184·杯数 ±30 入库）。Jira KAN-40 Done。**V5 进度（决策 48）**：本地原型 S0~S6 完成（养成/经济/闯关逻辑）→ 在线化 **N1~N7 完成**（持久会话 + 配置服务器化下发 + 服务器权威经济状态/结算/通关发奖+sanity/挂机服务器时钟/**瘦客户端化**，真 docker 端到端验过）→ **在线化整线收官**，下一站 **S7 UI（接服务器）/ S8 内容平衡**。**S7 UI 设计稿先行完成**（[docs/DESIGN_V5_S7_UI.md](docs/DESIGN_V5_S7_UI.md)，KAN-58 正在进行；派生 KAN-67 养成卡格多维排序 To Do），代码接 N7 落地的 EconomyStateCache。**S7 UI 整合全部完成（a~e，KAN-58 Done）**：共享 HUD 组件 + 基地 + 闯关地图/领奖开箱 + 养成 collection/detail + deck builder 已解锁池；修复 stale-run 闯关误判肉鸽的流程 bug；补全客户端 `[V5]` 全流程日志 + 服务端 api 请求/economy 业务日志。**真人验收用例 [docs/ACCEPTANCE_V5_S7.md](docs/ACCEPTANCE_V5_S7.md)（7 例：基地/闯关地图/全流程开箱/排序/养成详情/deck/stale-run 回归）全过**（纪律：表现层/交互新内容必须给真人写可执行验收用例，MCP 截图只算自检）。**S7+KAN-67 全部 Done**。**S8 内容铺量 + 平衡进行中（KAN-59）**：S8a 遭遇模板池铺到 15 + S8b 平衡 probe harness（`ai/ai_controller.gd` 可选边 + `tools/balance_probe.gd` headless AI-vs-AI + runner）+ S8c stages 生成器铺 **100 关**（`config/stages_spec.json` + `tools/build_stages.py` → `config/stages.json`；coef 1.0→2.842、rec 800→2275、boss saw-tooth；钉 2 样例的客户端/Go 测试改配置驱动）+ S8d 平衡 pass（**敌塔 HP 随 coef** 做实 + 真关卡 probe 报告 + [docs/BALANCE_V5_S8.md]；**发现 AI-vs-AI 不可作绝对裁判**、曲线形状被验证、手感校准留 S8e）代码完成、**客户端 313/313**、Go 集成测真 PG 全过；另做 **GM 开发作弊工具（KAN-68 Done）**（设置内面板 + `/v5/gm/apply` 真改服务器 DB，env 门控 prod 必关，真人验收过）。**S8e 真人验收难度曲线挂起欠着**（用户暂无精力跑 100 关；用例已写 `docs/ACCEPTANCE_V5_S8.md`；故 KAN-59 仍「正在进行」，待 S8e 验完手感+调旋钮再 Done）。V4-S5 赛季/榜暂缓（KAN-41）。**联机视觉对齐（KAN-49）完成、真人双机验收通过**（单机精灵/FX/手感搬进 `net_battle_scene` 替换原矢量白膜；V5-S9 又补双方名片）。

**测试**：客户端 **327/327**（`HOME` 隔离）；服务端 Go unit（economy/session/gameconfig/battle/rating/matchmaking…）+ integration（auth/profile/battle/economy 持久化，跨包 `-p 1` 串行，需 PG+Redis）全过。**Docker**：5 容器（pg:5432/redis:6379/gateway:8081/api:8080/battle），gateway+api 挂 `../config`（决策 48 配置服务器化）。**分支/远端**：稳定线 `master`（主干开发——每任务从 master 切临时 feature 分支/worktree、验证过再合回；旧 `develop` 已于 2026-06-28 并入 master 删除）、`release` 为 Antigravity（Google IDE）创建的安卓打包分支（跟随 master，agent 默认不动）、`origin`=github.com/jchensh/godot-clash-pusher ；用户说「提交」才 commit + push（走代理）。**配置工作流**：改 `config/*.json` → `uv run --with openpyxl python tools/build_config.py --from-json` 同步 `GameConfig.xlsx` → `--check`；音频单独走 `config/AudioConfig.xlsx` → `config/audio_assets.json`，用 `tools/build_audio_config.py --check` 校验。**godot-ai MCP**：表现层辅助（仅编辑器开着时可用），默认不主动用——细节见 [CLAUDE.md](CLAUDE.md) / [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

---

## 关键决策记录（Decision Log）

1. **语言 = GDScript**：装的是 Godot 标准构建（非 .NET/Mono），且 PLAN 未提 C#。
2. **逻辑 tick = 10Hz（`SimClock.TICK_DELTA = 0.1s`）**：取 PLAN §8 示例值。配置里的速率（如 `elixir_regen_rate`）一律按**每秒**解释，tick 频率改变不影响数值含义，故此值低风险、可后改。**（用户 2026-05-30 确认保持。）**
3. **逻辑层数值用「每秒」单位 + dt 累加**：而非"每 tick 固定量"，保证 tick 频率与数值解耦。
4. **ConfigLoader 输出字典**而非 typed 数据类：遵守"不过度设计"，消费方（Step 4/6）真正需要时再加包装。
5. **测试用自写 headless runner**：零外部依赖（用户选择）。
6. **配置数据存为字典 + 交叉引用校验**：主动校验 deck→card、spawn_unit→unit 的引用完整性，提早抓 id 笔误。
7. **起始圣水 = 0（空槽开局）**：PLAN/配置未定义起手圣水；先按 0 做，将来如需半槽起手再加 `levels.json.elixir_start` 字段（用户 2026-05-30 确认）。
8. **`attack_range` = lane 进度比例**：用户 2026-06-06 确认，范围数值按 `0.0~1.0` 的 lane 进度解释。
9. **`target_type` = 单位自身类型**：2026-06-06 决策，`ground` / `air` 表示单位属于地面/空中，用于命中筛选；攻击能力后续若需要用独立配置字段表达。
10. **`attack_speed` = 攻击间隔（秒/次）**：Step 4 决策，单位初次接敌可立即攻击，攻击后按 `attack_speed` 秒进入冷却。
11. **Lane 目标选择 = 范围内最近敌人**：Step 4 决策，单位只打同 lane 中距离最近且在自身 `attack_range` 内的敌方单位；未接敌时沿 owner 方向推进，接近前方敌人时停在自身攻击范围边界。
12. **三塔制（1 王 + 2 公主）/方**：Step 5 决策（用户 2026-06-07 确认）。塔血取自 `levels.json.tower_hp`（king/princess）。`Tower` 只是血量容器（kind/owner/hp），位置由 Lane/Battle 接线。
13. **王塔归零 = 该方立即负**：Step 5 决策（用户 2026-06-07 确认）。公主塔被摧毁**不**结束对局，只减少该方剩余塔血。三塔才有层次。
14. **超时（match_duration）按剩余塔血总和判胜负**：Step 5 决策。时间到 → 双方在场塔血求和，多者胜、相等判平。
15. **V1 单 lane 两端接双方王塔**：Step 5 决策（用户 2026-06-07 确认）。单位推到尽头直接削敌王塔，使 1-lane 阶段也能按王塔归零正常结束；两座公主塔仍实体化、满血计入超时比拼，扩到 3 lane 时再接公主/中路。
16. **Lane↔Tower 接线方式 = Lane 持两端可空塔引用**：Step 5 决策。`Lane.set_towers(start,end)`；不接塔时为 null，行为与 Step 4 完全一致（旧测试不受影响）。单位攻击优先级：范围内敌方单位 > 尽头敌塔。

> 以下 17–21 为 **Step 6（SkillSystem）开工前提**，用户 2026-06-07 确认。原 PLAN §9 遗留的「多积木结算顺序」「direct_damage 的 target 枚举」在此定稿，并补全 `aoe_damage` 圆心/半径与出牌指令口径。

17. **多积木卡牌结算顺序 = 数组顺序、自上而下、逐个同步结算**：`skills` 数组里多个积木严格按下标先后执行，前一个执行完再下一个；策划用数组次序控制先后，不引入优先级字段。当前 8 张卡均为单积木，本规则面向未来叠积木的卡。
18. **`direct_damage.target` V1 仅实现 `first_enemy_in_lane`**：语义 = 出牌方指定 lane 中**最逼近出牌方自己塔**的敌方单位（玩家塔在 progress 0 → 取 progress 最小的敌方单位；对手塔在 1 → 取最大）。该 lane 无敌方单位则**空放**（无效果）。V1 的 direct_damage 只打单位、不打塔。其余 target 取值（如 nearest_enemy / enemy_tower）后续用 `match` 分支扩展，不改架构。
19. **`aoe_damage` 圆心/半径口径**：`radius` 按 lane 进度比例解释（`0~1`，与 attack_range 同尺度）；V1 为**沿 lane 的一维范围**——命中目标 lane 中 `|progress - center| <= radius` 的敌方单位。圆心 `center` 由出牌指令携带（玩家点哪 / AI 指定）。`config/cards.json` 里 `fireball.radius=1.5` 为可调占位（V1 覆盖整条 lane）。跨 lane 溅射留到多 lane 阶段（需二维坐标）再做。
20. **技能伤害 V1 只打敌方单位**：`aoe_damage` / `direct_damage` 仅作用于出牌方的敌方单位，不误伤己方、不打塔（简化；CR 式友伤后续如需再开）。
21. **出牌指令统一为 `(card_id, owner_id, lane_index, target_progress)`**：`spawn_unit` 在 `(lane_index, target_progress)` 处生成 `count` 个该单位（owner = 出牌方）；`aoe_damage` 用 `target_progress` 作圆心；`direct_damage` 只用 `lane_index`。部署区限制属 Step 7 输入层，逻辑层信任传入位置。**SkillSystem 不校验/扣圣水**（圣水门槛是上层 Player/显示层职责），只负责执行技能效果——对齐 §6 验收「出一张卡能正确触发 生成/直伤/AOE」。

> 22 为 **Step 8（AIController）出牌规则**，用户 2026-06-07 确认（原 PLAN §9「规则 AI 出牌优先级表」在此定稿）。

22. **规则 AI = 简单进攻型 + 中等节奏**：①圣水 `get_int() >= 6` 才考虑出牌；②出「出得起且有用」的**最贵**牌——兵随时有用、伤害法术仅在对面 lane 有敌方单位时才算有用（否则跳过，不空放）；③兵部署在自家塔前 `progress 0.9` 往 0 推，法术落在「最逼近 AI 塔的敌方单位」处；④两次出牌最小间隔 `1.0s`（防一次性倾泻）；⑤**确定性、无随机**（利于测试与复现）。V1 单一难度，`levels.json.ai_difficulty` 暂为占位。AI 一律经对称入口 `opponent.try_play_card` 发指令（与玩家同路径）。

> 23 为 **V1 收官 + V2 范围 + 文档重构**，用户 2026-06-07 确认。

23. **V1 在 Step 8 收官；Step 9（安卓打包）缓做**：当前阶段编辑器内即可体验/继续开发，打包对玩法迭代无帮助，降级到后续阶段（需要分发到手机时再做）。**V2 范围与顺序 = A→D→B→C**：A 玩法深度（核心 = 3-lane，必做）→ D 表现/换皮 → B AI 深度 → C 内容/数值；**V2 不做空中/地面克制**（留后续）。**文档重构**：原 `PLAN.md` → `PLAN_V1.md`（V1 历史规格存档）；新增 `PLAN_V2.md`（V2 分步施工图）与 `PLAN_GRAND.md`（全项目 roadmap，粗粒度）。CLAUDE/AGENTS/HISTORY 的「必读/规格」指针改指 PLAN_GRAND + PLAN_V2。

> 24–25 为 **V2-1（3-lane 逻辑层）开工前提**，用户 2026-06-08 确认（PLAN_V2 §4 两个待细化项至此定稿）。

24. **侧路公主塔被摧毁后，该 lane 单位转打王塔**（皇室战争式「拆侧塔开路、威胁王塔」）：侧路（lane 0/2）主塔为公主塔；公主塔归零后，该 lane 内推到尽头的单位改为攻击该端**王塔**。实现 = `Lane` 持兜底引用 `king_at_start/king_at_end`，`_enemy_tower_for` 改为「主塔活着打主塔，主塔毁则打兜底王塔」。中路（lane 1）主塔本就是王塔，无需兜底。三条 lane 的兜底王塔指向**同一座**王塔对象，故中路 + 已破侧路对王塔的伤害天然累加。
25. **部署规则 = 仅己方半场（progress 0~0.5）、任意 lane 可选**：玩家出兵落点限己方半场，但可自由选 3 条 lane 中任意一条。⚠️ **本规则的强制校验留到 V2-2**（与出牌选 lane 的输入层一并做）；V2-1 仅完成 3-lane 拓扑与转火逻辑，逻辑层暂仍信任传入的 `(lane_index, target_progress)`（沿用决策 21）。

> 26–28 为 **V2-2（3-lane 接通 + 显示层 + 出牌选 lane）开工前提**，用户 2026-06-08 确认。

26. **越界部署 = 拒绝出牌**：含 `spawn_unit` 的兵牌，落点 `target_progress` 必须在出牌方己方半场（玩家 `[0,0.5]`、对手 `[0.5,1.0]`），越界 → `try_play_card` 返回 false、不扣圣水、不抽牌（皇室战争式）。**纯伤害法术**（无 spawn 积木，如 fireball/arrows/zap）**不受半场限制**，可打敌方半场。校验落在对称入口 `Player.try_play_card`（玩家/AI 同受约束）。
27. **AI V2-2 最小适配 = 固定中路（lane 1）**：AI 出兵与感知敌情都只在中路，确保 3-lane 下出牌不报错、保持确定性。完整的「按 lane 选攻防方向 + 难度分级」是 V2-6（B）的事，此处不做。
28. **出牌交互 = 先选卡再点落点（tap-to-place）**：点手牌选中 → 点己方半场某 lane 落点部署；落点的 lane 由点击 x 最近列决定、progress 由点击 y 决定并钳在己方半场。拖拽（drag-drop）留后续表现优化（V2-5/后续）。

> 29 为 **表现层阶段引入 Godot AI MCP**，用户 2026-06-08 确认安装并纳入 git。

29. **Godot AI MCP = 表现层辅助工具，不替代测试/真人验收**：选用 `hi-godot/godot-ai`（https://github.com/hi-godot/godot-ai，MIT，导入版本 `2.6.1`；**2026-06-16 编辑器内自升级到 `2.7.5`**，作为单独 chore 提交入库）。它通过 Godot 编辑器插件启动本地 MCP server（HTTP `127.0.0.1:8000/mcp`、WebSocket `127.0.0.1:9500`），供 Codex / Claude Code 读取场景树、截图、日志、编辑器状态并辅助 UI/动画/特效排查。逻辑正确性仍以 headless test runner 为准；写操作仍遵守一步一确认；主观视觉/手感验收仍交用户确认。

> 30 为 **V2-4（动画与特效）事件源选型**，用户 2026-06-09 确认。

30. **V2-4 动画事件源 = 路线 A（纯显示层、零改逻辑）**：受击/死亡/塔摧毁靠显示层逐帧 diff 血量还原；攻击配对/投射物来源靠显示层复刻 `Lane` 的目标选择（范围内最近敌方单位 + 尽头敌塔）还原；玩家法术按点击点/直伤目标精确出特效，AI 法术（显示层看不到其经 `opponent_controller.tick` 的出牌）按「同帧某 lane ≥2 个玩家单位聚集掉血」推断爆点（近似，带节流 + 聚集窗）。代价：攻击/投射物配对为启发式、AI 法术落点为近似；收益：逻辑层一行不改、不扩大范围、无新单测、契合架构铁律「显示层每帧读逻辑状态画出来」。备选路线 B（逻辑层每 tick 发可测事件缓冲，显示层 drain 精确驱动）记录在案，若将来精确度不足再升级。

> 31 为 **配置体系迁移到 Excel 源表**，用户 2026-06-09 确认。

31. **配置工作流 = JSON / Excel 双入口，agent 默认 JSON 优先**：Godot 运行时仍读 `config/cards.json`、`config/units.json`、`config/levels.json`，避免引入 Excel 运行时解析依赖、也不改战斗逻辑。Codex / Claude 修改配置时优先直接改 JSON（更省上下文、路径更短、贴近运行时），确认没问题后运行 `tools/build_config.py --from-json` 把当前 JSON 覆写同步到 `config/GameConfig.xlsx`。人类策划仍可直接改 Excel，再运行 `tools/build_config.py` 生成 JSON。提交前统一跑 `tools/build_config.py --check` 与 Godot 单测。若 Excel 可能有用户尚未同步到 JSON 的手工改动，agent 不得直接 `--from-json` 覆盖，必须先询问。

> 32 为 **V2-5（D 模块收尾）开工前提**，用户 2026-06-10 确认。

32. **V2-5 拆 3 小步 + 音频缓做 + UI 保持全英文**：V2-5 原打包「UI 美化 + 音频 + 主菜单 + 结算闭环」，按「一步一确认」拆为 **V2-5a 场景闭环骨架（主菜单 + 结算面板 + 菜单→对局→结算→菜单）→ V2-5b 战斗内 UI 美化 → V2-5c 音频**，每小步停下做真人视觉验收。**音频本阶段缓做**（既不引入外部 CC0 音效素材、也不先做程序化合成），留到 a/b 之后单独处理；**UI 保持全英文**（延续 7b 决定，不导入 CJK 字体、零字体依赖）。理由同 V2-3/V2-4 零外部素材路线：先把场景闭环与可玩骨架立起来再逐步美化，避免一步铺太大、便于分段验收。

> 33 为 **V2-6（规则 AI 升级）开工前提**，用户 2026-06-10 确认（PLAN_V2 §4「难度分级差异维度」至此定稿）。

33. **规则 AI = 攻防结合 + 按 lane 选向 + 难度 3 档（easy/normal/hard）4 维度**：难度从 `levels.json.ai_difficulty` 解析（`Match.setup` 存 `ai_difficulty`、`AIController` 读取，构造参数可覆盖便于单测；难度选择界面经 `GameState` 静态变量传入覆盖关卡值）。差异维度：①圣水阈值（easy 8 / normal 6 / hard 4）②出牌间隔（2.0 / 1.2 / 0.6 s）③是否防守（easy 否，normal/hard 是）④进攻选路（easy 固定中路，normal/hard 集火「守军塔血最低」的 lane）。**防守口径**：玩家单位 `progress ≥ 0.55`（越中线逼近 AI 塔）该 lane 受威胁，优先在塔前 `0.9` 空投最贵可用兵 body-block，防守优先于进攻。**进攻口径**：选目标 lane 出最贵可用兵；最贵可用为法术且场上有敌方单位时落在最前敌人处（不空放）。确定性无随机（延续决策 22）、tie-break 取小 index、仍走 `opponent.try_play_card`（玩家/AI 对称）。

> 34 为 **V2-7（C 模块：内容/数值）开工前提**，用户 2026-06-10 确认（PLAN_V2 §4「V2-7 细化」至此定稿）。

34. **V2-7 拆 3 小步 + 卡池适中 + 关卡=独立遭遇战 + 自由组卡 + 会话内持久化**：按「一步一确认」拆 **7a 扩卡池（纯 JSON + 单测）→ 7b 多关卡 + 选关界面 → 7c 组卡界面**。①**卡池适中**：+6 卡 / +4 单位 → 14 卡 / 9 单位，覆盖坦克/群攻/快攻/空军/远程/法术原型，仍只用 `spawn_unit`/`direct_damage`/`aoe_damage` 三积木、**不做空中/地面克制**（V2 范围外），新内容 = 新数值组合 + 法术调参（统一平衡留 V2-8）。②**关卡 = 独立遭遇战，自带难度**：每关携带 AI 卡组 + 塔血 + `ai_difficulty` + 圣水节奏；做「选关」界面，**取代现有难度选择界面**（难度内嵌进每关）。③**组卡 = 自由选任意 8 张唯一卡，不限费用**（原型阶段最简）。④**所选关卡/卡组经 `GameState` 静态变量跨场景传递**（与 `ai_difficulty` 一致、会话内有效、重启重置、不落盘）。最终流程：菜单 → 选关 → 组卡 → 对局 → 结算。

> 35 为 **V2-8（数值平衡 pass）方法与落地**，用户 2026-06-10 确认（PLAN_V2 §3 C「V2-8 数值平衡」至此落地）。

35. **V2-8 = 轻量数值平衡；数据驱动测量、proxy 不可调难度、难度曲线交真人**：用户定**轻量改动**（只治明显废牌/超模牌，不重构费用曲线），优先保**对局节奏 + 关卡难度曲线**。测量用临时 headless harness（`tools/_balance_probe.gd`，AIController 驱动 AI 侧 + 几何镜像控制器驱动玩家侧、同一套 DIFF；多变体扰动出牌相位+卡序取胜率；**验后即删、不入 git**）。三结论：①**对局节奏健康**——带扰动多变体 75–100% 靠拆王塔决胜、时长 40–120s，唯一 0-0 平局仅出现在「完全对称」人造对照组；②**难度曲线无法用 AI-vs-AI proxy 测量**——难度档在 proxy 下倒挂（镜像玩家钻 hard AI「低阈值+反应式防守」浪费圣水的空子；而 easy AI「攒满砸大兵」朴实难缠），**proxy ≠ 真人**（真人打 easy 关慢/单路/不防守会觉得简单，打 hard 关反应快/会防守/多路会觉得难）→ 难度曲线**交真人实机验收**（清单见 V2-8 逐步历史），本步不靠 proxy 调；③**单卡 raw 强度**印证 skeletons/goblins/mini_pekka/giant 为破防引擎（**不削**，否则增平局）、baby_dragon 为明显废兵。据此**仅改两张卡（纯配置）**：**arrows** `direct_damage 150@3`（被 lightning/fireball 双压、无生态位）→ `aoe_damage radius0.5/140@3`（补「中号群清」：log 小→arrows 中→fireball 全场；**意外收益**：经典卡组里 AOE 箭雨清掉防守群兵，对称对局 0-0 僵局消失、全部拆王塔决胜，直接改善节奏）；**baby_dragon_body** 攻速 `1.6→1.3`（DPS 50→62，让 4 费空中远程兵在混合卡组站得住）。swarm/mini_pekka/zap 及各关卡配置（塔血/回速/时长/难度档/AI 卡组）**本轮不动**——各关数值的调整待真人难度反馈后另起一轮。view 层零改动（`battle_scene._play_spell_fx` 按技能类型派发，arrows 改 AOE 自动走爆点 FX）。

> 36 为 **V3（战斗核心 2D 重构 + 买断制单机）方向锁定**，用户 2026-06-10 确认。

36. **V3 = 战斗核心 2D reboot + 混合主轴 + 2D 卡通精灵**：用户判断「3-lane + 无自由地形」的简化丢失了皇室战争「兵自由走位的轻 RTS」核心乐趣，要求向 CR 看齐重构。锁定四大取舍：①**战斗模型 2D 化（取代 lane）**——河 + 左右双桥、每方 2 公主 1 王、**己方半场任意落点**、地面兵流场绕桥、空军越河（**首版先全地面**、空军 V3-2）；②**仇恨 = 完整 CR 式**（默认锁最近敌塔、敌方单位进 `aggro_radius` 转火，可拉扯/风筝）；③**出兵领土 = 固定己方半场**（不做破塔扩张领土，留后续）；④**碰撞 = 软推挤**（体积半径 + 确定性分离，**不用物理引擎**、可单测）。**单机主轴 = 混合**（5–6 关脚本短战役兼新手教学 → Roguelite 终盘：3 act / draft 三选一 / relic=JSON 数值修正器 / 永久死亡 / 局间 meta 解锁，复用 `Match`/`Battle`/`AIController`/JSON 管线）。**美术 = 2D 卡通精灵**（静态精灵 + 现有 tween 鞭 动画、素材包打底）。施工图 + 程序重构设计见 [docs/PLAN_V3.md](docs/PLAN_V3.md)。**改 CLAUDE.md 硬性 DO-NOT**：1D lane 进度 → 抽象 2D 场地坐标（tile 空间）；「不用物理引擎」保留（自写确定性软分离）。**重构策略 = 绞杀式（strangler）**：新 `arena.gd` 与旧 `lane.gd` 并存、逐子步迁移、**单测全程绿**，待 V3-1h 全通后再删 lane.gd 及 lane 单测。（⚠️ 此条 V3-1b 起被决策 37 覆盖为「推倒重来」。）

> 37 为 **V3-1b 重构策略改「推倒重来」+ AI 搁置**，用户 2026-06-10 确认（覆盖决策 36 的绞杀式）。

37. **V3-1b = 推倒重来（rip-out），非绞杀式**：摸查发现 `move_speed`/`attack_range` 量纲在 lane(0~1) 与 2D(tile) 冲突、且共用同一 Unit 字段——保并存需在 units 上挂双份字段（用户否决）。故改**推倒重来**：直接改 tile 量纲、**删 `lane.gd`**。因仅 `battle.gd` preload lane（`view/*`、`ai_controller` 是运行时动态调用、解析不受影响），删 lane 的连带原子 = Unit 2D + arena 移动 + battle 去 lane + **`skill_system` 2D（原 V3-1f 被迫提前并入 V3-1b）** + config/units/cards 量纲 + match/player 2D + 删改相关单测。**AI 暂搁置**（`ai_controller.gd` 留死代码、删 `test_ai_controller`，V3-1g 2D 重写时加回）；**view 暂坏**（解析通过、不运行，V3-1h 接通）。代价：V3-1b~g 期间无可玩画面、只有 headless 单测（用户已接受）。

> 38 为 **V3-4a（Roguelite 骨架）参数与流转口径**，用户 2026-06-15 确认（PLAN_V3 §5「Roguelite 参数：act/战数/map 形态，V3-4 前定」至此为 4a 定稿）。

38. **V3-4a = 线性连战链 + 二元永久死亡 + 3 act × 3 战**：①**节点地图形态 = 线性连战链**（节点按 act 展开成一条扁平链、依次连战、无分叉；节点带 `type(battle/elite/boss)` 与 `act` 标签供 V3-4d 差异化与 view 分组，4a 所有节点同跑普通战斗；分叉/程序化地图留后续，同一 `RunMap` 接口承载、流转不必改）。②**败北模型 = 二元永久死亡**——只有【玩家胜】推进，**对手胜或平局**立即整局失败（draw 视为「未取胜」→ 必须明确取胜才过关；该口径用户已知，可后续否决）；战斗未结束(ONGOING)喂入为防御性 no-op。③**run 规模 = 3 act × 3 战 = 9 节点**（act 数沿用决策 36 锁定的 3；每 act 末节点标记为 boss；战数全走 `run.json` 可调）。④**遭遇来源 = run 节点引用现有 `levels.json` 的 level_id**（复用 `Match.setup(level_id, player_deck_override)` 现成逻辑：用该关 AI 侧/塔/时长，玩家卡组用 run 卡组覆盖；零额外接口；当前仅 4 关先复用，富遭遇池留内容步）。⑤**起始 run 卡组 = 玩家在 deck_builder 选的卡组**，空则用 `run.json` 的 `starter_deck`（与 V2-7c 的 `player_deck_override` 同口径）。⑥**确定性**：`RunState` 带 `seed` 字段但 4a 地图按 config 确定性展开、不实际跑随机（保单测可复现，seed 留后续程序化）；`relics` 字段空置留 V3-4c。⑦**`run.json` 为结构性配置、不进 Excel 镜像**（比照 `arena.json`，`build_config.py`/`--check` 不涉及）。⑧**view 接入（菜单→run→对局→下一节点）不在 4a**——4a 仅 logic+config+单测（对齐 PLAN_V3 §3 「4a 验收 = 单测 + headless 跑通一条 run」），最简 view 留后续小步。

> 39 为 **V3-4b/c/d 一批做完 + 配最简可玩 view**，用户 2026-06-15 确认（要求一口气开发完并在 V3-4 全完成后给「人工引擎内验收清单」）。

39. **V3-4b/c/d 一批做完 + 配最简可玩 view**：本批含让 run 引擎内可玩的最简 view（否则无可人工验收的东西）。各子步口径——**4b draft**：每场胜后三选一，候选 = 卡池中**不在 run 卡组**的卡、**确定性 seeded 洗牌**取 3（`RunRewards`，同 seed 同结果）；选中 → **追加**进 run 卡组（卡组可增长、不替换、去重），故 **`Deck` 放宽**为 ≥HAND_SIZE+1（不再硬限 8）；可 SKIP。**平局/对手胜不给 draft**（沿用决策 38 永久死亡）。**4c relic**：relic = JSON 数值修正器（`relics.json`，结构性、不进 Excel），经 `RunModifiers.effective_level` 作用于 level 的**深拷贝 effective 副本**（圣水回速/上限/**起手圣水**、对局时长、王/公主塔血），**绝不污染 ConfigLoader 基础配置**；多源**顺序叠加** `val=val*mult+add`；relic 奖励在 **elite/boss 胜**后给（普通节点给卡 draft）；**单位级 relic（兵伤/血）留后续**（需注入 SkillSystem 生成路径，本批不做）。`Match.setup` +`modifiers` 形参（空=行为同前、起手圣水仍 0），起手圣水经 `Elixir` 第三参注入。**4d boss/精英 + meta + 存档**：boss/elite 节点经 `run.json.node_modifiers` 用同一修正器引擎**抬塔血**（elite ×1.25 / boss 王×1.5·公主×1.4）实现差异化（AI 难度仍随所引用关卡，不另调）；**meta = 局间持久统计**（runs_started/won、bosses_defeated）驱动**解锁**——relic 上挂 `unlock:{stat:阈值}` 门控，满足才进可用池（`MetaProgress.available_relics`）；**存档落 `user://`**（`SaveSystem`：meta 持久 + run 可续跑，run 地图不存盘由 config 重建后 `load_dict` 恢复进度）。**view = 最简**：`run_scene` 节点链中枢（打节点→回来推进→给奖励→结算）+ `battle_scene` run 模式（读 `GameState.run` 建场、CONTINUE 回中枢）+ 主菜单 ROGUELITE 入口；run 真正可玩，但**引擎内流程/手感交真人验收**。**踩坑**：①新类的 `static from_dict` 引用自身 `class_name` 在 .uid/全局注册前会被 test runner 预检判失败 → 改为**实例方法 `load_dict`、不引用自身 class_name**（合 HISTORY「不依赖 class_name 全局注册」）；②`--script` 的 `_initialize` 期 `add_child` **不触发 `_ready`** → headless smoke 须显式调 `_ready()`（非代码 bug）；③杀进程留下的 `user://` 半档会污染下次 smoke → smoke 前清档。

> 40 为 **V3 后半段施工顺序调整**，用户 2026-06-16 确认。

40. **V3-5（短战役 + 新手引导）推迟到 V3-6（手感）+ V3-7（美术）之后**：原 PLAN_V3 §3 顺序为 5→6→7。用户判断脚本化战役与新手引导应建立在**已成形的交互手感 + 精灵美术**之上——否则对着白膜画面 + 粗糙控制写教学覆盖层与关卡脚本，等手感/美术落地后必返工。**步骤 ID 不重编号**（V3-5/6/7 标签不变，避免跨文档引用错位），仅改执行先后：**执行顺序 = V3-6 → V3-7 → V3-5 → V3-8 → V3-9**。PLAN_V3 §3 表格已按新序重排并加注；下一步由 V3-5 改为 **V3-6（交互与游戏手感）**。

> 41 为 **V3-6（交互与游戏手感）范围与拆步**，用户 2026-06-16 确认。参考业界 UI/UX 范例：皇室战争（拖拽部署/卡片抬起/落点提示/分段圣水/胜利演出）、Vlambeer《The Art of Screenshake》+《Juice it or Lose it》（顿帧/震屏/缓动）、Brawl Stars（受击数字）、Slay the Spire（奖励/relic 揭示）、Apple HIG（≥44pt 触控/拇指区）。

41. **V3-6 = 纯显示层（零逻辑改，沿用决策 30 路线 A）+ 拆 4 个真人验收 gate**：所有手感经显示层逐帧 diff 逻辑状态实现（hp 降→受击数字、新兵→入场、塔 hp→0→爆破），**不动逻辑、无新单测、全交真人验收**。**部署交互 = 拖拽（CR 式）**（用户选定，取代原两段式 tap）：按手牌→拖到场上(落点抬到手指上方避免遮挡)→松手落子；拖拽中画落点 ghost + 合法绿/非法红 + 己方半场高亮。**拆步（执行序 6a→6b→6c→6d，每步一 gate）**：**6a** 部署交互 + 落点 ghost/红绿 + 半场高亮 + 落地涟漪 + 入场缩放；**6b** 战斗 juice（10Hz→60fps 移动插值、受击闪白 + 浮动伤害数字、命中顿帧、震屏、攻击命中 stub FX）；**6c** 圣水/HUD 反馈（分段圣水条 + 满槽脉动、卡牌冷却扫光 + 下一张预览、可用/不可用态、王冠/倒计时强调）；**6d** 胜负与 run 总结演出（王冠落入、胜负 sting、塔爆破序列、结算面板动画；roguelite 奖励/relic 揭示）。**白膜上做**：6a–6d 装的是「手感系统」（插值/伤害数字生成器/震屏/ghost），V3-7 再贴精灵/粒子皮，**近零返工**。

> 42 为 **V3-7 题材 + 美术主风格 + 素材方案**，用户 2026-06-16 确认。

42. **题材 = 黑暗中世纪幻想；主美术 = itch Pixel Grit 精细像素**：骑士/法师/亡灵/兽人/吸血鬼，无机甲/火器（→ 非中世纪卡改名换概念，见 ①）。`testAssets/` 原始库（Pixel Grit 角色/特效/boss bundle + Lonesome/Grand Forests/World Map 三套 **No-Attribution** 地形 + .aseprite 源）；`assets/` 选用集 94 文件（units/towers/terrain/map/fx/bosses）。地形三套分工：Lonesome **Summer** 全色版=战场地面/河/桥、Grand Forests=树木、World Map=run 节点地图（弃 pixelCrawler top-down + PICO-8）。映射/缺口（golem/真龙/真巨人缺→换皮）/许可见 [docs/ART_ASSETS.md](docs/ART_ASSETS.md)。⚠️ Pixel Grit 付费 bundle 授权用户已确认（license 文件待补拷）；仓库公开、用户确认全量入库。

> 43 为 **② 多语言（i18n）方案 + ① 卡牌改名**，用户 2026-06-16 确认（顺序 ①→②→③ 切片）。

43. **i18n = JSON 翻译表 + autoload 运行时构建 Translation（headless 友好）+ 像素中文字体 + 设置内中英切换**：弃 CSV 编辑器导入，用 `config/i18n.json`(en/zh ~80 key) 经 `I18n` autoload 建 `Translation` 注入 `TranslationServer`；locale 存 `user://settings.cfg`、**默认中文**。字体 = Fusion Pixel 12px proportional zh_hans（OFL，Godot 自动禁 subpixel），`project.godot` [gui] 默认主题字体（中英共用）。6 场景全 `tr()`（卡名/relic/难度/数值模板/HUD/结算/奖励）；新增设置页（主菜单入口）切换即时(reload 本页)+存盘。**① 卡牌改名**：13 张改 `cards.json` name（食人魔/狂战士/女巫/怨灵/余烬火颅/亡灵巨像/滚石 + 火球术/箭雨/电火花/闪电术/骷髅兵/治愈术），id 不变、英文名入 i18n。**view 层零逻辑改、无新单测**（表现层）。

> 44 为 **V3 UI/UX 整体优化（像素设计系统 + 全屏统一）**，用户 2026-06-21 确认。

44. **UI = 像素设计系统 PixelUI + 全屏统一**：用户要求菜单/系统界面整体优化、保持像素风（非高清拟物）。立 `view/ui/pixel_ui.gd`（9-slice 按钮/面板 + 色板 + 动态色 sbpixel）+ `tools/gen_ui_assets.py` 生成贴图。落地 = Theme/9-slice（用户选）。**关键约束**：编辑器开着时 MCP 无法为全新 png 生成 `.import`（Godot 双实例锁，headless `--import` 抢锁）→ 定「固定中性样式（按钮/面板）用 9-slice 贴图、动态语义色（难度/稀有度）用程序化 StyleBoxFlat」。6 屏全统一（主菜单/选关/设置/组卡/run/战斗HUD），战斗 HUD 仅色板对齐、战场单位色不动。

> 45 为 **V3-5 新手战役范围**，用户 2026-06-22 确认。

45. **V3-5 = 新手战役（教学专属 6 关 + 可重试 + 无剧情 + roguelite 不锁）**：①关卡 = 新增教学专属序列（`campaign.json` 6 关，焦点 deploy→elixir→bridge→defend→spell→boss + AI 循序），不复用 5 难度关；新增 `campaign_01~06` 到 `levels.json`（⚠️**选关界面须过滤 campaign_* 关，否则混入自由对战**）。②流转 = 可重试（`CampaignState`：胜推进/败留原地重打/全胜通关，区别于 roguelite 二元永久死亡）。③剧情 = 首版极简（关名+focus，无叙事）。④roguelite = 一直开放（不锁）。⑤拆 V3-5a 框架 + V3-5b 新手引导覆盖层。⑥菜单「新手战役」主线金按钮。

> 46 为 **V4 联网升级 + 实时对战方向锁定**，用户 2026-06-23 确认。

46. **V4 = 联网升级 + 实时对战（玩法验证导向）**：用户判断 V3 单机已收尾，要为 PvP/匹配/赛季/排行榜搭服务端基础。锁定：①**战斗权威 = lockstep + 状态哈希校验**（沿用现有 `logic/` 10Hz 确定性 tick，不重写 Go 战斗逻辑）；②**服务端语言 = Go**（高并发 WS、tick 循环、protobuf 一流）；③**网络协议 = WebSocket + protobuf**（移动友好、二进制紧凑；不用 UDP）；④**数据库 = PostgreSQL + Redis**（PG 主存账号/档案/战绩；Redis ZSET 匹配队列+榜单+对局缓存+限流）；⑤**认证 = JWT + refresh token**，前期**匿名 device_id 登录**（无 SMS/邮箱/三方）；⑥**商业模式长期 F2P + 内购解锁/养成**（schema 预留 `purchases`/`unlocks`/`currency` 字段，但**前期完全不实现支付/IAP/养成**）；⑦**部署 = 本地 docker compose**，不上云、不做合规、不做监控告警；⑧**V3 Roguelite + 短战役保留为单人训练营**，不动；PvP 走全新主轴入口；⑨**仓库结构 = 单仓 `/server` 子目录（Go）+ `/proto` 共享 schema**；⑩**客户端平台 = Android + Windows**（iOS/Mac/Linux 不做）。**反作弊深度**：基础 JWT + 状态哈希 + 速率限制；异常检测/封禁推后到 S7。**新增 DO-NOT**：客户端禁止权威化战斗状态——所有指令走服务端转发、状态以双方+服务端三方 hash 对帐为准。**阶段划分**：S0~S5 玩法验证（脚手架/匿名登录/档案云存/lockstep 对战/匹配/赛季+榜）；S6~S12 产品化（战绩回放/反作弊深化/部署/版本/IAP/正式登录/合规/聊天好友）推后。**与 V3-9 关系**：V3-9 平衡剩余子项（数值/节奏调优）与 V4-S0~S2 可并行。施工图见 [PLAN_V4.md](PLAN_V4.md)。

> 47 为 **V5 单机闯关养成方向锁定 + V4 服务端线暂缓**，用户 2026-06-26 确认。

47. **V5 = 单机 F2P 闯关养成（暂停 V4 服务端线）**：用户判断当前首要是丰富单机玩法与留存，暂停 V4-S5+（赛季/排行榜/部署，KAN-41 退回 To Do），转向把单机做成养成驱动的闯关 RPG。锁定（详见 [PLAN_V5.md](PLAN_V5.md)，Epic KAN-50）：①**核心范式 = 战力为底·操作为顶**（养成给有上限的数值；难度 = 系数 + AI 档 + 脏卡组；中等战力差可操作弥补、巨大战力差不能）；②**关卡 = 模板池 × 难度系数曲线**（~15 遭遇模板 + 系数递增 + boss 特化，100+ 关）；③**养成 = 10 级 × 3 阶浅养成**（单卡满 ≈ ×3.0；升级花金币提数值、升阶花碎片 + 解锁技能积木）；④**难度系数线性 1.0→~2.6 + boss 小跳**；⑤**初始 8 张 + 推关攒碎片解锁其余 8 张**；⑥**货币 = 金币（升级）+ 碎片（每卡，解锁 + 升阶）+ 宝石（占位，只产不充）**；⑦**节奏 = 挂机离线金币 + 无体力**；⑧**全程单机本地存档（user://）、不依赖服务端**（V4-S0~S4 成果保留不动）。施工 S0~S8（KAN-51~59）。复用现有 CampaignState/SaveSystem/RunModifiers/SkillSystem/ConfigLoader。**唯一较重新管线 = 出兵数值乘区**（我方按卡 level/rank、敌方按关卡 coef，注入 SkillSystem 生成路径，V5-S1）。

> ⚠️ **决策 47 已被决策 48 取代**（2026-06-26 当日转向）：V5 不再是"单机本地"，改为实时在线 F2P、服务器权威。

> 48 为 **项目转向实时在线 F2P 手游 + 服务器权威（推翻决策 47「单机本地」）**，用户 2026-06-26 确认。

48. **项目定位 = 实时在线 F2P 商业手游（服务器权威）**：用户拍板把项目从"买断/单机本地"彻底转为**按多人在线网游标准开发**。**推翻决策 47「全程单机本地、不依赖服务端」**，并更新决策 36「买断制单机」/ 46「V4 玩法验证·前期不实现支付」的定位（方向就是商业化 F2P；支付/合规按上线节奏推进，不再是"范围外"）。锁定：①**进游戏强制登录 + 持久连接**（启动登录 → 建持久 WS 会话 → **断线即不可玩**，网络抖动自动重连、长断回登录）；②**服务器唯一权威**——账号/钱包/货币/卡养成(等级/阶/解锁/碎片)/关卡进度/挂机 全在服务器 + PG DB；所有产出/扣费/解锁/升级/升阶/挂机结算走服务器（**服务器时钟**，改本地时钟/改存档均无效）；③**配置服务器化**——服务器持权威配置，登录后下发带版本配置包，客户端只内存持有 + 薄版本缓存（**非零配置**：lockstep 战斗需 units/cards/skills/arena 在客户端算，但源在服务器）；④**客户端 = 瘦表现层**——UI + 战斗 sim（lockstep 仍客户端跑保确定性）+ 非权威本地缓存（秒启动/只读展示，永远以服务器覆盖）；⑤**战斗仍客户端 lockstep**（决策 46 不变）——PvE 开战服务器下发权威输入(卡组 + 我方 level/rank)，胜负先**信任客户端 + 服务器 sanity 限制**（服务器复算/反作弊并入后续）；⑥**复用 V4 地基**（Go + PG + 账号 S1 + WS + lockstep），V4 服务端线从"暂缓"转为**主干**。施工：在线地基 N1~N2（持久会话+登录门 / 配置下发）→ 服务器经济 N3~N6（状态/结算/发奖/挂机服务器时钟）→ 瘦客户端 N7 → 原 S7 UI（接服务器）/ S8 内容平衡顺延其后。本地原型 S0~S6 算法镜像进 Go 做权威结算，客户端那份保留做 UI 预览 + 战斗内计算。施工图见 [PLAN_V5.md](PLAN_V5.md)。

---

## V4 — 联网升级 + 实时对战（进行中）

> 方向见决策 46，权威规划见 [PLAN_V4.md](PLAN_V4.md)。**头号工程 = V4-S3 lockstep 实时对战网络层**。S0~S5 = 玩法验证骨架（脚手架/账号/档案/对战/匹配/赛季+榜），S6~S12 = 产品化推后。每步追加在本段（V3 及更早的详细段去 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md) 写）。

### V4-S0 — 协议 + Go 脚手架 + Docker + Makefile + 双端 pb（已完成）
**前置决策**：见决策 46。拆 6 子步：a proto / b Go cmd / c Docker / d Makefile / e Go pb 生成 + docker compose 跑通 / f godobuf 客户端 pb 接入。环境前置：本机 winget 装 Go 1.26.4 + protoc 35.0 + GnuWin32 Make 3.81 + Docker Desktop 4.78（WSL2 后端，首装要管理员 PowerShell `wsl --install` + 重启电脑）。

#### V4-S0a — proto schema 初版（commit `d79dd25`）
6 个 .proto / 26 条消息：common（MsgId 枚举分段 0-9/10-19/20-29/30-39/40-49/50-59 + ErrorCode 分层框架级<1000 + 业务级按模块段 + ProfileSummary）/ auth（device_id 匿名登录 + JWT/refresh）/ profile（乐观锁 `version` + `expected_version` CAS + `unlocked_card_ids`）/ match（FindMatch + MatchFoundPush 带 seed）/ battle（lockstep 核心：DeployCmd 用 `int32 x_milli/y_milli` 定点避浮点漂移 / TickBundle 空 deploys 也照发同步 tick / StateHashUp sha256(32B) / BattleResultPush 含 HASH_DIVERGENCE / Heartbeat 60s 超时认输）/ leaderboard（Scope GLOBAL/ARENA + season_id=0=当前）。帧格式 `[2 bytes msg_id (be u16)][N bytes protobuf payload]`，PING/PONG 无 payload。protoc 35.0 dry-run 全过、无 warning。

#### V4-S0b — Go 服务端脚手架（commit `d5c71af`）
- `server/go.mod`（module `github.com/jchensh/godot-clash-pusher/server`, go 1.23）。
- 4 个 cmd binary 占位：`gateway`（WS 接入，V4-S3 起填）/`api`（HTTP API，V4-S1 起填）/`battle`（room，V4-S3 起填）/`migrate`（一次性 CLI，V4-S1 起填）。
- `internal/version`（跨 cmd 共享版本常量 + 单测示范，"按需建包"避免预先建 8 个空 internal 目录）。
- `server/{README.md,.gitignore}`。
- 验证：`go build/test/vet` 全过；4 个 cmd 都能 `go run` 启动打印 boot log 后退出。

#### V4-S0c — Docker 化（commit `107fed9`）
- `server/Dockerfile`：multi-stage（golang:1.23-alpine builder → alpine:3.20 runtime）打全部 4 binary 到 `/usr/local/bin/`。
- `server/docker-compose.yml`：5 容器（postgres:16-alpine + redis:7-alpine + gateway+api+battle 共享 `gcp-server:dev` 镜像）+ pg/redis healthcheck + `depends_on` + `.env` 通过 `${VAR:-default}` 注入配置 + 端口映射（5432/6379/8080/8081）。
- `server/{.dockerignore,.env.example,migrations/0001_init.{up,down}.sql}`（migrations 仅占位 schema_migrations 标记表）。
- 4 个 cmd main.go 升级为 `signal.NotifyContext` 等待 SIGINT/SIGTERM（docker 容器健壮性的最小演进，V4-S1+ 直接复用此模板）。

#### V4-S0d — 根级 Makefile（commit `8ced7fd`）
统一入口：`gen-proto-{go,gd}` / `install-tools` / `build/test/vet/fmt/tidy-go` / `up/down/down-v/logs/ps` / `migrate` / `clean` / `help` / `test-godot`。`PROTO_DIR=proto / GO_PB_OUT=server/internal/pb / GD_PB_OUT=net/proto`。兼容 GnuWin32 Make 3.81（Windows winget 装的老版，避免 .ONESHELL 等新特性）。

#### V4-S0e 前半 — Go pb 生成（commit `9001c2c`）
`go install google.golang.org/protobuf/cmd/protoc-gen-go@latest`（走 `HTTPS_PROXY=http://127.0.0.1:7897`，宿主机 Clash）+ `make gen-proto-go` 生成 `server/internal/pb/{common,auth,profile,match,battle,leaderboard}/*.pb.go`（入 git，新人 clone 即可 `go build`，不必先装 protoc）。
**踩坑**：①初版 Makefile 用 `--go_opt=paths=source_relative` 让 6 个文件（不同 `go_package`）挤同目录 → `found packages auth (auth.pb.go) and battle (battle.pb.go)` 编译失败；改用 `--go_opt=module=github.com/jchensh/godot-clash-pusher/server/internal/pb`，protoc-gen-go 从 go_package 减 module 前缀算相对路径，6 子目录各自一个 Go package。②`server/go.{mod,sum}` 加 `google.golang.org/protobuf v1.36.11` 依赖。

#### V4-S0e 后半 — docker compose 跑通（commit `d4a2698`）
**踩坑**：①容器内 `go mod download` 拉不到 `proxy.golang.org`（被墙，Clash 代理在容器隔离网络外不可达）→ Dockerfile 加 `ARG GOPROXY=https://goproxy.cn,direct` 默认值（国内 Go 模块代理，七牛维护），同时取消 `COPY go.sum` 注释（S0e 起有真实依赖）。②`make migrate` 失败：Git Bash 把 `/usr/local/bin/migrate` 转换成 `C:/Program Files/Git/usr/local/bin/migrate` 让容器找不到 binary → Makefile migrate target 改用裸命令 `migrate`（alpine image PATH 含 `/usr/local/bin`，docker exec 自动查 PATH）。
**验收**（Win11/WSL2/Docker Desktop 4.78）：`make up` 起 5 容器 / postgres+redis healthy / gateway+api+battle 各打印 `boot log — idling until SIGINT/SIGTERM` / postgres 16.14 响应 `SELECT version()` / redis `PING` → `PONG` / `make migrate` one-shot 容器跑完正常退出。

#### V4-S0f — godobuf 客户端 pb 接入（commit `e13a466`）
- `addons/godobuf/`：vendor [oniksan/godobuf](https://github.com/oniksan/godobuf) v0.7.0 for Godot 4.6（BSD 3-Clause），不入库其 200+ test fixture（`test/` 子目录）。
- `Makefile gen-proto-gd`：从占位提示升级为真自动化——循环 6 proto 跑 `godot --headless --path . -s addons/godobuf/godobuf_cmdln.gd --input=... --output=...`，靠 `[ -s file ]` 判产物大小（godobuf 自身退出码不区分成败、`push_error+quit()` 都 exit 0）。新增 `PROTO_NAMES / GODOT / GODOT_TMP_HOME` 变量，可被环境覆盖。
- `proto/*.proto` 兼容性调整（让 godobuf 和 protoc 同时跑得起来）：①`ErrorResp.message` → `detail`（godobuf 把 `message` 当 proto 保留字，protoc 实际允许）；②6 个 .proto `package game.v4.<sub>` 统一改 `package game.v4`（godobuf 不解析 `game.v4.common.X` 完全限定名；protoc 短名跨文件解析依赖同 package；`option go_package` 保留各自独立，Go pb 仍分 6 子目录）；③`ProfileSummary` 引用全部去掉 `game.v4.common.` 前缀（4 处：auth/match/battle/leaderboard）。
- `net/proto/{common,auth,profile,match,battle,leaderboard}.gd`：godobuf 生成（29-50KB/文件，自带跨 import 类型副本如 ProfileSummary，每个 .gd 单文件 self-contained），入 git。
- `net/README.md`：目录用途 + protobuf 工作流 + godobuf 三大坑（保留字 / 同 package / `res://` 路径 bug）+ 典型 encode/decode 代码。
- `tests/test_net_proto.gd`：4 条 round-trip smoke（LoginReq 三字符串字段 / Profile 空消息默认值 int64=0 string="" / DeployCmd 定点坐标 x_milli=4500 y_milli=17000 / BattleResultPush 嵌套 enum Winner.SIDE_1 + Reason.KING_DESTROYED）。
- 单测 **190/190**（旧 186 + 新 4，零回归）。
- 顺手：`server/internal/version` `V4Stage` 标签从 `V4-S0b` 升 `V4-S0e`（log 标签同步）。

> **V4-S0 整阶段收官**：a proto schema → b Go 脚手架 → c Docker 化 → d Makefile → e Go pb 生成 + docker compose 跑通 → f godobuf 客户端 pb 接入。客户端单测 **190/190**；docker compose 5 容器 + postgres 16.14 + redis 验收通过；双端 protobuf 编解码圆环对接。**下一步 V4-S1 匿名 device_id 登录**：device_id → JWT (HS256, TTL 30d) / refresh token (TTL 90d)；`server/migrations/0002_accounts.up.sql` 真实建表 + `server/internal/{auth,store}/` 起包；`net/auth.gd` 客户端 token 存盘 + `user://` 持久化；`tests/` 单测覆盖 JWT 签发/校验。

### V4-S1 — 匿名 device_id 登录（已完成）
**前置决策**：见决策 46。拆 5 子步：a DB 客户端 + migrations runner + accounts/profiles schema / b JWT 签发/校验 + device_id 业务 / c HTTP server + 路由 + 接 a/b / d 客户端 `net/auth.gd` / e 端到端真链路验收。**a~d 因 `go.mod`/`go.sum` 跨子步耦合**（a 加 pgx, b 加 jwt, c 用 a+b 起 HTTP, d 是客户端）**合 1 个 commit `db1e77d`**；e 纯验收无产物。**Jira KAN-37** 同步 To Do → In Progress → Done。**Atlas MCP 写入工具**首次被 Auto Mode classifier 拦 → `.claude/settings.local.json` 加 6 条 allow 规则放行（仅本机本项目，UUID 不入 git）。

#### V4-S1a — DB 客户端 + migrations runner + accounts/profiles schema（合于 commit `db1e77d`）
- `server/internal/store/postgres.go`：pgxpool 封装（`Open(ctx, dsn)` / `Close()` / `Ping(ctx)`），不藏在 database/sql 后面，高层包直接用 pgxpool API。
- `server/internal/store/migrate.go`：自写 ~80 行 migrations runner。`Apply(ctx, db, fsys, dir)`：①`CREATE TABLE IF NOT EXISTS schema_migrations` ②`SELECT COALESCE(MAX(version), 0)` ③`ReadMigrations` 扫 `NNNN_*.up.sql` 按 version 升序 ④逐个 `applyOne` 开 tx → 执行 SQL → INSERT version → commit。失败回滚 + 返回已成功数。`ParseMigrationFilename` 严格 4 位数字 + label + `.up.sql`；`ReadMigrations` 重复 version 报错。
- `server/internal/store/migrate_test.go`：6 unit（`ParseMigrationFilename` 10 case / `ReadMigrations` 排序+过滤+空目录 / 重复版本检测 / `"."` dir 路径 `io/fs` 兼容（见踩坑 3））。
- `server/migrations/0001_init.{up,down}.sql`：改纯占位（`SELECT 1;`，原 V4-S0c 的 `CREATE TABLE schema_migrations` + INSERT 删掉）；schema_migrations 改由 runner 自管，避免 migration 内容与 runner 重复维护同一张表。
- `server/migrations/0002_accounts.{up,down}.sql`：真表——`accounts(id BIGSERIAL PK, provider TEXT default 'device', external_id TEXT, created_at, last_login_at, ban_status SMALLINT, UNIQUE(provider, external_id))` + `profiles(account_id BIGINT PK FK→accounts ON DELETE CASCADE, nickname, avatar_id, level, exp, trophies, current_season_id, version INT 乐观锁 default 0, updated_at)`。F2P 字段（unlocks/currency/purchases）**不预建空表**——按"不过度设计"留 V4-S10 IAP 接入时真做。
- `server/cmd/migrate/main.go`：真实化——读 `DB_URL`（缺失 fatal）+ `MIGRATIONS_DIR`（默认 `/app/migrations`，对齐 Dockerfile COPY 目标），30s 超时 ctx，调 `store.Apply(db, os.DirFS(dir), ".")` 跑迁移，打印 `applied N migration(s)`。one-shot 退出码：0=成功 / 1=失败。
- `server/Dockerfile`：①builder `golang:1.23-alpine` → **`1.25-alpine`**（pgx 触发 `go mod tidy` 把 `go` directive 升到 1.25.0；keep image ≥ go.mod 声明）；②加 `ARG GOSUMDB=sum.golang.google.cn` 默认值 + `ENV GOSUMDB=${GOSUMDB}`（`sum.golang.org` 被墙）；③runtime stage `COPY --from=builder /src/migrations /app/migrations` 让 migrate binary 能读 SQL 文件。
- 验收：`go build/test/vet ./...` 全过；`make up + make migrate` → `applied 2 migration(s)`；`docker exec pg psql -c '\dt'` 见 accounts/profiles/schema_migrations 3 表；`schema_migrations` 行 v=1, v=2。

#### V4-S1b — JWT 签发/校验 + device_id 业务（合于 commit `db1e77d`）
- `server/internal/auth/jwt.go`：`Issuer` 封装 HS256。`NewIssuer(secret)` 空 secret 报错；`SignAccess(accountID, now)` / `SignRefresh(accountID, now)` 接受外部 now（测试用），TTL 默认 30d/90d，可 `SetTTLs(access, refresh)` 覆盖。`Claims{AccountID, Kind, jwt.RegisteredClaims{IssuedAt, ExpiresAt}}`；`Verify(token, expectKind)` 区分 access/refresh 两类、`expectKind=""` 关掉 kind 检查（middleware 入口用）。
- `server/internal/auth/jwt_test.go`：8 unit（空 secret 拒 / access roundtrip / refresh roundtrip / wrong kind 拒（access 不能当 refresh 用）/ 31 天前签发的 access 过期拒 / 错 secret 验签拒 / 空 expectKind 接受 / `SetTTLs(1s, 2s)` 5s 前签发的过期拒）。
- `server/internal/auth/account.go`：`AccountRepo.FindOrCreateByDevice(ctx, deviceID)`——`INSERT INTO accounts(provider, external_id, last_login_at) VALUES('device', $1, NOW()) ON CONFLICT (provider, external_id) DO NOTHING RETURNING id, ...` 命中 `pgx.ErrNoRows` 时回退 `UPDATE accounts SET last_login_at = NOW() WHERE provider='device' AND external_id=$1 RETURNING ...`；首次创建额外 `INSERT INTO profiles(account_id, nickname=Player{id})`；整流程单 tx，`defer tx.Rollback`。返回 `Account{ID, Provider, ExternalID, BanStatus, Created bool}`。
- 验收：`go test ./internal/auth/` 8 jwt 测全过；account.go 真 DB 路径留 S1-c integration 覆盖。

#### V4-S1c — HTTP server + 路由 + 接 a/b（合于 commit `db1e77d`）
- `server/internal/auth/handler.go`：`Handler{Repo, Issuer, Now}` + `Mount(mux)`。**用 Go 1.22+ 方法+路径路由**（`mux.HandleFunc("POST /v4/auth/login", ...)`）—— 标准库 net/http 够用，**不引入 chi**（少 1 个依赖；V4-S3 起 middleware 链复杂再换）。body codec 走 `application/x-protobuf` 二进制（`proto.Marshal/Unmarshal`），与 V4-S3 WS frame 共享 wire 格式。`MaxBytesReader` 16 KiB 防 DoS。错误统一回 `pbcommon.ErrorResp{Code, Detail, InReplyTo}` + 适当 HTTP 状态（400=ERR_INVALID_ARG / 401=ERR_AUTH_INVALID_TOKEN/EXPIRED / 403=ERR_AUTH_BANNED / 500=ERR_INTERNAL）。
- `server/internal/auth/handler_integration_test.go`：4 integration（需 `INTEGRATION_DB_URL`，默认 `t.Skip`）——`TestLogin_CreatesAccountAndProfile`（login → PG accounts/profiles 各 +1 行）/ `TestLogin_IdempotentForSameDevice`（同 device 二次 login 仍 1 行）/ `TestRefresh_RoundTrip`（refresh 换新 access）/ `TestRefresh_RejectsAccessTokenInRefreshField`（access token 当 refresh 用被拒 401，验 kind 检查实际能拦）。`setupIntegration` 每 test 清表保确定性。
- `server/cmd/api/main.go`：真实化——读 `DB_URL`/`JWT_SECRET`/`API_PORT`（默认 8080）；起 pgxpool + Issuer + Handler；mount auth 路由 + `/healthz`（含 `db.Ping(r.Context())`，db down 回 503）；`signal.NotifyContext` 接 SIGINT/SIGTERM；10s graceful `srv.Shutdown`。**`JWT_SECRET` 缺失启动 panic**——决策 46 明确无 dev fallback。
- 验收：`go test ./...` 全过（unit 不依赖 DB）；`make up` 起 api 容器 listen :8080；`curl /healthz` HTTP 200；`INTEGRATION_DB_URL=postgres://app:dev@localhost:5432/gcp?sslmode=disable go test -v ./internal/auth/...` 4 PASS。

#### V4-S1d — 客户端 net/auth.gd（合于 commit `db1e77d`）
- `net/auth.gd`：`extends RefCounted`——**不耦合 SceneTree**（HTTPRequest 由 caller `add_child` + 传入），保证可在 headless 单测里 `Auth.new()`。
  - **device_id UUID4**：首次启动用 `RandomNumberGenerator` 生成 16 字节随机 + RFC 4122 v4 改 version 位（byte 6 高 4 位 `0x40`）+ variant 位（byte 8 高 2 位 `0x80`）+ 拼 `8-4-4-4-12` hex；存 `user://device.cfg` `[device].id`；后续启动从盘读。
  - **access/refresh token**：存 `user://auth.cfg` `[auth].access`/`refresh`；`logout()` 清内存变量 + 删 auth.cfg，**保留 device.cfg**（再登仍同账号）。
  - `login(http_req) -> Result` / `refresh(http_req) -> Result` await 风格——构造 LoginReq/RefreshReq → `to_bytes()` → `http_req.request_raw(url, headers=[Content-Type+Accept: application/x-protobuf], METHOD_POST, body)` → `await http_req.request_completed` → 解码 LoginResp/RefreshResp → 存盘 + 返回 `Result{ok, error, status_code, account_id}`。refresh 收到 401 → 自动 `_clear_tokens()`（refresh 已失效 → 客户端 UI 应跳重登）。
- `tests/test_net_auth.gd`：7 unit（UUID4 格式：36 字符 + 位 14 是 `4` + 位 19 是 `8/9/a/b` / 第二实例从 device.cfg 读同 ID / 清盘后重新生成不撞 / token 存读盘 / `logout` 清盘 + 删 auth.cfg / `logout` 保留 device_id / 默认 `server_url=http://localhost:8080` + 构造覆盖）。
- 验收：Godot 单测 **197/197**（190 + 7，零回归）。

#### V4-S1e — 端到端真链路验收（无 commit；smoke 验后即删）
- `tools/_login_smoke.gd`（**临时 harness，仿 V3 `_frame_probe.py`/`_pace_probe.gd` 惯例，验后即删、不入 git**）：`extends SceneTree`，`_init` 用 `await process_frame` 等 root inside_tree（不然 HTTPRequest `ERR_UNCONFIGURED`，见踩坑 4）→ 清 `user://device.cfg` + `auth.cfg` 让 device_id 是新生成的 → `Auth.new("http://localhost:8080")` → `await auth.login(http)` 检 status 200 + token 非空 → 第二 `Auth` 实例从盘 reload device_id/access/refresh 三字段一致（持久化校验）→ `await auth.refresh(http)` 拿新 access。退出码 0=全过 / 1=login fail / 2=持久化 fail / 3=refresh fail。
- 端到端真链路：Godot UUID4 → protobuf 编码 LoginReq → HTTP POST `http://localhost:8080/v4/auth/login` → docker api 容器 → `FindOrCreateByDevice` → PG `accounts` + `profiles` 各 +1 行 → JWT HS256 签发 access + refresh → 客户端解码 LoginResp → `user://auth.cfg` 落盘 → 第二实例 reload 一致 → 再走 refresh 链路。
- 验收（实跑）：
  - smoke 输出 `LOGIN OK status=200` + `PERSISTENCE OK` + `REFRESH OK status=200` + `ALL CHECKS PASSED -- device_id=722ff678-d983-452e-804c-ca5da72fac8c` ✅
  - `docker exec server-postgres-1 psql -U app -d gcp -c "SELECT * FROM accounts WHERE external_id='722ff678-...'"` → id=6 / provider=device / last_login_at=刚才 ✅
  - `profiles WHERE account_id=6` → nickname=`Player6` / version=0 ✅
  - accounts COUNT(*) 1 → 2（仅新增 smoke 那一行）✅

**踩坑（V4-S1 全程，写进 commit message）**：
1. **`go.mod` 的 `go` directive 被 `go mod tidy` 自动升到 `1.25.0`**（加 pgx/v5 时依赖链触发）→ Dockerfile builder `golang:1.23-alpine` 编不过 → 升 `golang:1.25-alpine` 即可（也加注释说明 go.mod 可能继续升、image 跟随）。
2. **`sum.golang.org` 被墙**，容器内 `go mod download` 校验 pgx hash 失败（V4-S0e 装 protobuf 时凑巧 cache 未触发）→ Dockerfile 加 `ARG GOSUMDB=sum.golang.google.cn` 默认值 + `ENV GOSUMDB=${GOSUMDB}`（与 V4-S0e 的 `GOPROXY` 一道，国内一站到位）。
3. **`io/fs.ReadFile` 不接受 `./X` 前缀**，cmd/migrate 用 `os.DirFS("/app/migrations")` + `Apply(..., dir=".")` 时 `ReadMigrations` 拼 `"."+"/"+"0001_init.up.sql"=./0001_init.up.sql` 报 `invalid argument` → 改用 `path.Join`（自动 normalize 去 `./` 前缀），加 `TestReadMigrations_DotDir` 覆盖该路径。
4. **`extends SceneTree` 的 `_init()` 阶段 `root` 还没 `inside_tree`**，`HTTPRequest.request_raw` 直接报 `ERR_UNCONFIGURED`（`!is_inside_tree()` 为真）→ 在 `_init()` 开头 `await process_frame` 等一帧让 SceneTree 真跑起来；记入 [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md) V3-4d 已有的"`_initialize` 期 `add_child` 不触发 `_ready`" 同类坑。

**Jira / PM**：
- **KAN-37 Story** 状态推进 To Do → In Progress（commit 时）→ Done（端到端验收后用户拍板）。
- 进度 comment 入 KAN-37，**首次写入触发 Auto Mode classifier 拦截**（"External System Writes" 风险判定，不知道 CLAUDE.md PM 工作流刚加）→ `.claude/settings.local.json` 加 6 条 Atlas MCP 写入 allow 规则放行（addCommentToJiraIssue / createJiraIssue / editJiraIssue / transitionJiraIssue / addWorklogToJiraIssue / createIssueLink），**仅本机本项目、UUID 不入 git**（每人装 MCP 拿不同 UUID）。

> **V4-S1 整阶段收官**：a DB+migrations → b JWT+device_id 业务 → c HTTP server+路由 → d 客户端 net/auth.gd → e 端到端真链路验收。客户端单测 **197/197**；Go unit 14 + integration 4 全过；docker compose 5 容器健康；smoke 跑完 PG accounts/profiles 各 +1 行，`user://auth.cfg` 落盘且 reload 一致，refresh 链路也跑通。Jira KAN-37 Done。**下一步 V4-S2 玩家档案云存档**：客户端切到在线模式时从服务端读 profile + 卡组；改卡组经 `DeckUpdateReq` 推回（带乐观锁 `expected_version`）；`unlocked_card_ids` V4 玩法验证阶段默认全卡解锁（V4-S10 IAP 接入后差异化）；新建 `decks` 表（`server/migrations/0003_profile_decks.up.sql`）+ `server/internal/profile/` 起包；客户端 `net/profile.gd` 接 `/v4/profile/get` + `/v4/profile/deck-update`。

### V4-S2 — 玩家档案云存档（已完成）
**前置决策**：见决策 46 + V4-S1 收官段尾的 V4-S2 范围。拆 5 子步：a decks 表 migration / b profile 业务层（repo + 乐观锁 CAS + 卡组校验）/ c HTTP 路由 + auth 鉴权 middleware + httpx 共享包 / d 客户端 `net/profile.gd`（离线缓存 + 冲突重取）/ e 端到端真链路验收。**4 个设计决策**（用户 2026-06-24 拍板，全按推荐）：①`unlocked_card_ids` 空列表 = 全卡解锁（服务端不持卡表，客户端持 cards.json 判可组卡）；②卡组校验只查 count==8 / slot 1..3 / 无重复，**不**查卡 id 是否存在（服务端无 card 配置）；③新账号**不**自动播种 deck 行，空 decks 客户端用本地默认；④`readProto/writeProto/writeError` 抽到共享 `internal/httpx`（auth+profile 两 handler 都用）。**a~e 合 1 个 commit**（S2 末尾一次性，用户定）；e 纯验收无产物。**Jira KAN-38** Story To Do → In Progress（开工）→ Done（端到端验收 + 用户拍板）。

#### V4-S2a — decks 表 migration
- `server/migrations/0003_profile_decks.{up,down}.sql`：建 `decks(id BIGSERIAL PK, account_id BIGINT FK→accounts ON DELETE CASCADE, slot INT CHECK 1..3, card_ids JSONB NOT NULL, is_active BOOL NOT NULL default false, UNIQUE(account_id, slot))`。`profiles`（0002）已含 Profile proto 全字段 → **无需补列**。F2P 表（unlocks/currency/purchases）**不预建**（留 V4-S10）。
- 验证：宿主机跑真 runner（`store.Apply`）→ `applied 1 migration`（v=3，v1/v2 已在）；`\d decks` 全约束就位（PK/UNIQUE/CHECK/FK CASCADE）；`schema_migrations` v=1,2,3。

#### V4-S2b — profile 业务层
- `server/internal/profile/profile.go`：`Repo.Get(account_id)` → profile + decks（slot 序）；`Repo.UpdateDeck` 乐观锁 CAS（`UPDATE profiles SET version=version+1 WHERE account_id AND version=expected`，0 行 → `ErrVersionMismatch`）+ deck upsert（`ON CONFLICT(account_id,slot) DO UPDATE`）+ set_active 互斥（降其他 slot），单 tx。`validateDeck`：slot 1..3 / 正好 8 张 / 无重复 / 无空 id → `ErrDeckInvalid`。card_ids 走 `json.Marshal` → `$3::jsonb`，读回 `json.Unmarshal`。返回 domain struct（不耦合 pb）。
- `profile_test.go`：`validateDeck` 8 子用例（8 张 ok / slot 0·4 拒 / 7·9 张拒 / 重复拒 / 空卡拒）。CAS/CRUD 真 DB 路径留 c 的 integration 覆盖（仿 S1 account.go）。

#### V4-S2c — HTTP 路由 + auth 鉴权 middleware + httpx 共享包
- `server/internal/httpx/codec.go`（**决策 4**）：从 auth/handler.go 抽出 `ReadProto/WriteProto/WriteError` + `ContentTypeProtobuf/MaxBodyBytes`，与 V4-S3 WS frame 共享 wire 格式。
- `server/internal/auth/middleware.go`：`Middleware.Require(next)` —— `Authorization: Bearer <token>` → `Verify(KindAccess)` → account_id 入 request ctx；缺/坏 token 401，过期专回 `ERR_AUTH_EXPIRED`（`errors.Is(jwt.ErrTokenExpired)`）。`AccountIDFromContext`。**account_id 取自令牌、不信 body**（防冒充）。battle/match 将复用。
- `server/internal/profile/handler.go`：挂 `/v4/profile/get` + `/deck-update`（都过 middleware）；domain↔pb 映射；CAS 失败 → 409 `ERR_PROFILE_VERSION_MISMATCH`，非法卡组 → 400 `ERR_PROFILE_DECK_INVALID`，profile 缺失 → 404。`unlocked_card_ids` 回 nil（空 = 全解锁）。
- `server/cmd/api/main.go`：挂 profile 路由 + middleware。`auth/handler.go` 改用 httpx（删私有 helper），`auth/handler_integration_test.go` 1 处引用改 httpx —— **原有 12 测全过零回归**。
- `handler_integration_test.go`：6 integration（默认档 / 改卡组持久化 + 版本+1 / stale → 409 / 非法 → 400 / 无 token → 401 / 坏 token → 401）。
- 验证：`go build/vet/unit` 全过；integration（真连库）6 过。

#### V4-S2d — 客户端 net/profile.gd
- `net/profile.gd`（extends RefCounted，不耦合 SceneTree）：`get_profile`（Bearer 鉴权头）成功落盘 `user://profile.cfg`、不可达回退缓存（offline）；`update_deck`（乐观锁 `expected_version`），409 → 自动重取（服务端胜出）；`request_timeout_s`（默认 10s）防服务端不可达永久挂起。wire 解码抽成 `apply_get_resp_bytes/apply_deck_resp_bytes`（可单测）。
- `tests/test_net_profile.gd`：7 unit（默认 url / 缓存圆环 / 缺文件 false / 本地 deck upsert + 激活互斥 / DeckUpdateReq 编解码 / ProfileGetResp 解码填充 + 落盘 / DeckUpdateResp 更新版本）。
- 验证：Godot 单测 **204/204**（197 + 7，零回归）。

#### V4-S2e — 端到端真链路验收（无 commit；smoke 验后即删）
- `tools/_profile_smoke.gd`（临时 harness，仿 S1 `_login_smoke.gd`，验后即删、不入 git）：宿主机临时 api 跑 `:8090`（不动 `:8080` 5 容器），Godot 全链路 login → get（默认 `Player{id}` / version 0 / 无 deck / unlocked 空）→ update slot1 8 张（expected 0）→ 换实例 re-get 确认持久化 → stale 版本 409 + 自动重取 → 死端口 `127.0.0.1:9999` 离线读缓存。
- 验证（实跑）：`ALL CHECKS PASSED -- account_id=23`；`docker exec psql SELECT ... decks WHERE account_id=23` = slot1 / 8 张卡 JSONB / is_active=t；`profiles` version=1。

**踩坑（V4-S2 全程，写进 commit message）**：
1. **godobuf `Deck` 类撞 V3 全局 `class_name Deck`**（`logic/deck.gd`）：S0f 起埋的隐患 —— godobuf 把每个 message 生成同名 GDScript 内部类，`Deck` 触发 `Class "Deck" hides a global script class` 编译错。测试框架靠**重载**侥幸兜过（仍打错误日志），但 `--script` 单发 smoke 无重载 → 直接挂死。**根治**：proto `Deck` 消息改名 `DeckMsg`（wire 不变，仅类型名），重生成双端 pb（`net/proto/profile.gd` + `server/internal/pb/profile/profile.pb.go`）+ 改 `handler.go` 1 处（`pbprofile.Deck`→`DeckMsg`）。不碰 V3 全局类。
2. **离线请求永久挂起**：`net/profile.gd` 未设 `HTTPRequest.timeout`，服务端不可达时 `await request_completed` 永不返回 → smoke 离线步卡死（exit 124）。加 `request_timeout_s`（默认 10s）修复（离线检测的必要前提）。
3. **集成测试跨包并行踩库**：`go test` 默认并行跑不同包，auth + profile 两集成包共享 live PG、各自 `DELETE` + 建号 → auth 的 `COUNT` 断言被打乱。单包跑各自都过。修：跨包用 `-p 1` 串行（已写进 profile 测试头注释）。纯单测（无 `INTEGRATION_DB_URL`）不受影响。

> **V4-S2 整阶段收官**：a decks migration → b profile 业务（CAS + 校验）→ c HTTP + 鉴权 middleware + httpx 抽包 → d 客户端 `net/profile.gd`（离线缓存 + 冲突重取）→ e 端到端真链路。客户端单测 **204/204**；Go unit + integration（auth 4 + profile 6，`-p 1` 串行）全过；smoke PG 实查落库。顺带根治 S0f 起的 `Deck` 全局类撞名隐患（→`DeckMsg`）。**下一步 V4-S3 lockstep 实时对战网络层（★头号工程）**：WS gateway + battle room；`NetworkPlayer` deploy 指令 → 服务端 → 广播双方 → 双方 `logic/` tick 推进；每 N tick state hash 三方对帐；断线重连（room TTL 60s）；超时认输。待细化：hash 算法 / 重连窗口 / tick 偏移 / 客户端预测。

### V4-S3 — lockstep 实时对战网络层（进行中：a~e 完成，f/g 待做）
**前置决策**：见决策 46 + V4-S3 规划（8 条待细化，用户 2026-06-24 全按推荐拍板）：①出兵 tick=current+2（200ms RTT 缓冲）；②S3 不做客户端预测；③哈希=浮点×1000 量化取整+固定字节序→sha256（units+towers+elixir）；④断线重连 60s/超时 30s 拆到靠后子步（f）；⑤开局下发双方卡组+关卡+side+start_tick（两端建同一初始态）；⑥新增固定 ladder 关卡配置；⑦S3 临时调试配对（真匹配=S4）；⑧新建 `net_battle_scene` 不动单机 `battle_scene`。**真机验收=两台 Windows**（同架构 x86 浮点确定性有保障；安卓跨架构 ARM 确定性延后，真 desync 再上定点数）。拆 a~g 共 7 子步；**本提交含 a~e**（f 重连+超时 / g 真机验收待做），a~e 合 1 个 commit。**Jira KAN-39** In Progress（未 Done，S3 未收尾）。

#### V4-S3a — 确定性地基 + 状态哈希
- `logic/match.gd`：新增 lockstep 三件套（单机 `update()` 路径完全不动）——`advance_tick(deploys)` 无时钟无 AI 的确定性单 tick 推进（先双方 regen → 应用 deploys → battle.step）；`_apply_deploy` 按 side 选 Player、按 card_id 在手牌反查 hand_index 再 try_play_card（卡不在手/side 非法=确定性 no-op，丢弃非法/作弊指令）；`state_hash()` 按 proto 定义量化(×1000)定序 sha256（elixir 双方 + units(arena 列表序，spawn 确定性) + towers(player 序+opponent 序)）。约定 side1↔OWNER_PLAYER、side2↔OWNER_OPPONENT。
- 前置确认（lockstep 命门）：逻辑层零随机（唯一 RNG 在 `run_rewards.gd` 抽奖、不在战斗）+ deck 不洗牌确定性循环 + 卡组无重复卡（S2 validateDeck 保证）→ card_id↔hand_index 唯一。
- `tests/test_lockstep_determinism.gd`：5 测——两 Match 喂相同输入序列(220 tick + 真出兵打架)每 tick 哈希全等 / 不同输入哈希分叉 / 垃圾卡 no-op / 空 tick 确定性 / net_tick 自增。单测 **209/209**。

#### V4-S3b — 协议补全 + ladder 配置 + matches 表
- `proto/battle.proto`：JoinRoomReq +deck；JoinRoomResp +side1_deck/side2_deck/level_id；新增 `BattleEndReport`（tick/winner/reason/scores——客户端 sim 判定结束上报，服务端无 sim 靠两端核对）。`proto/common.proto`：MsgId +`BATTLE_END_REPORT=48`。
- `config/levels.json`：+`ladder_01`（固定对战配置：时长 180 / 圣水 / 塔血 / 默认场地）。
- `server/migrations/0004_matches.{up,down}.sql`：matches 表（id UUID `gen_random_uuid()` / 双方 account FK / winner/reason/scores / trophy delta / started·ended）+ 双索引。PG13+ 内置 gen_random_uuid，无需 pgcrypto。
- 重生成双端 pb（Go protoc + godobuf gd），Godot 209/209 无类冲突。

#### V4-S3c — Go gateway WS + battle room（最重）
- `server/internal/battle/room.go`：lockstep 中继核心（**服务端不跑 sim**，只做确定性中继+裁判）。`onDeploy` 按 tick 缓冲(过期 clamp 到 curTick+1)、`onTick` 打包广播 TickBundle(空包照发保同步)、`onHash` 两端对帐(分歧标记 mismatch，完整仲裁留 S7)、`onEnd` 双方核对一致拍板、`finalize` 算 trophy(S3 固定±30)+广播 BattleResultPush+持久化。`Run()` = 10Hz ticker + inbound channel select(单 goroutine 无锁)。帧编解码 `[2B msgid 大端][payload]`。
- `server/internal/battle/{hub,conn,persist}.go`：Hub 先到两人配对(真匹配=S4)；conn.go WS 收发泵(gorilla/websocket，结束给 300ms 宽限 flush 结算帧)；PGPersister 写 matches + 双方 profiles.trophies(GREATEST floor 0) 单 tx。
- `server/cmd/gateway/main.go`：真实化——`/v4/battle/ws?token=` JWT 鉴权 + 拉对手 ProfileSummary + WS upgrade + hub.Serve；`/healthz`；graceful。+gorilla/websocket v1.5.3 依赖。
- `room_test.go`：9 测（join resp 双方卡组/side / deploy 按 tick 打包 / 双方同 tick 同包 / 过期 clamp / 哈希对帐相等不标·分歧标记 / 结束双方核对+持久化+trophy±30 / 平局零 delta / 重复结束 no-op）。

#### V4-S3d — 客户端网络层
- `net/ws_client.gd`：WebSocketPeer 封装——connect/poll/帧编解码(大端 static 可单测)/开关沿信号。
- `net/battle_client.gd`：连 gateway → JoinRoomReq(本方卡组) → JoinRoomResp 建同一初始态 Match(setup 双方卡组) → 每 TickBundle 驱动 `advance_tick` → 每 10 tick 上报 `state_hash` → 本地 sim 结束上报 BattleEndReport → 收 BattleResultPush。`send_deploy` 发 DeployCmd(tick=net_tick+2) **不当场落子**（等服务端广播回来两端同 tick 落子）。
- `logic/match.gd`：`setup()` +`opponent_deck_override` 参数（单机不传=用 ai_deck，行为不变）。
- `tests/test_net_battle_client.gd`：7 测（帧编解码大端往返/高字节/短帧拒 / JoinResp 建 Match / TickBundle 推进+第10tick 报哈希 / deploy 用+2 tick+坐标×1000 / 未 join 不发）。单测 **216/216**。

#### V4-S3e — 对战场景 + LADDER 入口 + 端到端真链路
- `view/net_battle_scene.gd`+`.tscn`：联机对战场景（功能版 slim）——登录→连→等配对→渲染 match 逻辑状态(单位圆/塔矩形/HUD 卡+圣水)→拖拽出兵走 `send_deploy`→结算屏；side2 整场 180° 翻转(本方半场恒在屏幕下)。单机 `battle_scene` 不动（保 V3 训练营）。
- `config/network.json`：服务端地址(api_url/ws_url)，真机对战改成服务端局域网 IP。
- `view/main_menu.gd`：+「天梯对战」金 CTA 入口 → net_battle_scene（按钮整体下移重排）。
- 端到端真链路（临时 harness `tools/_lockstep_smoke.gd`，验后即删、不入 git）：单进程两 battle_client 经真 WS 连宿主机 gateway，登录(api)→配对→真 lockstep 60 tick **逐 tick 直接比对两端 state_hash：856 比对 / 0 分叉**+各出兵真生单位→两端上报结束→服务端核对→BattleResultPush winner=1→PG matches 行落库(KING_DESTROYED / trophy±30)。

**踩坑（V4-S3 a~e，写进 commit message）**：
1. **房间结束竞态**：`finalize` 广播结算帧后立即 close socket → 结算帧可能没 flush。conn.go 关闭加 300ms 宽限（粗暴但够 S3 玩法验证）。
2. **matches 表 FK 污染集成测试**：lockstep smoke 插了 matches 行(账号 38/39)，S1/S2 集成测试 `DELETE accounts` 撞 matches FK(SQLSTATE 23503) → 两集成测试清表加 `matches`(FK 子表先删：matches→decks→profiles→accounts)。纯单测不受影响。
3. **Docker 守护进程中途停了**：开发中 Docker Desktop 退出 → 启动 + `compose up -d` 重新拉起 5 容器。**容器仍是旧镜像**（gateway 是 S0 scaffold），端到端验证用宿主机临时 gateway(:8082) 跑通；**g 真机前需重建 gateway 镜像**让容器带新代码。
4. **headless editor import 补 .uid**：编译新场景时顺手生成一批 `.uid`（含 S1/S2 当时漏提的 net/proto·net/auth 等），repo 本就提交 .uid，随本提交一起入库。

**Jira / PM**：KAN-39 In Progress（a~e 完成、未 Done，f/g 待做）。

#### V4-S3f — 心跳 + 断线重连重放 + 超时认输
- `server/internal/battle/room.go`：lockstep 健壮性层。心跳(HeartbeatPing→Pong + 刷 lastSeen)；掉线/静默(30s 无活动)→`onDisconnect` 暂停整局(`paused` 跳过 onTick，两端都停、不单方面被打)；`onReconnect` 重连方重发 JoinRoomResp + 重放全部历史 TickBundle(确定性快进追回)，双方都在线则恢复；`reconnectWindow`(60s)耗尽→`finalizeDisconnect` 在线方按 DISCONNECT 判胜 + 落库。`history` 记录全部广播 bundle 供重放；`step()` 提取 tick 循环体(暂停时查重连窗口 / 否则查静默 + onTick)便于单测；`deliver` 跳过掉线方(避免向孤儿/已关通道发)。
- `server/internal/battle/conn.go`：写泵改 select(send/quit)、**不关闭 p.send**(房间持有、重连会 swap，关闭会 race panic 向已关通道发)；读循环断开 → signal `room.disc`(房间未结束时)开重连窗口。
- `server/internal/battle/hub.go`：+`active` map(accountID→room)；Join 先查活跃房(未结束)→走 `room.reconnect` 重连路径，否则正常配对；房间结束 `reapWhenDone` 清 active。
- `room_test.go` +5 测(掉线暂停不广播 / 心跳 pong / 重连重放 JoinRoomResp+历史 / 重连窗口超时对手 DISCONNECT 胜+落库 / 静默触发掉线)。Go battle **14 unit**。
- `net/battle_client.gd`：心跳(poll 累计 5s 发 HeartbeatPing)；断线自动重连(`_on_closed` 进重连态 → poll 每 2s 重试 connect，最多 60s 窗口)；重连收 JoinRoomResp 重建 Match + 重放 bundle 快进；+`reconnecting` 信号；`poll(delta)` 接帧时间。`test_net_battle_client.gd` +心跳测。Godot **217/217**。
- `view/net_battle_scene.gd`：poll 传 delta + 重连状态显示。
- 端到端真链路(临时 harness `tools/_reconnect_smoke.gd`，验后即删)：两 client 真 WS 对战中**强制断 A** → A 自动重连 → 服务端重放指令流 → **A 追回 tick(重连后 15 比对 0 分叉)** → lockstep 恢复 → 正常结算。超时认输(窗口耗尽对手胜)走单测(注入时钟，60s 窗口太长不宜 smoke)。

#### V4-S3g — 两台 Windows 真机对战验收（真人）
- 前置：`docker compose build` 重建 `gcp-server:dev` 镜像（容器从旧 scaffold 升到 lockstep 新代码）+ recreate；操作清单 `docs/V4_S3_g_real_machine_test.md`（A 机起服务+开防火墙 8080/8081；两台改/确认 `config/network.json` 指向服务器 IP；主菜单点天梯对战自动登录+配对）。顺带 `project.godot` +`run/max_fps=60`（封帧降功耗，移动端必需）。
- 验收（用户 2026-06-25，两台 Windows 局域网）：完整一局 lockstep PvP 跑通——**双方实时看到对方出兵、走位/血量同步、胜负结算两端一致**（一端「失败」一端「胜利」）、matches 表落战绩。初步人工验证无问题。
- 备注：联机对战场景目前是**矢量白膜**（圆=单位/方块=塔），单机已有的精灵/特效/手感**未搬入**（S3 故意聚焦网络正确性）；「联机视觉对齐」记入 Jira 待办。

> **V4-S3 整阶段收官**：a 确定性地基 → b 协议+ladder+matches → c Go gateway+battle room → d 客户端 net 层 → e 对战场景+真链路 → f 心跳+断线重连重放+超时认输 → **g 两台 Windows 真机对战验收通过**。客户端单测 **217/217**；Go unit(battle 14)+integration 全过；**端到端真 WS 856 比对 0 分叉 + PG 战绩落库 + 断线重连重放恢复 + 真机完整对局实时同步胜负入库**。**lockstep 整条路线（不重写 Go 战斗逻辑、两端各跑 logic+哈希对帐）验证成立**。Jira KAN-39 Done。**下一站 V4-S4（匹配）**：Redis ZSET 按段位分桶 + ELO 起评 1200 + 窗口扩展 + 取消，把"先到两人配一桌"换成真匹配。

### V4-S4 — 匹配（Redis ZSET + ELO）（进行中：a~e 完成，真机验收待做）
**前置决策**：路 B（用户 2026-06-25 拍板，全按推荐）：①profiles 加隐藏 `rating INT DEFAULT 1200`（MMR/ELO）；②杯数 trophies 保留作可见进度（存库 + 主界面显示），赢 +30/输 -30 封底 0，与 MMR 分开；③标准 ELO，K=32 平（不搞新手保护/定级赛）；④匹配窗口 ±50 起每 5s 放宽 → ±200 封顶；⑤S4 单一全局池（arena 恒 1，不分桶）；⑥队列后端 = **Redis ZSET**（S0~S3 一直闲置的 Redis 首次用上，S5 榜单复用）；⑦卡组按 `deck_slot` 查 S2 存档，无则 ladder 默认兜底；⑧主菜单进来自动登录 + 拉档显示杯数（会话 `net/session.gd` 跨场景复用）。拆 5 子步 a~e + 真机验收（用户跑）。**Jira KAN-40** In Progress。

#### V4-S4a — schema + ELO 逻辑
- `migrations/0005_rating.{up,down}.sql`：profiles +`rating INT DEFAULT 1200`；matches +`p1/p2_rating_delta`。
- `internal/rating/elo.go`：纯 ELO——`Expected`（期望分，等分 0.5/400 分差 ~0.91）+ `Update`（零和调分，`delta=round(K*(score-E))`，K=32）。`elo_test.go` 6 测（等分 0.5/高分被看好/同分赢 ±16/平局不动/零和/爆冷涨更多）。
- `battle/persist.go`：结算时读双方当前 rating（`FOR UPDATE` 锁行防并发）→ 套 ELO 写回 + matches 记 rating delta；杯数仍走房间算的 ±30（GREATEST floor 0）。`persist_integration_test.go` 真连库验（赢家 1216/30、输家 1184/0、delta ±16）。**房间逻辑不动**（只管谁赢 + 杯数 delta，ELO 在 persister）。

#### V4-S4b — 匹配器 + Redis 队列
- `internal/store/redis.go`：go-redis/v9 封装（`OpenRedis` ParseURL+Ping / `Client` / `Close`）。**首次用 Redis**。
- `internal/matchmaking/queue.go`：`Queue` 接口 + `RedisQueue`——`Add`（ZADD `matchmaking:queue` score=mmr + HSET meta deck_slot/joined_at）/`All`（ZRANGEBYSCORE 全捞 + 补 meta，stale 成员清掉）/`Remove`（ZREM+DEL）。逻辑/存储分离便于单测。
- `internal/matchmaking/matcher.go`：`windowFor`（±50 起每 5s+50 至 ±200 封顶）+ `FindPairs`（最久等待优先、配到「双方窗口都接受」的最近对手、配上即出队）。
- `matcher_test.go` 5 测（窗口随等待放宽/近分立即配/远分等放宽后配/取消出队/三人配最近两个远的继续等）。`queue_integration_test.go` 真连 Redis 往返。

#### V4-S4c — 接网关（Lobby 替代 Hub）
- `internal/battle/lobby.go`（**取代 hub.go**）：匹配队列 + 建房 + MatchFound + 重连。`EnterQueue`（读 rating 入队，返回 waiter 供阻塞）/`LeaveQueue`（取消）/`RunMatchmaker`（每秒 FindPairs→createMatch）/`createMatch`（按 slot 查双方卡组→建 Room→推 MatchFound→signal 双方 waiter；一方中途取消则把另一方重入队）/`Reconnect`（active map 找活跃房）/`lookupDeck`（无存档兜底 ladder 默认）。
- `conn.go`：Serve 重写——首帧 `FindMatchReq`→EnterQueue→select(matched/取消/断线)→对战；首帧 `JoinRoomReq`→`Reconnect`；读 goroutine 把后续帧灌 inbox 供 Serve 分流。
- `cmd/gateway/main.go`：接 Redis（`REDIS_URL` 必填，缺失 fatal）+ Lobby + 启 `RunMatchmaker` goroutine；Serve 由 Lobby 提供。
- `lobby_integration_test.go` 真连 Redis+PG：两人入队→matchTick→配进同房 + 双方收 MatchFound（side/对手/room_id 对）+ active 登记 + 队列清空。**删 hub.go**。

#### V4-S4d — 客户端匹配流程 + 主菜单杯数
- `net/session.gd`：联机会话（匿名登录 + 档案缓存，跨场景复用，GameState 静态持有，**非 autoload**避免测试/headless 自动跑网络）。`ensure`（登录+拉档幂等）/`refresh_profile`/`trophies`/`token`/`ws_url`。
- `battle_client.gd`：`start(deck_slot)` → `_on_opened` 首发 `FindMatchReq(slot)` / 已匹配后重连发 `JoinRoomReq(room_id)`；`_handle_match_found`（记 `_room_id` + 发 `matched` 信号）；`cancel_match`。
- `net_battle_scene.gd`：session 登录 + 匹配中 UI（状态「匹配中…」+取消按钮）+ `matched` 信号 + 对局后 `refresh_profile` 刷杯数。`main_menu.gd`：进菜单自动登录 + 显示「杯数 N」。`game_state.gd`：+`session()` 懒持有。
- `test_net_battle_client.gd` +4 测（首发 FindMatch 带 slot / MatchFound 记 room+发 matched / 已匹配重连发 JoinRoom / 取消发 CancelReq）。Godot **221/221**。

#### V4-S4e — 日志打点 + 端到端真匹配 smoke
- 服务端日志：lobby（入队 mmr / 取消 / 配对）、room（结果 / 掉线 / 重连）、persist（ELO mmr 变化 + 杯数）、gateway（连接）。客户端 print（匹配 / 已匹配 / 进房 / 结果 / 重连）。`version.V4Stage` → `V4-S4`。
- 重建 `gcp-server:dev` 镜像 → S4（gateway 连 Redis、:8081 listening、WS 端点 401）。
- 端到端真匹配 smoke（临时 harness `tools/_match_smoke.gd`，验后即删）：两 client 真 WS 各发 FindMatch → 服务端按 ELO 配对 → MatchFound → 进房 lockstep（**235 比对 0 分叉**）→ 上报结束 → 结算。psql 实查：赢家 mmr 1200→**1216** 杯数 **+30**、输家 1200→**1184** 杯数 0；matches 行 rating ±16 / trophy ±30。服务端日志全流程呈现（ws connected → mm queued mmr=1200 → mm matched → battle end → persist mmr 1200→1216）。
- **真机验收待用户跑**（两台 Windows pull S4 + 改 network.json 为服务器 IP + 点天梯：匹配中→配上→对战→杯数变）。

**踩坑/设计点（V4-S4 a~e）**：
1. **Hub→Lobby 重构**：配对逻辑从「先到两人配一桌」移到匹配器（Redis 队列 + ELO 窗口）；网关 Serve 重写成首帧分流（FindMatch→匹配 / JoinRoom→重连），匹配器配对后直接把两连接喂进房间（happy-path 不再需要客户端单独 JoinRoom）。
2. **Redis 首次接入**：gateway 新增 `REDIS_URL` 硬依赖（缺失启动 fatal）；compose 早已注入。
3. **会话用 GameState 静态变量持有，不做 autoload**：避免 autoload 在 headless 测试/test_runner 里 `_ready` 自动跑登录网络。
4. **ELO 放 persister、杯数放房间**：rating 是隐藏匹配分（不进 ProfileSummary、不推客户端），结算入库时算；杯数是可见进度，房间算 ±30 推客户端。两者解耦。

**Jira / PM**：KAN-40 In Progress（a~e 完成、真机验收待用户跑 → 过则 Done）。

> **V4-S4 整阶段收官**：a schema+ELO → b 匹配器+Redis 队列 → c Lobby 替代 Hub → d 客户端匹配流程+会话+杯数 → e 日志+真匹配 smoke → **真机匹配验收**。客户端 **221/221**；Go unit（rating 6 + matchmaking 5 + battle 14）+ integration（含 Redis 首接入、Lobby 真匹配）全过；**端到端真匹配 smoke：真 WS 按 ELO 配对 → lockstep 235 比对 0 分叉 → ELO（1200→1216/1184）+ 杯数（±30）入库**；**两台 Windows 真机验收通过（用户 2026-06-25，room-2: 94 vs 97 ELO 配对+完整对局+MMR/杯数入库）**。复用 S3 lockstep 房间不重写。Jira KAN-40 Done。**V4-S5（赛季+排行榜）暂缓**（KAN-41 退回 To Do）——**当前转向 V5 单机闯关养成**（决策 47）。

---

## V5 — 单机闯关养成（进行中）

> 方向见决策 47，权威规划见 [PLAN_V5.md](PLAN_V5.md)，Epic KAN-50。把单机升级为养成驱动的闯关 RPG：100+ 关闯关推关（难度系数）+ 货币经济（金币/碎片/宝石）+ 卡牌养成（升级提数值 / 升阶解锁技能积木）+ 挂机产出，**战力为底·操作为顶**，全程单机本地存档、不依赖服务端（V4-S0~S4 成果保留不动）。施工 S0~S8 = KAN-51~59。每步追加在本段。

### V5-S0 — 配置表骨架 + 存档 schema（已完成）
**前置决策**：见决策 47 + PLAN_V5.md。S0 = 骨架步（配置表 schema + 样例 + 存档草案 + ConfigLoader 接表），全 headless 单测覆盖。
- **4 张新配置表**（`config/`，结构性、JSON-first、不进 Excel 镜像）：
  - `stages.json`：闯关关卡（chapter/index/encounter/difficulty_coef/ai_difficulty/recommended_power/stars/first_clear/repeat/shard_drop）；S0 含 2 样例关（stage_1_1/1_2）。
  - `encounters.json`：遭遇模板（deck 8 张 + archetype）；S0 含 3 模板（starter_easy/tank_push_a/swarm_rush_a）。
  - `economy.json`：升级/升阶/解锁成本 + 数值曲线（level_stat_per_level 0.10 / rank_stat_mult 1.25 / level_cap_per_rank {1:4,2:7,3:10}）+ 挂机 + 奖励基数。〔示意·待平衡，V5-S8 probe 定〕。
  - `card_progression.json`：全 16 卡稀有度（普通6/稀有5/史诗4/传说1）+ starter（初始 8 张 = level_01 默认卡组）+ base_power + 各阶解锁 rank_unlocks（type=stat/skill，S5 实现）。
- **`logic/config_loader.gd`**：接 4 新表（load + 校验 + accessor get_stage/get_encounter/get_economy/get_card_progression/has_*）。校验：card_progression 双向覆盖 cards（每卡须有条目、rarity 合法、base_power 数字）；encounters deck 正好 8 张且卡存在；stages 的 encounter/ai_difficulty/coef(≥1.0) 合法 + 奖励/掉落 card 引用存在。`_` 前缀键（如 `_comment`）跳过。
- **`logic/player_data.gd`（草案）**：存档数据结构（wallet{gold,gems}/cards{level,rank,shards,unlocked}/stages{stars,cleared}/highest_cleared/idle）+ `init_new`（默认新档：全卡建条目、starter 8 张解锁）+ `to_dict`/`load_dict`（实例方法、不引用自身 class_name，遵 V3-4d 踩坑）。SaveSystem 接线 + 战力计算 + 解锁解算留 V5-S2。
- **单测**：`tests/test_v5_config.gd`（4：加载 4 表 / 覆盖全卡 / stage 引用合法 / 注入坏引用被校验抓出 + `_` 键跳过）+ `tests/test_player_data.gd`（3：默认档解锁 8 张 / 往返 / 缺字段默认）。**228/228**（221 + 7，零回归）。
- **踩坑**：①ConfigLoader 类成员 `var` 在 class 顶层（**无缩进**），首版 Edit 误带 tab 缩进 → 未匹配，去 tab 修正。②`build_config.py --check` 红——但是 **HEAD 既有 drift**：`levels.json` 的 `ladder_01`（V4-S3 加）未回灌 `GameConfig.xlsx`（经核 Excel 无 JSON 缺失项 → 无 clobber 风险）；但 `--from-json` 会整表重建 Excel（**可能丢 Balance_View/_Enums 等不导出 sheet**），未验证前不擅自跑 → 留作独立 housekeeping（待用户定夺：同步进 Excel / 让 check 跳过 ladder）。S0 新增 4 表本就不进 Excel 镜像，**未引入新 drift**。
- **Jira/PM**：Epic KAN-50 + S0~S8 = KAN-51~59 建好、全 To Do；KAN-51 In Progress；KAN-41（V4-S5）退回 To Do 暂缓。

### V5-S1 — 出兵数值乘区管线（已完成）
**前置**：S1 是养成/难度的命门地基（先于一切养成/关卡）。给出兵生成路径加一个 hp/damage 乘区，speed/range/attack_speed/tick 一律不动（保手感+确定性）。
- `logic/unit.gd`：+`apply_stat_mult(mult)`——只缩 max_hp/hp/damage；`mult==1.0` 提前 return（保证乘区未启用时逐位一致、零回归）。
- `logic/skill_system.gd`：`play_card` / `_execute_block` / `_spawn_unit` 多收 `stat_mult` 透传到生成单位；仅 spawn_unit 用（伤害/治疗积木本步不缩放）。
- `logic/player.gd`：+`unit_stat_mult` 字段（默认 1.0），`try_play_card` 出牌时带给 `skill_system.play_card`。
- `logic/match.gd`：+`set_stat_mults(player_mult, opponent_mult)` 一处注入双方乘区（来源后续接：敌方 coef = V5-S3 / 我方 = V5-S4/5）。
- **单测** `tests/test_v5_stat_mult.gd`（6：apply 只缩 hp/dmg·其余不动 / mult=1 逐位一致 / play_card 缩放 / 默认不变 / Match 注入 / Player 透传——敌方 3× knight 600→1800）。**234/234**（228 + 6，**228 旧测逐位零回归**）。
- **边界（故意，标在代码注释）**：①法术伤害（火球/闪电）不走通用乘区，养成对法术走升阶积木（V5-S5）；②亡语召唤的单位暂用基础数值（V5-S5 再议）。
- **顺带**（前置 housekeeping，commit `3699ad6`）：`build_config.py --check` 跳过结构性关卡 `ladder_*`（比照 arena.json 不进 Excel 镜像；check / --from-json / 反生成三向一致），修掉 V4-S3 遗留的 --check 红。

### V5-S2 — 玩家存档系统 + 战力计算（已完成）
- `logic/player_data.gd`：+`card_stat_mult`（= 等级乘 `1+(lvl-1)·0.10` × 阶乘 `1.25^(rank-1)`，读 economy 曲线）/ `card_power`（base_power × 乘区）/ `team_power`（卡组求和取整）/ `can_unlock`（碎片 ≥ 稀有度门槛）/ `ensure_cards`（卡池新增时补齐缺失卡、不丢档）。
- `logic/save_system.gd`：+`save_player`/`load_player`/`has_player_save`/`clear_player_save`（`user://player_save.json`）；无档 → `init_new`（初始 8 张解锁），有档 → `load_dict` + `ensure_cards`。
- **单测** `tests/test_v5_progression.gd`（6：落盘往返 / 无档建新档 / ensure_cards 补齐不覆盖 / 乘区曲线（满养成 ×2.969）/ 战力（knight L5=140·初始队伍=960）/ 解锁门控（golem 120 碎片））。**240/240**（234 + 6，零回归）。
- **设计点**：S2 只算"数值/战力/解锁"，**不接战斗**——我方乘区来源 `card_stat_mult` 由 V5-S4 出牌时注入、敌方 coef 由 V5-S3 注入。S2 是数据 + 计算层。

### V5-S3 — 闯关骨架 + 星级判定（已完成）
- `logic/stage_progress.gd`（新）：关卡按 (chapter,index) 排线性序列；`is_unlocked`（首关恒解锁 / 前关通关才解锁）、`next_stage`、`is_all_cleared`、`chapter_stars`、`apply_result`（≥1 星=通关，星数取 max 不回退，刷 `highest_cleared`）；进度持久在 `PlayerData.stages`（复用 CampaignState 二元推进范式）。
- **星级判定** `StageProgress.judge_stars(stars_cfg, outcome)`（静态纯函数）：未胜=0 星；胜=命中目标数（`win` 必中 → ≥1 星），支持 `king_hp_pct`（保塔血）/ `time_under`（限时）。`outcome={won,king_hp_pct,duration_sec}` 由 view/battle 结束时算（接 UI 留 S7）。
- `logic/match.gd`：+`setup_stage(stage_id, player_deck_override, player_stat_mult)`——读 stage：`difficulty_coef`→`set_stat_mults(_, coef)` 敌方出兵乘区、`encounter`→敌方卡组、`ai_difficulty`→AI 档；对局参数走 `base_level`（默认 ladder_01）。**S1 的敌方乘区在此真正用上**。
- `config/stages.json` +`base_level` 字段；`logic/config_loader.gd` 校验 base_level 引用存在。
- **单测** `tests/test_v5_stage.gd`（6：排序/解锁、推进+解锁下一关+章节星、星数取 max 不回退、未胜 no-op、三星判定 4 档、`setup_stage` 接 coef/deck/AI + **headless 跑通一关**：敌方 giant 2000×1.05=2100）。**246/246**（240 + 6，零回归）。
- **设计决策**：①**敌塔 HP 暂用 base_level 值、不随 coef**（coef 只放大敌方单位 hp/damage；塔血缩放留 V5-S8 平衡）；②base_level 统一 `ladder_01`（标准对局参数：圣水 1.0/10、180s、塔 2500/1450）。

### V5-S4 — 卡牌升级（金币·数值曲线）（已完成）
- `logic/player_data.gd`：+`level_cap(rank)`（economy.level_cap_per_rank：rank1→4/2→7/3→10）/ `upgrade_cost`（`base[rarity]·(1+(lvl-1)·growth)`，随等级线性涨）/ `upgrade_card`（花金币·level+1·受阶上限钳制）。
- **养成接进战斗**：`logic/player.gd` +`player_data` 字段 + `_resolve_stat_mult(card_id)`（有 player_data → 按本卡 `card_stat_mult` per-card 乘区；否则 flat）；`logic/match.gd` `setup_stage(..., player_data)` 注入我方养成。**升级一张卡，战斗里它真变肉变疼**（养成首次在战斗生效）。
- `config/economy.json`：`upgrade_total_gold` → `upgrade_cost_base`(80/160/320/600) + `upgrade_cost_growth`(0.5)；`config_loader` 校验 key 同步。
- **单测** `tests/test_v5_card_upgrade.gd`（6：扣金币+升级 / 成本随等级涨 / 阶等级上限拦 / 金币不足拒 / 锁定卡拒 / 战斗内我方 knight L6R2 ×1.875=1125 变肉）。**252/252**。

### V5-S5 — 卡牌升阶 + 技能积木解锁（已完成）
- `logic/player_data.gd`：+`rank_up_card`（花碎片+金币·rank+1·抬等级上限）/ `rank_up_cost`（economy.rank_up[rarity][rank-1]）/ `_max_rank`。
- **技能积木解锁机制** `logic/card_progression.gd`（新）：`effective_skills(base, rank_unlocks, rank)` 把 rank 2..当前的 `ops` 顺序叠加到 skills 深拷贝。op：`count_add`（spawn count+）/ `num_add`·`num_mult`（块 field 改，如 radius/damage）/ `unit_field`（spawn 块挂 `_unit_override` 改单位配置如 death_spawn）。
- `logic/skill_system.gd`：`play_card` +`skills_override`（用 effective skills）；`_spawn_unit` 合并 `_unit_override` 进 unit 配置。`logic/player.gd` +`_resolve_skills(card_id)`（rank≥2 → effective skills）。
- `config/card_progression.json`：给 11 张卡授 ops；**新机制类解锁**（on-hit 溅射 / 亡语溅击 / 对塔加伤 / 穿透 / 溅射 / 连锁 / 灼烧 / 护盾）engine 未支持 → **仅 note 占位、留 V5-S8**。
- **golem 示范偏差（有意，记踩坑）**：PLAN 原想"death_spawn 从 0 在 2 阶解锁"，但 `test_arena` 的 V3-3 亡语测试依赖 golem 基础亡语（2 哥布林）——移走会破 2 个测 + 触发 Excel 重建。改为**保留基础亡语、用 `unit_field` op 把 death_spawn_count 升阶放大（2→3→4）**，同样端到端验证 unit_field 机制、零 V3 回归、不动 Excel。
- **单测** `tests/test_v5_card_rank.gd`（9：effective_skills count/rank1/num_add/golem unit_field、升阶扣碎片+金币、升阶抬等级上限、最高阶+碎片不足拒、战斗内 goblins rank2 出 4 只、`_unit_override` 生成 golem 死兵 3）。**261/261**（V3 arena/skill_system 亡语测试零回归）。

### V5-S6 — 经济产出（首通/重复/挂机/解锁）（已完成）
- `logic/player_data.gd`：+`grant_reward`（通用：金币/宝石/碎片，任务/成就/章节宝箱占位复用）/ `grant_stage_reward`（首通 first_clear 大额 / 重复 repeat 小额 + 可选 seeded rng 概率 shard_drop）/ `unlock_card`（碎片够 → 扣 + 解锁）/ 挂机离线 `idle_rate_per_hour`（按最高通关章节）·`idle_pending`（累计封顶 cap_hours）·`collect_idle`（领取清零，`now_ts` 由 caller 注入、逻辑层不取系统时间）。
- **单测** `tests/test_v5_economy.gd`（9：首通/重复奖励、通用奖励、seeded shard_drop 可复现、解锁扣碎片/不足拒、挂机累计+封顶(8h)、领取刷基准、无进度 0 产出）。**270/270**。
- **占位说明**：日常任务/成就的"定义 + 每日重置"留后续；S6 提供其发奖机制（`grant_reward`）。

> **转向（决策 48）**：S6 后用户拍板把项目改为**实时在线 F2P、服务器权威**（推翻决策 47）。S7 UI 顺延到在线地基 + 服务器经济（N1~N7）之后。详见决策 48 + PLAN_V5 §11.1。

### V5-N1+N2 — 持久会话连接 + 配置服务器化（已完成）
**前置**：决策 48。在线地基头两步，复用 V4 的 gateway/auth/WS。一起做、自验（纯代码/数据逻辑，无表现层，免真机）。
- **proto**：`session.proto`（`ConfigPush{version, up_to_date, bundle}`）+ `common.proto` MsgId `CONFIG_PUSH=60`（60-69 = V5 会话/经济段）。双端重生成（Go protoc + godobuf）。
- **N1 服务端**：`internal/session`（`Manager` 一账号一连接、新登录挤掉旧；`Serve` = 注册 + 配置推送 + 心跳 PING→PONG + 掉线清理；`quit` 通道驱逐/关服）。gateway `/v5/session/ws?token=&cfgver=`（JWT 鉴权 → 升级 → Serve）。
- **N2 服务端**：`internal/gameconfig`（`Load(dir)` 读 `config/*.json` → 版本化 bundle，文件名升序确定性 sha256 版本）。连接时下发 `ConfigPush`：`cfgver` 命中 → `up_to_date`（不带 bundle）；否则全量。compose 把 `../config` 只读挂进 gateway（`CONFIG_DIR=/app/config`，双份同源）。
- **客户端**：`net/session_conn.gd`（token → 连 WS → 收 ConfigPush 入内存 + `user://config_cache.json` 薄缓存 → 5s 心跳 → 断线自动重连/窗口）。复用 `net/ws_client.gd`（顺带把入站缓冲调到 2MB——配置包 82KB 超默认 64KB）。
- **测试**：Go `gameconfig`（5）+ `session`（Manager 驱逐/注册 + buildConfigPush + WS 集成：配置推送/心跳/驱逐 httptest）；客户端 `tests/test_net_session.gd`（4）。**客户端 274/274**；Go 全绿。
- **端到端自验**（临时 harness `tools/_session_smoke.gd`，验后即删）：真 docker——登录 → 持久会话 WS → 收 82KB 配置（ver `2d6c03b…`，15 文件，cards 16 张 knight cost 3）→ 连接稳定 → 重连用缓存 cfgver → 服务器回 **up_to_date 不重发**。全通过。
- **踩坑**：①客户端方法名 `is_connected()` 撞 Object 原生（签名不符警告升错）→ 改 `is_online()`。②配置包 82KB > WebSocketPeer 默认入站缓冲 64KB → 收不到大帧 → 调 2MB。③Bash cwd 跨命令保留（`cd server` 后 godot `--path .` 找不到 test_runner）。

### V5-N3+N4 — 服务器权威经济状态 + 结算动作（已完成）
**前置**：决策 48。把本地原型 S0~S6 的养成/经济搬上服务器做权威（Go + PG，复用 V4 库 + auth + httpx）。一起做、自验。
- **proto**：`economy.proto`（`EconomyState`{wallet+卡牌+关卡} / `CardState` / `StageState` / `EconomyActionReq`）+ `common.proto` MsgId `ECONOMY_*=61~65` + ErrorCode `ERR_ECONOMY_INSUFFICIENT/AT_CAP/LOCKED=500~502`。双端重生成。
- **N3 DB + 状态**：`migrations/0006_economy`（`economy_state` 钱包/货币/挂机/highest + `economy_cards` 每卡 level/rank/shards/unlocked + `economy_stages` 每关 stars/cleared，FK accounts CASCADE）。`internal/economy/repo.go`：`Get` 懒播种（首次访问 → 全卡 level1/rank1，starter 解锁，镜像 PlayerData.init_new）+ 读取。`GET /v5/economy/state`（Bearer，account 取自令牌）。
- **N4 结算**：`internal/economy/config.go`（`ParseConfig` 从 bundle 的 economy.json + card_progression.json 解析曲线，镜像 player_data 的 cost/level_cap/rank_up/unlock）。`repo.go` `Upgrade`/`RankUp`/`Unlock`：单 tx `FOR UPDATE` 锁卡+state 行 → **服务器算成本 + 校验（解锁/上限/金币碎片够）+ 扣 + 落库**，拒绝映射 409 + 业务码。`POST /v5/economy/{upgrade,rank-up,unlock}`。
- **客户端**：`net/economy_client.gd`（HTTP + protobuf + Bearer：`get_state`/`upgrade`/`rank_up`/`unlock`，返回服务器状态快照或业务错误码）。
- **api 接线**：`cmd/api` 加载 gameconfig + ParseConfig + 挂经济路由；compose 把 `../config` 也挂进 api（双份同源，服务器用它算成本）。
- **测试**：Go `economy` config（成本/上限/真实 16 卡）+ repo 集成（PG：播种 16 卡 8 解锁 / 升级扣金币 / 升阶扣碎片抬上限 / 解锁 / 上限拒·不足拒·未知卡拒）；客户端 `tests/test_net_economy.gd`（4）。**客户端 278/278**；Go 全绿。
- **端到端自验**（临时 harness，验后即删）：真 docker——登录 → 拉状态（服务器播种 16 卡 / 8 starter 解锁 / gold 0）→ 升级 knight **被服务器拒绝**（gold 0，ERR_ECONOMY_INSUFFICIENT，证明客户端刷不了）→ 服务器侧授金币 → 再升级 **服务器扣 gold 10000→9920、knight level→2**。全通过。
- **踩坑**：①`docker compose build api` 是 no-op（只有 gateway 有 `build:`，api 共享镜像）→ 改 build gateway 重建 `gcp-server:dev`。②login 的 `account_id` 在 V4-S1 服务端恒 0（smoke 授金币改用 device_id join accounts）。

### V5-N5 — 通关发奖 + sanity 校验（已完成）
**前置**：决策 48。客户端上报 (stage_id, stars)，服务器 sanity 校验 + 发首通/重复奖励（含概率掉落）+ 记进度，全服务器权威（镜像 player_data.grant_stage_reward + stage_progress）。
- **拍板（用户 2026-06-27）**：①shard_drop 概率掉落 N5 就做（服务端 `math/rand`，非 lockstep 无需确定性，概率走配置表可控）；②0 星/超上限/未知关 → 复用 `ERR_INVALID_ARG`；③**stars 超上限 = 拒绝**（不钳制），detail 要告诉客户端原因；④进度连续 = 线性解锁（第一关恒可，否则前一关 cleared）；⑤范围只做通关发奖+sanity+记进度。
- **config.go 扩展**：`ParseConfig` 增量解析 `stages.json`（`Stage`{chapter/index/coef/FirstClear/Repeat/ShardDrop/starCap} + 按 (chapter,index) 升序的有序序列），跳过 `_` 元字段；缺 stars → starCap 默认 3。新增查询：`Stage/OrderedStageIDs/PrevStage/StarCap`（线性解锁/防跳关用）。
- **proto**：`economy.proto` 加 `StageClearReq{stage_id, stars}`（注释 0=拒/≥1=通关，不超 stars 配置条数）；`common.proto` MsgId `ECONOMY_STAGE_CLEAR_REQ=66` + ErrorCode `ERR_ECONOMY_STAGE_LOCKED=503`（跳关专用）。双端重生成（Go protoc + GDScript godobuf）。
- **repo.go StageClear**：sanity 三道——关存在(`ErrUnknownStage`) / stars≥1(`ErrInvalidStars`) / stars≤starCap(`ErrTooManyStars`)；线性解锁——有前驱且前一关未 cleared → `ErrStageLocked`。单 tx `FOR UPDATE` 锁 stage+state 行 → 发奖：首通(未 cleared)=`first_clear`、重复=`repeat`，固定碎片(reward.Shards)+shard_drop 概率(`rng().Float64()<chance`) → 写 `economy_stages`（stars 取 max、cleared=true）→ 刷 `highest_cleared`（有序序列里最后一个 cleared）→ 回新 `EconomyState`。
- **handler.go**：`POST /v5/economy/stage-clear`（单独 handler，带 stars 非 card_id）；`mapErr` 扩 503/跳关 → `ERR_ECONOMY_STAGE_LOCKED` 409，0星/超上限/未知关 → `ERR_INVALID_ARG` 400（detail 带 err.Error() 说明原因）。
- **客户端**：`net/economy_client.gd` `report_stage_clear(http, token, stage_id, stars)`（`StageClearReq` 打 `/v5/economy/stage-clear`）。
- **测试**：Go `economy` config +3（stages 解析：有序序列/前驱/reward/drop/starCap；真实 config 含 stages）；repo 集成 +3（首通发奖+stars max+highest、重复、跳关拒、0星拒、超上限拒、shard_drop 概率 200 次掉落验证）；客户端 `test_net_economy.gd` +1（StageClearReq roundtrip）。**客户端 279/279**；Go economy 全绿（含 N3/N4 旧测零回归）。
- **端到端自验**（临时 `cmd/e2e_n5`，验后即删）：真 docker 6 场景全 ✓——①首通 1_1(2★) +300g/+5gem/highest=1_1；②重复 1_1(3★) +30g→330；③0★ 拒 400 `ERR_INVALID_ARG` "stars must be >= 1"；④4★>cap 拒 400 `ERR_INVALID_ARG` "stars exceed stage star cap"；⑤跳关 1_2(1_1 未通) 拒 **409 `ERR_ECONOMY_STAGE_LOCKED`(503)** "stage not unlocked: previous stage not cleared"；⑥首通 1_2(1_1 已通) +320g/+skeletons:3/highest=1_2。
- **踩坑**：①首版 StageClear 漏发 first_clear/repeat 的**固定碎片**（只处理了 shard_drop）→ 测试 stage_1_2 首通 skeletons=0 抓出，补 `reward.Shards` 发放分支修复。②Go 全量 `-p 1` 偶现 economy flake（跨包共享 DB 残留 + 时序），`-count=1` 重跑稳定通过（非真 bug）。

> **下一步 V5-N6（挂机服务器时钟结算）**：服务器存 last_collect，按**服务器时间**算挂机产出落库（改本地时钟无效）。修复决策 48 头号刷资源漏洞（本地改时间刷挂机金币）。

### V5-N6 — 挂机服务器时钟结算（已完成）
**前置**：决策 48。挂机离线金币从「客户端本地时钟」（本地改时间可刷）改为「**服务器时钟**结算 + 落库」，修复头号刷资源漏洞。镜像 player_data.collect_idle，now 全服务器定。
- **拍板（用户 2026-06-27）**：①新号 `ensureSeeded` 时把 `idle_last_collect_ts` 设为当前服务器时间（注册即计时，更符合「挂机」直觉，非严格镜像 player_data 的 0 初值）；②章节驱动产率（rate=gold_per_hour_per_chapter×chapter），数值走 economy.json 配置（`idle: {gold_per_hour_per_chapter:50, cap_hours:8}`），代码不写死；③CollectIdle 纯触发无参（now 全服务器定）。
- **config.go 扩展**：`ParseConfig` 解析 economy.json `idle` 段（`Idle`{GoldPerHourPerChapter, CapHours}）；新增 `IdleRatePerHour(chapter)`（=GoldPerHourPerChapter×chapter）、`IdleCapHours()`、`HighestChapter(highestCleared)`（从 stage_id 查章节，未知/空→0）。
- **proto**：`economy.proto` 加 `CollectIdleReq{}`（空消息，纯触发）；`common.proto` MsgId `ECONOMY_COLLECT_IDLE_REQ=67`。双端重生成。
- **repo.go CollectIdle**：`now = time.Now().Unix()`（**服务器时钟**）→ 单 tx `FOR UPDATE` 锁 state 行 → 读 gold/last_collect/highest_cleared → `idlePending(now, lastCollect, highest, cfg)` 算累计（rate=IdleRatePerHour(HighestChapter)，elapsed=(now−last_collect) 钳≥0，hours=min(elapsed/3600, CapHours)，pending=floor(rate×hours)）→ 发金币 + last_collect=now → 回新 `EconomyState`。`ensureSeeded` 播种时 `idle_last_collect_ts=time.Now().Unix()`。
- **handler.go**：`POST /v5/economy/collect-idle`（无业务入参，读 body 验 proto 合法性即可）。
- **客户端**：`net/economy_client.gd` `collect_idle(http, token)`（`CollectIdleReq` 打 `/v5/economy/collect-idle`）。
- **测试**：Go `economy` idle 纯函数 `idle_test.go` 3（累计/封顶/边界 lastCollect≤0·未通关·时钟倒退·未知 stage）；config idle 解析 2（cfg + 真实 economy.json 50/8）；repo 集成 `TestRepo_CollectIdle`（新号播种 last_collect>0 / 未通关产0 / 倒拨 2h 累计 / 封顶 8h / 立即再领0 / 基准刷新）+ `TestRepo_CollectIdle_ServerAuthoritative`（服务器时间权威）；客户端 `test_net_economy.gd` +1（CollectIdleReq roundtrip）。**客户端 280/280**；Go economy 全绿（15 测，N3/N4/N5 旧测零回归）。
- **端到端自验**（临时 `cmd/e2e_n6`，验后即删）：真 docker 5 场景全 ✓——①新号 collect（注册即计时 last_collect>0，未通关产 0）；②通关到 chapter1 后立即领（elapsed≈0，金币=通关奖励）；③倒拨 last_collect 2h（chapter1 rate 50/h，gained ~99~100，时间戳毫秒精度致 floor 偶差 1）；④倒拨 100h（封顶 cap 8h → 50×8=400）；⑤立即再领（基准已刷新 → +0，无重复领）。**服务器时钟权威验证成立——客户端改本地时钟无效**。
- **踩坑**：①首版纯函数测试用 `lastCollect = 10000 - 3600*100` 算出负数（-350000）→ 命中 `lastCollect<=0→0` 误判封顶失败，改用大基准时间戳 `base=1e9` 修复（非逻辑 bug，测试数据问题）。②e2e 倒拨 2h 期望精确 +100 实得 +99（floor + 时间戳毫秒精度），改用容差 [95,100] 判断——这是 floor 的真实行为（挂机不满整点按比例给），非 bug。③e2e 集成测代码编辑时误删了相邻的 `TestRepo_StageClear_ShardDrop` 函数签名（Edit 范围误伤），已补回。

> **下一步 V5-N7（瘦客户端化）**：`PlayerData` 降为服务器状态缓存；养成/领奖改调 API；开战从服务器拉权威 level/rank → 客户端确定性算战斗数值。真机验收：改存档/改时钟均无效（N6 已堵时钟，N7 堵存档）。

### V5-N7 — 瘦客户端化（已完成）
**前置**：决策 48。客户端养成数据从「本地存档权威」改为「**服务器权威 + 本地非权威缓存**」，堵住「改本地存档文件影响开战数值」。N6 已堵时钟、N7 堵存档，在线化整线收官。
- **现状发现（关键）**：开工前读到——客户端养成（PlayerData）此前是「纯逻辑层 + 单测」状态：`match.setup_stage(stage_id, deck, player_data)` + `player.gd` 的 `player_data` 注入口子（出兵按卡 level/rank 算乘区）**早已写好**，但 `battle_scene` 实际开战用的是老的 `match.setup(...)`、view 层零养成 UI（grep upgrade/economy_client 全空）。即养成还没接进实际游戏（那是 S7 的活）。故 N7 聚焦「为 S7 备好权威数据来源机制」，不碰 UI、不给 battle_scene 加无入口的死代码。
- **拍板（用户 2026-06-27）**：路径 A（纯逻辑+代码，不动 UI）/ 本地档 A1（保留但降为非权威缓存镜像）/ 真机验收留 S7（N7 单测覆盖）。
- **`PlayerData.apply_server_state(server_state, all_card_ids)`**：从服务器权威快照重建自身（shape = `economy_client._state_to_dict` 输出：顶层 gold/gems/idle_last_collect_ts/highest_cleared；cards/stages 嵌套）。与 `load_dict` 区别：后者读本地存档 schema（wallet/idle 嵌套），本方法读服务器 schema；ensure 缺失卡补默认条目。
- **`net/economy_state_cache.gd`（EconomyStateCache）**：持有最近一次服务器状态快照（PlayerData 形状）。`refresh(http, token, all_card_ids)` 调 `economy_client.get_state` → `apply_server_state` 重建 + `is_loaded=true`；**`for_battle(all_card_ids)` 返回适合注入 `Match.setup_stage` 的 PlayerData**（已加载→缓存即服务器养成；未加载→默认新档保战斗能跑）；`seed_from_local(pd)` 离线兜底（秒启动展示，不改 is_loaded）；`get_cache()` UI 只读。
- **`SaveSystem` 降级**：`save_player/load_player` 注释改为「**非权威本地缓存镜像**」——存读的 `player_save.json` 是 EconomyStateCache 的落盘镜像（秒启动/离线只读），不是权威档；开战/校验用 `EconomyStateCache.for_battle()`（服务器拉来），改本文件不影响开战；登录后被服务器覆盖。
- **不动的部分（明确边界）**：没改 `battle_scene`（S7 做闯关入口时调 `cache.for_battle()` 注入 `setup_stage`）；没碰 view/ UI；没改服务端 Go（N7 纯客户端）。
- **测试**：`test_player_data.gd` +1（apply_server_state 重建 + ensure 缺卡）；`test_economy_state_cache.gd` 新建 4（for_battle 未加载返默认 / for_battle 用服务器养成≈3.0 / **改本地档不影响开战（决策48核心）** / 缓存反映最新服务器态）。**客户端 285/285**；Go 全绿（N7 未动服务端，零回归）。
- **端到端自验**（临时 `cmd/e2e_n7`，验后即删）：真 docker get_state 返回完整养成快照（16 卡 8 解锁 + idle_last_collect_ts>0 + knight baseline），客户端 apply_server_state 后即可开战——服务器侧链路验通（客户端 apply/for_battle 已被 GDScript 单测覆盖）。
- **踩坑**：①首版用 `//` C 风格注释（GDScript 用 `#`）→ 改。②测试用 `before_each` 钩子，实际 runner 调的是 `setup()` → 改方法名。③`for_battle` 依赖 `is_loaded`，测试模拟 refresh 成功要直接设 `cache.cache`+`is_loaded=true`（seed_from_local 不改 is_loaded，语义上离线兜底不算权威确认）。

> **在线化整线收官（N1~N7 全完成）**。后续转入 S7 UI 整合 → S8 内容铺量 + 平衡（详见下文 + 顶部总览表；完整口径见 [PLAN_V5.md](PLAN_V5.md) §11）。

### V5-S7 — UI 整合（已完成，KAN-58 Done）
**前置**：N1~N7 在线地基就绪（服务器权威经济 + `EconomyStateCache`）。把养成/经济/闯关从 headless 逻辑接上界面：**读 = 服务器权威快照缓存，执行 = API，展示算 = 本地 ConfigLoader**。设计稿 [docs/DESIGN_V5_S7_UI.md](docs/DESIGN_V5_S7_UI.md)。
- **S7a 共享 HUD 组件**：`view/ui/hud_widgets.gd`（工厂 + 纯助手）+ `hud_widget.gd`（纯 `_draw`：钱包条/星级/cost 药丸/阶 pip/数值条/锁罩，**0 贴图资源**）。
- **S7b 基地 Base Camp**：替换主菜单 START 入口；app shell 登录→`EconomyStateCache.refresh` 拉服务器状态→展示钱包/队伍战力（本地算·按推荐着色）/挂机产出+领取。
- **S7c~e 闯关+养成+组卡**：闯关地图 `stage_map` + 领奖开箱 `reward_chest` + `battle_scene` 接闯关模式（`setup_stage`→战后判星→`report_stage_clear`）；养成 `card_collection`/`card_detail`（升级/升阶/解锁走 `EconomyStateCache` 门面）；`deck_builder` 已解锁池 + 战力达标着色 + mode-aware 路由。
- **★修复必现 bug**：stale `GameState.run/campaign`（玩过肉鸽残留静态态）致闯关战误判肉鸽模式 → `deck_builder` 开战前清 run/campaign + `level_select` 清 stage_id。
- **日志**：客户端全流程 `[V5]` 打点；服务端 api 请求中间件 + economy handler 业务日志。
- **验收**：客户端单测 **290/290**；**真人全流程验收通过**（闯关 1-1 胜 3 星→首通 +300 金 +5 宝石→进度推进 + 1-2 解锁→挂机产出→升级 giant）。Jira KAN-58 **Done**。提交 `123866c`/`6e9c53d`（验收用例 [docs/ACCEPTANCE_V5_S7.md](docs/ACCEPTANCE_V5_S7.md)，7 例全过）。

### V5-S7+ — 养成卡多维排序（已完成，KAN-67 Done）
- 逻辑层纯函数 `logic/card_sort.gd`（键 rarity/cost/level/actionable + 稳定排序，5 单测）+ `card_collection` 顶部分段控件（4 键 + 升降序）+ 即时重排（缓存重建网格、不重拉服务器）+ 记忆上次选择（`user://settings.cfg`）。客户端 **295/295**；真机即时重排观感正确。提交 `f38f5eb`。

### V5-S8 — 内容铺量 + 平衡（🚧 进行中，KAN-59；S8a~d 代码完成、S8e 真人验收待）
**口径（用户 2026-06-27 拍板）见 [PLAN_V5.md](PLAN_V5.md) §11.3**：生成器铺量、10 章×10 关、coef 曲线、`rec=920×coef×T`、敌塔 HP 随 coef。服务器经济**完全配置驱动** → 铺量是纯配置、客户端+服务器两端自动吃到、无需改业务逻辑。
- **S8a 遭遇模板池 3→15**（按原型补 12 deck）+ ConfigLoader 校验加固（archetype 枚举 + deck 8 张互不重复）。客户端 **300/300**。提交 `844fb33`。
- **S8b 平衡 probe harness**：`tools/balance_probe.gd`（headless AI-vs-AI 确定性扫战力门槛）+ **AIController 可选边改造**（构造第 4 参 `controlled_owner`，opponent 默认边恒等→零回归）。客户端 **305/305**。提交 `844fb33`。
- **S8c stages 铺到 100 关**（生成器）：`config/stages_spec.json` + `tools/build_stages.py`（+`--check`）→ `config/stages.json`（coef 1.0→2.842、rec 800→2275、boss ×1.1、奖励随章放大）。gameconfig sha256 自动 bump，服务器需重启读新配置。客户端 **311/311** + Go 集成测对真 docker PG 全过。提交 `d7730dd`。
- **S8d 平衡 pass**：敌塔 HP 随 coef 放大（`Match.scale_opponent_towers`，我方塔不缩放）+ 真关卡 probe 报告器 `tools/run_stage_balance.gd` + 平衡报告 [docs/BALANCE_V5_S8.md]。**核心发现**：AI-vs-AI 非可靠绝对裁判（规则 AI 不主动推塔→早期关王塔满血却超时输），但曲线形状被验证（王塔剩血 100%(ch1~3)→0%(ch4+)，难度咬人在 ch4≈coef1.5，符合"早苟中养成"）；曲线保持公式默认、不拟合 AI 假象，手感绝对校准交 S8e 真人。客户端 **313/313**。提交 `d7730dd`。
- **GM 作弊工具（KAN-68 Done）**：随 S8 提交，服务器权威改 `economy_*` 表（加货币/碎片/解锁/满养成/通关到第 N 章/重置）+ 设置内 GM 面板；env `GM_ENABLED` 门控、**prod 必关**，走会话鉴权只能改自己账号。真 PG 集成测全过 + 真人验收过。提交 `d7730dd`。

> **下一步 = V5-S8e 真人验收**：从第 1 章推进体验难度曲线（用例 [docs/ACCEPTANCE_V5_S8.md](docs/ACCEPTANCE_V5_S8.md)），验收过 + 用户同意后 KAN-59 → Done。之后：联机对战美术对齐（KAN-49，把单机精灵/FX/手感搬进 `net_battle_scene`）/ 上线化（IAP·合规·赛季榜，V6+）。

### 工程迁移 + 多 agent 共享工作树踩坑（2026-06-28）
**迁移**：`Move-Item F:\godotProject F:\godotTowerPush\master`（同盘瞬时重命名、零拷贝）→ git 仓库/对象/远端全部无损、`.git/config` 无旧路径泄漏；工程 `res://` 相对路径天然不受影响、`.godot/` 缓存 gitignore 重建即可。仅**文档线滞后**于代码（CLAUDE 进度停在 N5、README 290 单测、多处旧绝对路径 + 旧 `develop` 分支约定）→ 本轮统一对齐到现实（主干流 / S8 进行中 / 313 单测 / 旧路径清理），提交 `cfa15d7`。
**踩坑（两个 agent 抢同一个工作树）**：文档作业期间，另一个 agent（ZCode）在**同一个工作树**里 `git checkout` 把分支从 `master` 切到新建临时分支 `zaiDev`，我那批**未提交**的文档改动被一起带了过去（切分支时未提交改动会跟随 HEAD）。
- **诊断**：`git reflog` 还原序列（`commit 247c15f` → `checkout: moving from master to zaiDev`）；`git stash` 空、无提交吞掉改动；关键发现——`zaiDev` 从 `master` 尖端刚拉出、**两者指向同一 commit `247c15f`**。
- **无损还原**：因两分支零差异，`git checkout master` 时 Git 不改任何工作区文件、未提交改动原样留下、HEAD 重指 master → 改动安全归位（不可能冲突或丢失）。随后用**显式文件名** `git add`（避免在共享树里卷入异己改动）+ 提交 `cfa15d7`，工作树转干净、解开两 agent 纠缠。
- **教训**：① **多个 agent 绝不共享一个工作树**——每任务用 `git worktree add ../master-<feat> <branch>` 开独立树作业（正是 CLAUDE.md / AGENTS.md「分支约定」要求的纪律，这次正是没遵守才撞）；② 提交前先 `git rev-parse --abbrev-ref HEAD` 验分支、`git add` 用显式文件名不用 `-A`；③ 已关停乱切的 ZCode；`zaiDev` 待其任务合回 master 或废弃后 `git branch -d zaiDev` 清理。

### V5-KAN49 — 联机视觉对齐（🚧 代码完成、真人两机验收待跑）
**前置**：V4-S3 联机对战场景 `net_battle_scene` 当初为聚焦网络正确性做成**矢量白膜**（圆=单位/方块=塔/文字卡面），记 KAN-49 待办。本次把单机 `battle_scene` 的完整视觉搬进去。**逻辑层零改动**——lockstep 跑同一 `logic/match.gd`，单机/联机的 Match/Battle/Arena/Unit/Tower/Player/Deck/Elixir 实例就是同一个类的实例，juice/FX/插值/投射物（基于 `get_instance_id()`+hp/cooldown diff）**owner/side 无关、零适配直接搬**。纯 view 层搬运 + 联机特有的 3 处适配 + 3 个技术坑。

**联机特有 3 处适配（必改）**：
1. **`match_obj.player → _client.local_player()`**：单机 ~8 处 `match_obj.player.{deck,elixir,can_play,card_cost}` 直读（单机本方恒 player）；联机 side2 玩家本方是 opponent（owner 不随 side 翻转：恒 player=0/opponent=1）→ 圣水条/卡面/下一张/拖拽判 mine 全部走 `local_player()`。
2. **owner/side 翻转**：①队伍色 `_is_mine(owner)`=`(o==0 and not _flip) or (o==1 and _flip)`；②王冠计数 `_my_towers()/_foe_towers()` 按 `_flip` 选 player/opponent_towers；③落点 `can_deploy(owner)` 的 owner=`your_side-1`（side1→0/side2→1）；④己方半场高亮 `_deploy_y_min`=`deploy_player_y_min if not _flip else grid_h-deploy_player_y_min`（本方半场恒在屏幕下方）；⑤胜负语义 result 是 **side 语义**（winner 1=side1/2=side2），`mine = _flip?2:1`。
3. **结算演出触发源**：单机靠 `match_obj.is_over()` 本地判 → 联机改 `_on_result` 服务端信号驱动 `_start_ending`。

**联机特有 3 个技术坑**：
1. **sim 驱动差异（命门）**：联机 sim 由 `battle_client.poll`→tick bundle→`advance_tick` 驱动，**view 不能调 `match_obj.update()`**（单机那样做会双驱 sim、破坏 lockstep）。`_detect_events`/`_detect_attacks`/`_update_disp`（只读 diff）照搬。**顿帧改写**：单机冻结 sim 无意义（sim 非本地驱动）→ 改「纯视觉顿帧」——冻结 FX 时钟 `_elapsed` 增量让画面定格，**不影响 lockstep 推进**（`_process` 里 `if _hitstop_t>0: _hitstop_t-=delta else: _elapsed+=delta`）。
2. **精灵朝向翻转**：side2 坐标 `_t2s` 翻转是平移不旋转像素 → owner 1（本方）兵贴图朝向会反。解法：`SpriteDB.frame` 的 owner 参数在 `_flip` 时镜像传值（`spr_owner = u.owner_id; if _flip: spr_owner = 0 if u.owner_id==1 else 1`），让贴图朝向跟随屏幕视角而非逻辑 owner。
3. **资源/音频齐备**：`battle_scene`+`sprite_db` 所有 preload 路径 + `.import` 全部存在直接复用；AudioManager 是全局 autoload、缺失资源静默 no-op（当前音频文件未入库，调用都是空操作，与单机一致）。

**一次性搬运的 7 大模块**（`view/net_battle_scene.gd` 366→~960 行整体重写）：①资源 preload（塔/FX/投射物/地形 + SpriteDB）；②地形 `_draw_terrain`（地面/水动画/桥 + 己方半场高亮按 flip）；③单位 `_draw_units`（SpriteDB+状态派生 walk/attack+闪白+入场缩放+空军影子/上浮+side2 朝向翻转）；④塔 `_draw_towers`（贴图保持长宽比贴地+队伍色+血条+王冠+废墟）；⑤战斗 juice（`_detect_events`/`_on_hit`/`_on_tower_destroyed`/`_update_disp`/`_update_shake`/`_pop_scale`+顿帧改纯视觉）；⑥FX+投射物（`_detect_attacks`/`_tower_target`/`_draw_projectiles`/`_draw_fx`+落地涟漪+出牌音效）；⑦HUD+演出+音频（分段圣水+满槽脉动+自绘卡面+下一张+王冠倒计时；胜负演出调暗/标题 sting/王冠落入/比分滚动+按钮淡入，触发源改 `_on_result`；`_on_joined` 接 `AudioManager.play_music/play_ambience`）。

**验证**：客户端单测 **313/313 零回归**（`test_net_battle_client` 7 测不动）；headless `--editor --quit` 导入无脚本错误。net_battle_scene 是纯 view（`_draw` 驱动），无新逻辑层单测；**画面/手感交真人两机验收**。

**真人验收**：用例 [docs/ACCEPTANCE_V5_KAN49.md](docs/ACCEPTANCE_V5_KAN49.md)（8 例：地形/精灵/塔/HUD/涟漪投射物FX/juice/胜负语义/**side2 视角全面**——side2 是联机特有最大风险点，须单独验精灵朝向不反、落点合法、本方数据正确）。**验收过 + 用户拍板 → KAN-49 Done**。

**分支/worktree**：本次在 `master-zaiDev` worktree（feat/zaiDev 分支原址）新建 `feat/kan49-net-visual` 开发（基于 master 尖端 ce699df；zaiDev 分支保留不动、待用户清理）。Jira KAN-49 To Do → **正在进行**。

### V5 卡池扩充设计（16→48）+ 三件套引擎 — 设计四部曲完成、T1 splash 开工（🚧 进行中，2026-07-03）

**背景**：战斗系统已可用但卡池仅 16 张、深度不足。用户发起卡牌系统深度扩充：扩池 + 稀有度/流派/觉醒三维体系。plan-first、逐阶段用户确认，四阶段设计文档产出于 `docs/design/`：
- `01_research.md`：CR 品类调研（稀有度/进化/流派/费用平衡/卡池规模，WebSearch）+ 本项目 16 卡 per-elixir 价值锚。
- `02_design_constitution.md`：稀有度(4 档·数值放大系数硬性 1.0)/流派(6 做 2 缓)/觉醒(rank 永久制·机制优先)/CV 平衡尺(CV=√(队伍HP×DPS)·近战地面基准 80·远程对空吃半预算) + 三件套 schema。
- `03_card_library.md`：+32 张达 48，金字塔 18/14/10/6，全表 + tech_debt + retrofit。
- `04_awakenings_meta.md`：16 张 epic+legendary signature 觉醒 + meta 分析(Lavaloon/Hog/Bait + 2 结构隐患) + 平衡原则(最小杠杆优先)。

**关键决策（用户逐阶段拍板 2026-07-03）**：①**稀有度≠强度**（`base_power` 只作战力折算/展示、禁喂战斗数值；同级同费不看稀有度）；②Champion 第 5 档暂不做（主动激活技能=重引擎）；③觉醒走 **rank 永久制**（非 CR 循环/进化槽，复用 `rank_unlocks`）；④signature 觉醒仅 epic+；⑤规模 ~48、金字塔 18/14/10/6；⑥6 流派做（swarm/beatdown/cycle/splash-control/air/bait-lite）、真 Siege+桥头 spam 缓；⑦**三件套(splash/building-target/status)** 获批为前置引擎工作；⑧retrofit **R-A(baby_dragon 加 splash) + R-B(giant/golem 只拆塔) 都做**。

**实现顺序**：三件套 T1/T2/T3 → retrofit R-A/R-B → 32 卡数值铺入 config + 校验 → 觉醒填 rank_unlocks → probe 平衡 → T6/T7 延后件(balloon death_aoe / inferno ramp / electro chain)。

**T1 · 单位攻击溅射 splash（本步 · 🚧 代码+单测完成，待用户确认后进 T2）**：
- `logic/unit.gd`：+`splash_radius`（默认 0=单体，零回归）；`setup` 解析；`apply_stat_mult` 不缩放它（radius 非战斗数值）。
- `logic/arena.gd`：攻击结算阶段 +`_collect_splash(attacks, attacker, primary, damage)`——命中后对 primary 周围 `splash_radius` 内**其他存活敌方单位**同施伤；只打单位不含塔、尊重 `can_hit_type`（地面溅射不误伤空军）、排除主目标防双击；收集式与主攻击同批 apply，确定性。
- `logic/config_loader.gd`：unit 校验加 `splash_radius` 可选（数字、≥0）。
- 单测 `tests/test_splash.gd`（4：多敌溅射 / 半径外不中 / 地面溅射不误伤空军 / splash=0 单体零回归）。**客户端 331/331**（+4，零回归）。注：顶部总览表的 313 为 KAN-49 时点旧值、之后 S9/KAN-76/78-79 累加至 327 未回写总览；本步 327+4→**331**。
- **边界**：T1 只做「单位攻击溅射」；法术 `aoe_damage` 不受影响；建筑索敌(T2)/状态(T3)/retrofit(R-A/R-B) 为后续步。
- **未提交**（用户暂不提交）。

**Jira 建单（用户 2026-07-03 明确要求用 Atlas MCP 建，覆盖"手工维护"默认）**：**KAN-80~88 共 9 张挂 Epic KAN-50 下**——KAN-80 设计四部曲(已完成) / KAN-81 T1(正在进行) / KAN-82 T2 + KAN-83 T3 + KAN-84 retrofit R-A/R-B + KAN-85 铺 32 卡 + KAN-86 16 觉醒 + KAN-87 probe 平衡(均待办 To Do) / KAN-88 延后件 T6/T7/chain(Idea)。

**T2 · 建筑索敌 target_priority=buildings（🚧 代码+单测完成，待用户确认后进 T3）**：
- `logic/unit.gd`：+`target_priority`（"nearest" 缺省=现状零回归 / "buildings"）；`setup` 解析。
- `logic/arena.gd`：`_acquire_target` 加分支——buildings 时无视敌方单位、直锁 `nearest_enemy_tower`、不被 aggro 分心。反制靠 body-block + 塔火 + 高单体 DPS（无防御建筑"拉扯"，见 docs/design/04 隐患A）。**本步先上纯版**；"优先建筑但仍受 aggro 拉扯"软版留 retrofit(KAN-84)/probe 定。
- `logic/config_loader.gd`：unit 校验加 `target_priority` 可选（nearest/buildings）。
- 单测 `tests/test_building_target.gd`（4：无视敌兵直锁塔 / 攻塔不打身边兵 / 朝塔推进不被侧兵勾走 / 缺省 nearest 仍分心零回归）。**客户端 335/335**（+4，零回归）。
- 服务哪些卡：bone_ram/royal_giant/hog_rider/battle_ram/balloon/lava_hound + retrofit giant/golem。**未提交**。

**T3 · 状态系统 status(slow/stun/freeze)（🚧 代码+单测完成，待用户确认）——三件套收官**：
- `logic/unit.gd`：+`on_hit_status`(命中施加) + 单状态计时层(`_status_kind/_timer/_mag`)；`apply_status`(硬控不被 slow 顶掉) / `tick_status`(衰减过期清空) / `action_speed_mult`(stun·freeze→0、slow→1-mag、无→1) / `is_stunned` / `has_status`；`can_attack` 加 stun 门；`tick_cooldown` 按 action_speed_mult 缩放（slow 减慢攻击恢复、stun 冻结冷却）。
- `logic/arena.gd`：tick 加 `tick_status`；移动 `_move_toward(u, target, dt × action_speed_mult)`（slow 减速/stun 停步）；攻击结算带 on_hit_status → apply 阶段对命中【单位】施加状态（塔不受状态，`is Unit` 守卫）；`_collect_splash` 透传 status（splash+slow 同施）。
- `logic/skill_system.gd`：`_aoe_damage`/`_direct_damage` 支持 `status` 块 → 命中敌兵施加（freeze 术 = damage 0 + status）；helper `_apply_block_status`。
- `logic/config_loader.gd`：unit `on_hit_status`(对象 + kind 合法) + card skill `status`(对象 + kind 合法) 校验。
- 单测 `tests/test_status.gd`（10：施加/衰减过期 · slow 行动乘区 · stun·freeze 停动停攻 · 硬控不被 slow 覆盖 · slow 减慢冷却 · on-hit 施加 · 眩晕不造成伤害 · 法术 freeze · slow 减少推进 · 无状态零回归）。**客户端 345/345**（+10，零回归；踩坑：移动测试原用地面兵，绕桥致 y 进度非单调误判 → 改飞兵直线越河）。
- 服务：ice/electro_spirit、giant_snowball、freeze、ice_wizard、electro_wizard + heal/lightning/musketeer/baby_dragon 等觉醒。**未提交**。

> **三件套 T1/T2/T3 全部代码+单测完成**（KAN-81/82/83，未提交），客户端 **345/345**。下一步 = retrofit R-A/R-B（KAN-84）→ 32 卡铺入（KAN-85）→ 觉醒填表（KAN-86）→ probe 平衡（KAN-87）。

**retrofit R-A/R-B（KAN-84，🚧 代码+配置完成，待真人验收）**：三件套就绪后给现有卡挂机制、让 RPS 三角闭合。
- **R-A** `config/units.json` baby_dragon_body +`splash_radius: 1.5`：单体飞行肉 → 空中反 swarm（补"空中清群"边）。
- **R-B** `config/units.json` giant_body + golem_body +`target_priority: "buildings"`：现会打兵 → 真·只拆塔 beatdown（无视敌兵直取塔；golem 亡语裂 2 哥布林保留）。
- **xlsx 同步（用户提醒）**：`splash_radius`/`target_priority` 是 units 新字段、原 `build_config.py` 固定 `UNIT_HEADERS` 不含 → 直接改 JSON 会破 xlsx 往返（--check 报缺字段、--from-json 丢字段）。**故给 `build_config.py` 加两列往返**：`UNIT_HEADERS` +2 列 + `TARGET_PRIORITIES` 枚举 + Excel→JSON 可选读（splash>0 / target_priority≠nearest 才写，仿 death_spawn）+ JSON→Excel 写 + target_priority 下拉校验。流程：基线 `--check` ok（原本同步、无未回灌手改）→ 改 JSON → `--from-json` 重建 xlsx → `--check` ok（往返一致）。
- **验证**：客户端 **345/345**（零回归：配置带新字段过校验、giant/golem 只拆塔 + baby_dragon splash 无单测回归）；`config check ok`。**决策**：这俩是 unit 字段 → 进 Excel 镜像（同 units.json 全镜像惯例，非 arena.json 式排除），designer 可在 Units sheet 调 splash 半径。**on_hit_status（嵌套 dict）的 xlsx 表示留 KAN-85**（届时有 status 单位才需）。
- **play-feel 交真人验收**（改现有 PvE 手感，用例见 docs/design 派生 + 对话）；**probe 数值复衡并入 KAN-87**（AI-vs-AI 非可靠绝对裁判、数值仍 placeholder）。**未提交**。

**🐞 修复：闯关进战斗空指针卡死（KAN-78 await 隐患，本轮验收暴露、非本轮改动引起）**
- **现象**：选卡组进闯关战斗，`view/battle_scene.gd:937 _sync_cards` 每帧 `Invalid access to property or key 'deck' on a base object of type 'Nil'`（`match_obj.player` 为 Nil）卡死。
- **根因**：闯关模式 `_ready` 有 `await economy.pve_start`（KAN-78 开战报到）；`match_obj` 在 await 前已建（第160行）、`player/battle` 要等 await 返回后 `setup_stage`（第199行）才建。节点处理默认开启 → await 挂起期间 `_process` 照跑，而 `_sync_cards` 只挡了 `match_obj==null`、没挡 `player==null` → 空指针（`_draw`/`_detect_*`/`_update_disp` 都挡了 `battle==null` 故安全，独 `_sync_cards` 漏挡）。
- **修复**：①`_ready` 开头 `set_process(false)`，末尾 setup 完的 `set_process(true)` 才逐帧（根治 await 窗口，其余早退场景也不再空转）；②`_sync_cards` 补 `match_obj.player == null` 守卫。headless 编辑器导入无脚本错误。**与本轮卡/引擎/config 改动无关**（未碰 view/；units.json 新字段是客户端战斗用、服务端不读）。**真人重测确认**。
- **相关提醒**：本轮改了 `config/units.json`（配置版本 sha256 会 bump）→ 建议**重启 Go 服务端**让它加载新配置，保 KAN-79 重放验证时客户端 sim 与服务端校验用同一份配置（否则 baby_dragon splash / giant 只拆塔的行为差异可能致重放 hash 不一致）。

**🔎 KAN-78/79 反作弊 × 卡池扩充/养成 冲突排查（dockers 实跑验证，2026-07-03）**
- **背景**：用户问三件套/新卡/养成会不会和 KAN-78/79 重放验证打架。
- **结论：架构上安全，冲突是"版本同步"运维问题、非架构问题。** 验证器 `tools/pve_verify.gd` 自己 `ConfigLoader.load_all()` 读 `res://config` + 复用 `res://logic`（MatchScript/BattleScript…）+ 服务器权威养成快照 → 与客户端 sim **同配置同逻辑同养成**、无逐卡硬编码，新卡/新机制/养成天然一致。
- **实跑验证**（临时 smoke `tools/_pve_retrofit_smoke.gd`，验后删）：录一局含 retrofit 机制（baby_dragon splash + giant/golem 只拆塔）→ 进程内 `PveReplay.replay` + 真 CLI `pve_verify.gd` **均 pass**（逐 hash 全等、win、ticks=428/king_permille=1000 一致）。三件套/retrofit 确定性穿过 KAN-79 完整链路。
- **真冲突（运维·3 处须同版本：客户端 res:// / Go 内存 cfg / verifier 容器拷贝）**：
  1. **verifier 容器 = 启动那刻从只读挂载 `/repo` 拷 logic/config 到 `/work/project`**（`verifier-entrypoint.sh`）→ **改 logic/config 后必须 `docker restart server-verifier-1` 重新拷**，否则用旧逻辑重放 → 每局 ticks/king_hp 对不上 → mismatch → `accounts.ban_status=1` shadow 标记。**本轮已重启同步**（容器 2h 前起、我改动更晚；重启后日志确认 re-staged + polling）。
  2. **加新卡(KAN-85) → 必须重启 api**：`ensureSeeded` 从服务端内存 cfg 播种 `economy_cards`；`PveStart` 要求卡组 8 张全有行 + unlocked，否则 "card unknown" 拒开战。
  3. **min_stage_duration_s=15（墙钟）vs 强卡快通**：giant 只拆塔可能 <15s 通关 → `validatePveClaim` 判 "too fast" 误杀。铺卡/平衡时留意。
- **附带澄清**：verifier 日志里 `bad hash entry`/`mismatch` 是在啃**集成测试合成数据**（`h="aa"`/单条指令，battle 653-655/463-477），非真实对局、非 bug（用户被崩溃挡住没打成真局）。验证器本身正常。
- **运维铁律（卡池后续每步）**：改 logic/config → 重启 verifier 容器；加卡 → 另重启 api（+gateway 保配置版本）。

**✅ 验收收尾（2026-07-03，本批一起提交）**：三件套 **T1/T2/T3** + **retrofit R-A/R-B** 真人验收通过——①闯关进战斗不再崩/卡死；②giant/golem 只拆塔；③baby_dragon(游戏内名「余烬火颅」)溅射清群。客户端 **345/345**。Jira **KAN-81/82/83/84 → Done**，闯关崩溃修复建 **KAN-89(Bug) → Done**。verifier 容器已重启同步。**下一步 = KAN-85 铺 32 张新卡**（届时 restart api + verifier；含新卡 id↔中文名对照表 + on_hit_status 的 xlsx 表示）。**另交付美术清单** `docs/design/card_art_spec_48cards.xlsx`（48 卡×17 列，种族/职业/体型/移动/攻击/动画/特效，供美术画原画+帧动画+FX）。

### V5 卡池扩充 · KAN-85 铺 32 张新卡（✅ 完成，2026-07-03，独占 master 自主开发）
- **32 卡入库** → **48 张**（普通18/稀有14/史诗10/传奇6）：`cards.json`/`units.json`(+27 单位实体，含复用 minion/goblin/skeleton/spear_goblin body)/`card_progression.json`。数值=docs/design/03 §D 角色模板锚定示意值·待 KAN-87 probe。用足三件套：splash(fire_spirit/valkyrie/bomber/wizard/executioner/ice_wizard/princess)、building-target(bone_ram/royal_giant/hog_rider/battle_ram/balloon/lava_hound)、on_hit_status(ice/electro_spirit/ice_wizard/electro_wizard) + 法术 status(giant_snowball/freeze)；多积木(goblin_gang/electro_wizard 落地 zap)、亡语链(bone_ram→骷髅/battle_ram→蛮兵/phoenix→重生/lava_hound→6火犬)。
- **build_config.py 扩**：Units +`on_hit_status_kind/dur/mag`、CardSkills +`status_kind/dur/mag`（flatten 嵌套 dict）+ `STATUS_KINDS` 枚举 + 下拉校验。`--from-json`+`--check` 往返一致（32 新卡 + status 列都镜像进 GameConfig.xlsx）。
- **card_progression**：32 卡 rarity/base_power/`starter:false`(未解锁) + 轻量 rank_unlocks（swarm→count_add/法术→num_add/其余 stat；**epic+ signature 觉醒留 KAN-86**）。
- **服务端 ensureSeeded 改增量补种**(`repo.go`)：`INSERT … ON CONFLICT (account_id,card_id) DO NOTHING` —— 新卡上线后**已有账号下次访问自动补进缺失卡**（不动已有养成；新卡 starter=false 播为未解锁）。修 `config_test`/`repo_integration_test` 的 16→48 断言。Go 的 `cfg.Cards` 只从 card_progression 读 rarity/starter/base_power（忽略 rank_unlocks、不碰 cards.json skills），故 status 字段不影响服务端。
- **验证**：客户端 **345/345** + 临时 smoke（32 卡出兵数/三件套字段/lava_hound 裂6火犬/法术 status/电法师多积木，验后删）全过；Go economy 集成测（真 PG）全过（48 卡解析 + 播种 48）；`docker compose build gateway` 编译通过 → 重建 api+gateway + 重启 verifier，**api 日志 `economy config loaded (48 cards, cfg ver=96e05036)`**、DB 账号卡数=48。
- **⚠️ 用户须知**：新卡播为**未解锁** → 用 GM unlock-all（或攒碎片）才进卡组/PvE；api+verifier 已重启加载新配置。**下一步 KAN-86：为 epic+legendary(16 张)填 signature 觉醒到 rank_unlocks**。

### V5 卡池扩充 · KAN-86 觉醒填 rank_unlocks（✅ 完成，2026-07-03，独占 master 自主开发）
- **16 张 epic+legendary 填 signature 觉醒**（rank3 marquee + rank2 轻量）：**12 张真觉醒**用现有 ops+三件套表达——
  unit_field 挂 on_hit_status/splash：musketeer 破法弹 · baby_dragon 烈焰吐息(splash 1.5→2.5+减速) · wizard 烈焰风暴 · executioner 行刑领域(splash→3.5) · ice_wizard 凛冬将至(强减速) · princess 烈焰箭雨；
  unit_field death_spawn：golem 崩解(死裂→石心魔像) · lava_hound 熔火降临(火犬→喷火小龙) · phoenix 烈焰重生(重生满配)；
  法术：lightning 雷暴(**set_field 加 stun**) · freeze 绝对零度(num_add damage+200) · skeleton_army 亡骨潮(count_add 14→18)。
  **4 张留 KAN-88**（rank3 stat 占位+note）：heal 战意(需 haste 正向状态) · balloon 临空爆弹(T6 death_aoe) · electro_wizard 连锁闪电(chain) · inferno_dragon 熔核过载(T7 ramp)。
- **`logic/card_progression.gd` +`set_field` op**：直接设某块 field=value（任意类型含嵌套 dict，如给法术块加 status:{kind,dur,mag}）——法术觉醒用。unit_field 已能挂 on_hit_status/splash_radius/death_spawn_unit(dict/值任意)。
- **2 觉醒专用单位**(units.json)：`golemite_body`(石心魔像·只拆塔小坦)、`fire_pup_body`(喷火火犬·空中溅射)。`--from-json`+`--check` 往返一致。
- **验证**：客户端 **353/353**（+8 `test_v5_awakening`：effective_skills 的 unit_field/set_field/num_add 正确 + 运行时余烬火颅溅射变大+减速、雷暴命中眩晕、golem 崩解裂石心魔像、留 KAN-88 占位不改积木）；临时觉醒重放 smoke（rank3 觉醒局 record→PveReplay **逐 hash 全等 pass**，验后删）。
- **服务端无改**：Go `cfg.Cards` 只读 rarity/starter/base_power、忽略 rank_unlocks → 经济/播种不变，**api/gateway 无需重启**；仅 **verifier 已重启**（觉醒经 card_progression.gd 应用，重放需新配置/逻辑）。
- **下一步 KAN-87 probe 平衡**（48 卡+觉醒数值定稿）/ KAN-88 延后件（T6 death_aoe / T7 ramp / chain / haste）。

### V5 三国题材改版 · 轨道A1+A2 文案层三国化（✅ 代码+配置完成，待真人验收，2026-07-04）

**背景**：用户与美术设计师拍板——世界观/画风**全换三国题材**（魏/蜀/吴/群雄四阵营，热血物语方向三头身高清像素，序列帧为主）；**卡ID/费用/数值/机制/流派/结构全部冻结**（ID 是 DB economy_cards/decks、重放、反作弊校验主键，不动=服务端零改动，换皮压缩在显示层+素材层）。美术真相源=用户新交付《三国card_art_spec_48cards.xlsx》（48卡×19列，+阵营列 12×4 羁绊预留、+设计备注 sheet：稀有度=人物档次映射、顶级人物储备曹刘孙关张赵吕马、飞行包装=机关兽/飞具/方术三家）。施工图 [PLAN_V5_SANGUO.md](PLAN_V5_SANGUO.md)（轨道A A1~A4 + 决策 6 条 + 48 卡命名对照表）。**数值线 KAN-87/88 挂起**（用户指示，轨道A 后复盘；本 session 前段的 CV 审计离群结论保留：inferno_dragon 平 200 DPS 全池最超模等，见对话记录与 PLAN_V5_SANGUO §0）。

**A1 · 美术表口径对齐入库**：新表觉醒列有 5 处写的是 04 设计稿目标态、超前于 KAN-86 已实现机制（表自身"觉醒机制保持不变"强约束自相矛盾）→ 按"以实现为准"降级改写：左慈阴兵王领队→+2数量(14→18) / 司马懿减速叠层至冻结→强减速 / 孙尚香燃烧减速地带→命中减速 / 庞统火鸾满配重生+落地减速→仅满配重生 / 于吉范围眩晕→单体眩晕；**增强版全部列为 KAN-88 机制升级项**（cell 内【】标注）。另 4 张延后件觉醒（荀彧 haste/孔明灯 T6/张角 chain/机关龙 T7）标注"当前数值占位"。修订版覆盖入库 `docs/design/card_art_spec_48cards.xlsx`（奇幻旧版 git 历史留档；docs/design/01-04 内卡名仍为奇幻旧名、存档备查，三国名以美术表+config 为准）。

**A2 · 文案层三国化**：
- `config/cards.json`：48 卡 name 三国化 + 新增 **`faction` 字段**（wei/shu/wu/qun，魏12/蜀12/吴12/群雄12；当前仅题材归属+未来羁绊预留，不产生克制）。`config/units.json`：39 单位 name（衍生/觉醒单位改名：石心魔像→**石心攻城兽**、喷火火犬→**喷火小龙**、熔岩火犬→**南蛮幼鸢**、凤凰(重生)→**火鸾·重启**）。`config/card_progression.json`：22 处 rank_unlocks note 换三国觉醒名（破法箭/烈焰东风/古之恶来/雷暴(单体)/王佐军心/临空火坛/阴兵如潮/凤火重启/寒江绝策/机关化生/火神降临/冢虎寒域/黄天雷劫/枭姬火阵/火脉过载 + 群卡计数名 阴兵/山越兵/魂鸦/弩手）。
- **🐞 顺带修复 i18n 卡名断层**：UI 卡名走 `tr("card_"+id)`（deck_builder/card_collection/card_detail/battle HUD/net_battle/run_scene/account_create），`config/i18n.json` 原只有旧 16 卡键 → **KAN-85 铺的 32 张新卡在 UI 一直显示原始键名**（如 card_spear_goblins）。本次 en/zh 各补全 **48 键**（zh=三国名；en=英译初版，名将用拼音 Huang Zhong/Zhou Yu/Sima Yi/Zhang Jiao/Sun Shangxiang，待后续审校）。
- 稀有度显示名：`view/card_collection.gd` + `view/card_detail.gd` `_rarity_zh` 普通/稀有/史诗/传说 → **寻常/精良/非凡/无双**（**内部枚举 common/rare/epic/legendary 不动**——DB/配置/服务端在用；品质框颜色不变）。
- 工具链：`tools/build_config.py` Cards sheet +`faction` 列（FACTIONS 枚举+下拉校验；空=不写 JSON 零回归）；`logic/config_loader.gd` cards faction 可选校验（枚举）。`--from-json` 重建 GameConfig.xlsx + `--check` 往返一致。
- **验证**：客户端单测 **353/353**（零回归）；config check ok。
- **运维**：改 config → 版本 hash bump，需重启 api+gateway+verifier；本次 **docker daemon 未运行**（Docker Desktop 拉起超时）→ 无旧配置容器在跑、无 mismatch 风险；**下次 docker 起来容器自启即加载新配置**（verifier entrypoint 启动时拷贝、api/gateway 启动时解析）——若届时容器已带旧配置在跑，手动 `docker restart server-api-1 server-gateway-1 server-verifier-1`。
- **Jira 未同步**（Atlassian MCP 本会话不可用需授权）：手工清单见 PLAN_V5_SANGUO.md §4——①新建 Story「三国化-A1A2」In Progress（真人验收后 Done）②Task「三国化-A3 场景系统美术清单」To Do ③Story「三国化-A4 素材接入+世界观文本+遭遇奖励回填」To Do ④KAN-88 描述追加 5 项增强觉醒 ⑤KAN-87 挂起备注。
- **真人验收点**：图鉴/卡详情/卡组构建/战斗 HUD 全 48 卡显示三国名（**重点：32 张新卡不再显示 card_xxx 键名**）；稀有度显示 寻常/精良/非凡/无双；7 字长名（归附山越短刀兵/蜀汉火脉机关龙）在卡格/HUD 的截断表现（溢出则 A3 一并调 UI）。（2026-07-04 尾声：dockers 全起、api 已加载新配置 `cfg ver=cd27932e…`、verifier re-staged——运维同步闭环。真人验收用户暂欠。）

### V5 三国改版 · 48 卡可玩性查证 + 横版战斗立项（📋 查证+方案，2026-07-04，未 commit 待用户指示）

**48 卡"能不能玩"查证结论**（回应用户问询）：
- **机制层：全可玩**。48 卡 config/逻辑/经济播种全通（353 单测），GM unlock-all 后即可组卡进 PvE/天梯，三件套机制/觉醒都真生效。
- **表现层：29/39 单位无贴图**。`view/sprite_db.gd`（纯表现 manifest）只登记了 10 个旧单位的帧动画；其余 29 个新单位战斗中回退**白膜占位**（`frame()` 返回空 → 调用方画白膜，不崩）、卡面肖像为 null（文字卡）。golem 本身就是"orc 贴图放大暂替"先例。
- **内容整合层**：PvE 敌人不出新卡（15 遭遇模板全旧 16 卡）+ 奖励只掉 8 张旧卡碎片——A4 回填项（已在 PLAN_V5_SANGUO）。
- **A2.5 提案（待用户拍板后开工）**：按用户"重复代替+改大小改颜色"思路，sprite_db 铺满 29 条复用映射（按三国复用组配贴图+染色/缩放：山越系=goblin、阴兵系=skelly、魂鸦/机关兽系=fire_skull 染色、青州=knight/orc…），需 sprite_db/绘制侧补 per-unit modulate 支持（小改）；正式素材到位后逐组替换。

**横版战斗立项（用户 2026-07-04 指示"只方案先记着"，未开工）**：战斗加横向版本——我方在左敌方在右、单位左右走，**动机=侧视帧动画素材减半**（一套侧视帧+flip_h 镜像替代现在的 row/row_up 上下两行）；**盘面 18×32、地形、logic 全不变，纯表现层投影**。施工图 [PLAN_V5_HBATTLE.md](PLAN_V5_HBATTLE.md)：
- 像素账完美：竖版 720×1280=40px/格 ↔ 横版 1280×720=40px/格（旋转后密度不变）。
- 变换收敛先例：net_battle side2 的 `_t2s()` 180° 翻转模式 → battle_scene 9 处 `_tile_px()` 手算先收敛成统一 `_t2s/_s2t`（H1 纯重构可先行），再加旋转分支（H2）。
- 步骤 H1 变换层收敛 → H2 横版投影 → H3 精灵侧视约定(row_side+flip_h，三国素材直接按侧视交付) → H4 横版 HUD(mockup 先行) → H5 版式切换+屏幕方向(战斗切横屏、菜单恒竖屏) → H6 net_battle×side2 复合真机验收。
- **硬验收：同一局重放纵/横两版战斗结果+逐 tick hash 完全一致**（logic 零改动的证明）；纵版保留共存。
- 排期建议：A3 之后/A4 同期（让美术直接按"侧视帧"约定画，避免先画上下行再返工）。
- Jira（手工）：新建 Story「横版战斗（表现层）H1~H6」→ **Idea** 挂 KAN-50。

本段涉及文档：新增 PLAN_V5_HBATTLE.md；PLAN_V5_SANGUO.md 加 A2.5/横版关联线注记；PLAN_V5.md/CLAUDE.md 指针更新。**代码零改动。**

### V5 三国改版 · A2.5 占位精灵铺满 48 卡（✅ 代码+单测完成，待真人验收，2026-07-04，未 commit 待用户指示）

**目标**：29 个缺贴图的新单位从"白膜占位"升级为"复用贴图+染色+缩放"的可辨识占位（用户拍板"重复代替、改大小改颜色"），且**替换正式素材要顺手**。

- **`view/sprite_db.gd` 铺满 39/39 单位**（此前 10）：新启用素材包同源贴图 7 张（goblin_slinger/skelly_warrior/orc/orc_soldier/orc_archer/wraith/slime——PNG 头解析确认全部 4列×16px 标准网格，行号按包惯例配、留真人校正，同 V3-7b 流程）+ fire_skull/mage/knight/archer/axe 复用。**条目级新增 `tint`（占位染色）+ `ph`（占位标记）**；染色按阵营色语言（魏蓝/蜀绿/吴红/群雄黄 + 冰蓝/电黄/火橙个体色）。golem/baby_dragon 两条旧"暂替"也补了 tint+ph（吴红系）。
- **便于替换的设计**（用户核心要求）：①每单位独立条目、替换互不影响；②文件头写死"替换三步"（放 PNG→定网格→改条目删 tint/ph）；③`placeholder_ids()` 盘点 API + **单测账本**（`test_placeholder_inventory` 断言占位数=31，每替换一条正式素材递减一并更新断言——刻意的进度账本）；④tint/ph 删掉即回自然色，无残留逻辑。
- **染色链路**：`frame()` 返回值 +`tint`；battle_scene/net_battle_scene 战斗精灵 `fill×tint`（队伍色可读性优先、tint 作次级区分）；卡面/图鉴/卡组槽/名片头像走 `card_portrait_tint()` 自然色染（个体识别主场）——`_draw_card_art`×2 / `make_card_portrait` / deck_builder 槽位 / hud_widgets 头像共 5 处接入。
- **UNIT_VIS 半径表补 29 条**（battle_scene + net_battle_scene 两份同表）：按美术表体型档（极小0.35/小0.4/中0.5/大0.62/巨0.85），血条/投影/入场缩放随体型正确。
- **法术图标 +2**：北地霜石→Ice-Burst_crystal、郭嘉寒江计→Ice-Burst_transparent-blue（48px 帧）；无图法术剩 4 张文字卡（魏武箭阵/剑阁滚木/荀彧安军策/剑阁落石阵，与旧行为一致）。
- **副作用（好的）**：S9 创号头像池从 10 张兵卡扩到 ~39（account_create 按"有肖像"过滤）；山越奇袭坛等召唤类卡自动获得所召单位肖像。
- **验证**：客户端 **357/357**（+4 `test_sprite_db`：全单位有条目 / 全帧 src 在贴图边界内〔顺带验证了估的行号不越界〕/ tint 类型 / 占位盘点=31）。**纯 view 改动，无需重启 docker**（verifier 只 stage logic/config）。
- **真人验收点**：①图鉴 48 卡肖像全有图有色（4 张法术文字卡除外）；②全新卡组进战斗无白膜白圈、颜色可辨；③体型层次（母兽/霹雳车/轰天灯 显著大）；④**行号校正回报**：哪个单位"走路帧像攻击/帧错位"报名字即可（新贴图行号为包惯例估值）；⑤名片/创号头像染色正常。
- **收尾（2026-07-04）**：A1A2+A2.5+横版立项已提交推送（72624b5 / b75c387）；真人验收欠账集中台账 **[docs/ACCEPTANCE_SANGUO.md](docs/ACCEPTANCE_SANGUO.md)**（A 组 4 例 + B 组 5 例 + S8e 老账），Jira 建议口径改为 **In Review**（用户 2026-07-04 指示"验收欠着、单放 In Review"）。

### V5 三国改版 · A3 场景与系统美术清单（✅ 表已产出待评审，2026-07-04，未 commit 待用户指示）

**用户四决策**（已入 PLAN_V5_SANGUO §0 决策 7~10）：①**塔分阵营皮肤**（我方汉军套恒定 + 敌方魏/蜀/吴/群雄四套随章节，P0=我方+黄巾）②**UI 本次小改**：保像素风、中式化配色纹样（大改版后续另立项）③**头像首批 16**（四阵营×4）④**塔损毁=坍缩残骸图**（低矮不挡兵路；现状为程序化"原图压低 42%+染暗"，battle_scene:351——正式图逐套替换）。

**产出 [docs/design/scene_system_art_spec.xlsx](docs/design/scene_system_art_spec.xlsx)**（6 sheet / 69 行，与 48 卡表同风格：目标路径/现资源对照/尺寸规格/优先级/状态列）：
- **塔与战场 14 项**：塔 5 套（我方汉军 P0 / 黄巾 P0 / 魏蜀吴 P1，均 3/4 俯视方向无关构图=横版兼容）+ 坍缩残骸×5 套 + 地形 3 主题（中原 P0 / 山地·江河 P1，对应章节叙事）+ 浮桥（**标注横版两朝向变体强约束**，联动 PLAN_V5_HBATTLE H3 素材约定）+ 装饰物件。
- **战斗 FX 18 项**：状态 FX 统一 5 套（结霜/眩晕/冻结/灼烧[T7 预留]/治疗，全池共用阵营只差符纹——对齐 T3 引擎架构）+ 9 张法术落点表现 + 通用 4（命中/亡语召唤/入场/塔损爆）。
- **UI 系统件 8 项**：品质框 4 档（对照现 RARITY_COL 色值，加中式角饰递进）+ **阵营徽记×4（新增，图鉴筛选/卡面角标/未来羁绊 UI 复用）** + 货币 3（五铢钱/玉璧/虎符碎片）+ 按钮 3 套×3 态与面板 2（同尺寸同 9-slice 结构中式重绘，PixelUI 框架不动）+ menu_bg + 章节节点；**表内显式记录"UI 大改版=后续另立项"**。
- **头像 16**：四阵营×4（魏：虎贲校尉/典韦/司马懿/荀彧；蜀：黄忠/周仓/庞统/无当火油手；吴：周瑜/孙尚香/黄盖/山越旋刃卫；群雄：张角/于吉/左慈/黄巾力士），128×128 方形大头。
- **音频方向 6**：BGM×3+胜负 stinger+SFX 换皮方向，落地走既有 AudioConfig.xlsx→audio_assets.json 管线。
- **资产盘点结论**（建表前核实）：塔现用 building1(王)/building6(公主)、库存 2-5/7-8；UI 皮=12 张（按钮 3×3+面板 2+menu_bg）；地形=Lonesome_Forest 系 tileset；Boss vampire_lord 全套为奇幻遗产（三国 Boss 素材列"储备"，随 A4/后续）。
- **验收**：属文档评审（用户+美术过表：项齐/规格对/优先级认），已挂 [ACCEPTANCE_SANGUO.md](ACCEPTANCE_SANGUO.md) 台账第 4 条，Jira 建议 三国化-A3 → In Review。**代码/config 零改动**（部署区高亮等 3 项标注"保持程序化、无需素材"）。

### V5 三国改版 · 验收首轮反馈 + 组卡/创号滚动交互修复（🐞→✅ 代码+测试完成，2026-07-04，未 commit 待用户指示）

**用户验收首轮回报**：组卡界面卡名/肖像正常（"能看到的都配上图了"）、对战可打无问题（A-3 ✅ / B-2 大体 ✅）；**阻塞 bug：卡池无法滚动**——deck_builder 是 V3 时代按 16 卡设计的**纯绝对布局、无滚动容器**，48 卡铺到 y≈1624 远超 720×1280 视口，且底部 返回/保存 按钮悬浮压在卡上。用户要求做"手指/鼠标按住上下拖动"的滑动交互。

**波及排查**：`account_create`（S9 创号选头像）**同类问题**——A2.5 让头像池 10→39（按"有肖像的兵卡"过滤），网格铺到 y≈2046、确认按钮(1150)被埋。`card_collection`/`stage_map` 已用 ScrollContainer 不受影响（但桌面只能滚轮、不能鼠标拖动）。

**修复（对齐既有 ScrollContainer 模式 + 一个全局输入开关）**：
- `view/deck_builder.gd`：卡池区 → ScrollContainer(28,428,664×548，到底部按钮上方)，瓦片/肖像/名费标签/选中金边全进内容层（局部坐标，`_pin_label` 加可选 parent 参数）；**滚条隐藏**（SHOW_NEVER——不占列宽、拖动/滚轮仍可滚）；`scroll_deadzone=16`（阈值内=点选卡、超出=滚动，手势不打架）。按钮不再与卡重叠。
- `view/account_create.gd`：头像网格 → 同款 ScrollContainer(28,538,664×564)。
- `project.godot` +`input_devices/pointing/emulate_touch_from_mouse=true`：鼠标产生触摸事件 → **ScrollContainer 的"按住拖动"在桌面鼠标下生效**（真机触摸本就原生支持，此开关让桌面与手机手感一致）；副作用为正——图鉴/闯关地图两处旧 ScrollContainer 顺带获得鼠标拖动，三处滚动界面手感统一。战斗拖拽部署走鼠标事件不受影响（安卓 touch→mouse 默认模拟本就在用），仍列专项回归用例兜底。
- **验证**：headless 编辑器解析 0 错误；客户端全量 **357/357** 零回归。**纯 view/工程设置改动，无需重启 docker。**
- **验收用例 C 组 ×5** 追加进 [docs/ACCEPTANCE_SANGUO.md](docs/ACCEPTANCE_SANGUO.md)：C-1 卡池拖动滚动到底 / C-2 点选 vs 拖动不误触 / C-3 创号头像滚动 / C-4 图鉴·闯关地图拖动顺带受益 / **C-5 ★战斗拖拽部署回归**（全局输入开关的专项兜底，PvE+联机各一局）。

**🔁 二次修（同日）：emulate_touch_from_mouse 路线失败 → 自写 DragScroll 层**。用户复测：滚轮可滚、**鼠标按住拖动仍不行**（按下被子按钮捕获，drag 事件到不了 ScrollContainer，引擎触摸模拟在桌面不可靠）。改法：
- **撤销** project.godot 的 `emulate_touch_from_mouse`（顺带消掉 C-5 担心的战斗输入面）。
- 新增 **`view/ui/drag_scroll.gd`**（通用组件）：挂 ScrollContainer 子节点，`Node._input` 前置拦截**真实鼠标**事件——按在滚动区=本层代管；位移≤14px 松手=轻点 → 命中测试内容里最上层 BaseButton 派发 `pressed`（语义点击）；超阈值=拖动 → 直改 `scroll_vertical` 并吞事件（按钮不误触不残留按压态）。**触摸模拟出的鼠标事件（DEVICE_ID_EMULATION）跳过** → 真机触摸走 ScrollContainer 原生拖动，不双重滚动；滚轮不拦截。
- **四界面统一接入**：deck_builder（卡池）/ account_create（头像）/ card_collection（图鉴）/ stage_map（闯关列表），各一行 `DragScroll.attach(scroll)`。
- 验证：headless 解析 0 错误、客户端 357/357。C-5 降级为"抽查一局部署正常"（战斗输入已零改动）。

### V5 三国改版 · 首批 BGM 入库（菜单 + 战斗，✅ 完成待真人试听，2026-07-04，未 commit 待用户指示）

**背景**：`sound/` 目录自音频骨架(V3-8)以来一直是"清单先行、文件空缺"（AudioManager 静默跳过），游戏从无 BGM。用户要求配菜单+战斗各一套。

- **选曲（均 OpenGameArt **CC0 公共领域**，可商用免署名——商业 F2P 无授权尾债）**：
  - `music_main_menu` ← **Oriental**（Shadowfire452）：宁静东方古韵（菜单/城镇向），WAV 原格式入库（~22s 循环）。
  - `music_battle_normal` ← **Ninja Theme**（Spring Spring）：古筝/笛+合成器动作节奏（社区评"双截龙3味"，正对热血物语气质），OGG 入库。PvE 与 PvP 战斗同用此键（PvE boss 变体键仍 planned）。
  - 曾试 Taiko drums loop（更贴战鼓）但为 **CC-BY 3.0** 需署名 → 弃用，不背署名维护义务。
- **接入**：文件放 `sound/bgm/`（headless 导入 ok）；`config/audio_assets.json` 两条 → `asset_status=imported` + 菜单 path 改 `.wav` + effect_notes 三国化 + **source_notes 记来源与许可**；`build_audio_config.py --from-json` + `--check` 往返一致（xlsx 镜像同步）。
- **🐞 顺手修 AudioManager loop 缺口**：清单里 `loop:true` 从未落到资源（导入默认不循环，曲子播一遍就静音）——`_load_stream` 按清单给 OggVorbis/MP3 设 `loop`、WAV 设 `LOOP_FORWARD + loop_end(按格式算帧数)`。
- **新增 `tests/test_audio_assets.gd`**：asset_status=imported/final 的条目文件必须存在且可加载为 AudioStream（防"清单说有、盘上没有"漂移；planned 仍允许缺文件）。客户端 **358/358**（+1）。
- **踩坑记录**：uv `run soundfile` 转码 WAV→OGG 在 Windows 原生崩（libsndfile vorbis 写崩、退出码 127 误导以为 uv 坏）→ 放弃转码、WAV 直用（3.9MB 占位可接受，正式定制曲时按 A3 音频方向替换）。
- **验收（并入台账 D 组）**：菜单东方古韵循环播放、界面间切换不重头；进战斗切动作曲、退出回菜单曲；音量 -9/-10dB 预设不压音效。

### V5 横版战斗 · H1 变换层收敛 + H2 横版投影与实验开关（✅ 代码+单测完成，待真人验收，2026-07-05）

**背景**：用户拍板开工 [PLAN_V5_HBATTLE.md](PLAN_V5_HBATTLE.md)「最小可看里程碑」= H1+H2+设置页临时实验开关（PvE 先行）。动机=三国侧视帧素材减半（排在 A3 表发美术前把"侧视帧"约定跑通）。**logic/ 与 config/ 零改动、服务端零改动、docker 零操作**（纯 view+工程层）。

**H1 · 变换层收敛（纯重构，竖版逐像素不变）**：
- 实盘 `view/battle_scene.gd` 方向性手算 **14 处**（施工图预估 9 处，另抓出：塔 footprint 换算×2、塔箭口/塔伤害数字锚点（逻辑坐标里的"屏幕向上"偏移）、部署区矩形×2、教程 field 高亮矩形）。
- 收敛进「坐标映射」区块：`_t2s/_s2t/_tile_px` 保持 + 新增 **5 个语义 API**——`_ur()`（单位参考半径=格边均值，投影不变量）/`_tile_rect(tx,ty)`（terrain 瓦片屏幕矩形）/`_fp_screen(fw,fh)`（建筑 footprint→屏幕尺寸）/`_screen_up_tiles(n)`（"屏幕向上 n 格"的逻辑位移）/`_deploy_zone_rect(a)`（己方可部署半场屏幕矩形）。区块外不再有任何方向假设；每处替换均代数恒等。
- **屏幕语义元素刻意不动**（两版天然通用）：飞行影子/上浮、血条、伤害数字上浮、箭雨/治疗 FX、投射物箭头方向（从屏幕坐标算）、拖拽落点抬升（屏幕空间抬完再 `_s2t`）。HUD/卡面/结算/名片仍属 H4。

**H2 · 横版投影 + 实验开关**：
- 变换层 8 函数加 `_landscape` 分支（施工图 §2 公式：敌右我左，sx←(grid_h−y)、sy←x；`_tile_rect` 角点取 (tx,ty+1)、`_fp_screen` 交换、`_screen_up_tiles`=逻辑−x、部署区=屏幕左段）——**横版全部改动收在坐标映射区块内**，绘制/输入代码零感知。
- **临时投影区（H5 前）**：竖屏 720×1280 窗口的场区（顶栏~HUD 间 720×1050）内按 32:18 满宽 letterbox 垂直居中 → 场地 720×405、**22.5px/格**（画面偏小属预期，H5 切横屏窗口后回 40px/格）；上下空带留白。
- **开关与持久化**：`view/game_state.gd` +`battle_layout()/set_battle_layout()`（`user://settings.cfg` [battle] layout，对齐 I18n 范式；**纯表现层偏好，不违决策 48**）。设置页「战斗版式（实验·仅 PvE）」竖版/横版两按钮（y=250~400 空隙，样式对齐语言区；文案硬编码中文对齐 GM 区先例，H5 正式化再进 i18n——**config 零改动=免 docker 重启**）。
- **门控**：战役+新手引导强制竖版（教程 field 高亮是竖版语义；新手不吃实验特性）；联机 net_battle 不接（H6）。battle_scene `_ready` 打 `[V5][battle] 版式=` 日志。
- **重放一致性背书**：logic 零改动 + 366 单测（含 lockstep determinism）+ 横版闯关局走 KAN-79 服务器重放校验（正常结算发奖=view 未污染 sim 的实证）。
- **新增 `tests/test_hbattle_transform.gd`（+8）**：竖版基准锁定（720×1280/18×32 下 `_t2s(9,16)=(360,579)`、tile=(40,32.8125) 等硬编码期望——H1"逐像素不变"的自动化背书）/ 横版投影方向语义（敌底线→右缘、场心映场心、22.5 方格、letterbox=(0,376.5,720,405)）/ 双版 `_t2s↔_s2t` 互逆 / `_fp_screen/_screen_up_tiles/_deploy_zone_rect` 方向翻转。battle_scene 用 `new()` 裸实例测（不进树→`_ready`/@onready 不触发，无音频/网络副作用）。
- **踩坑**：`var pve_free := (campaign == null or ...)` 触发 Parse Error（`campaign` 无类型注解，`or` 表达式推不出类型）→ 显式 `: bool`。教训：对无类型成员做布尔组合再 `:=` 会编译失败，headless 单测能立刻暴露。
- **验证**：客户端全量 **366/366**（358 基线零回归 +8 新增）；headless editor 过导入无新告警。
- **真人验收**：台账 [docs/ACCEPTANCE_SANGUO.md](docs/ACCEPTANCE_SANGUO.md) **E 组 5 例**（竖版回归/横版开关/横版完整一局/门控/开关持久化）。Jira（手工）：新建 Story「横版战斗（表现层）H1~H6」→ **In Review**（原建议 Idea，现 H1+H2 已实做）。
- **验收首轮回报（2026-07-05）**：**E-2/E-3 ✅**（用户：横版人工验收通过——拖卡部署跟手、部署高亮在左半场、正常结算发奖）；E-1/E-4/E-5 仍欠。

### V5 · 🐞 发奖弹窗「继续」按钮失灵 → DragScroll 遮挡判定修复（✅ 修复+单测过，2026-07-05）

**用户回报**（横版验收时发现，实为 DragScroll 引入的回归、与横版无关）：闯关发奖开箱弹窗点【继续】无反应、控制台无报错；点屏幕其它地方"反而能退出"。
- **根因**：`view/ui/drag_scroll.gd`（2026-07-04 滚动交互修复引入）按下时只判"落点在 ScrollContainer 矩形内"就代管并吞事件，**不知道上面盖了弹窗**——reward_chest 是 stage_map 根下的全屏层（PRESET_FULL_RECT + STOP），其【继续】按钮 (240,880) 正落在闯关列表滚动区矩形内 → press 被吞、按钮收不到点击、无报错。
- **更隐蔽的第二刀**：轻点派发 `_hit_button` 只搜滚动子树 → 命中**弹窗底下被遮住的关卡按钮**直接 `pressed.emit()` = **穿透误触**（用户看到的"点别处能退出"其实是误触关卡按钮切了场景，不是正常退出）。
- **修复**（一处通用，组卡/创号/图鉴/闯关四界面同享）：press 代管前加 `_covered()` 判定——`get_viewport().gui_get_hovered_control()` 取鼠标下最顶层 Control，不属于本 ScrollContainer 子树（含自身）= 滚动区被盖 → 不代管、点击走正常 GUI 路径（弹窗按钮恢复、穿透同时堵死）。触摸路径不受影响（DEVICE_ID_EMULATION 事件本就跳过）。
- **验证**：客户端全量 **366/366** 零回归。真人回归 = 台账 **C-6**（发奖弹窗按钮 + 不再穿透）——**2026-07-05 真人验收通过**，与横版 H1H2 一并提交（69bfe6a + 82fdc44 已推 master）。

### V5 · UI 体系全面盘查 + 改造立项（KAN-97/98）+ Jira 看板补账 KAN-90~98（📋 方案已拍板待开工，2026-07-05）

**背景**：用户在 DragScroll 穿透修复后指出"整个游戏 UI 层级经常错误穿透（半透明界面能点到下层按钮）"，要求全面盘查客户端 UI 框架能否支撑未来各类 UI（全屏/页签/提示框/弹窗/跳字/半透明）。

**盘查（view/ 17 场景/组件全过，结论落 [PLAN_V5_UIFRAME.md](PLAN_V5_UIFRAME.md) §0 现状地图）**：
- **结论：只有样式库（PixelUI）没有层级骨架**——全项目 0 CanvasLayer、无统一弹窗/toast 通道、弹窗写法三家三样（chest 手搓 STOP / run `_dim` / 结算层 STOP+延迟按钮）、三套输入系统并行互不知晓（GUI mouse_filter / DragScroll 前置 `_input` / 场景手搓坐标判断）。穿透是结构性的。
- **新实锤 🔴 KAN-98**：net_battle 结算暗幕拦不住手牌——`_end_result_layer` 建于 `_ready`、手牌按钮建于进房后 `_build_cards`，**Godot Control 输入命中按树序（后加者先命中，与 z_index 无关）**→ 结算演出期点卡牌区被卡按钮吃掉。单机 battle_scene 无此问题（建层顺序恰好相反）。"视觉在上≠点击在上"陷阱的实证。
- 无害面确认：4×toast 全 Label IGNORE ✓；run_scene `_dim`（ColorRect STOP）是做对了的先例 ✓；匹配中界面无遮罩但底下无可点物 ✓；战斗伤害数字 `_draw` 派生 ✓。

**改造方案（用户 2026-07-05 拍板"就按这个来做"，施工图 PLAN_V5_UIFRAME.md）**：F1 层级骨架（`UI` autoload CanvasLayer 栈 MODAL=50<TOAST=90 + Modal 基类 + UI.modal/toast 入口 + DragScroll 双保险 + 顺带根治 KAN-98）→ F2 存量迁移（chest/run 弹层/4×toast/教程暗幕）→ F3 规约固化（新 UI 必须声明层级、禁树序当层级、z_index 不拦输入——写进 CLAUDE.md + pixel_ui.gd 头）。**待用户指示开工**。

**F1 · UI 层级骨架落地（✅ 代码+单测完成，2026-07-05 用户拍板即刻开工，待真人验收 F 组）**：
- **`view/ui/ui_layers.gd`（autoload `UI`，第 3 个业务 autoload）**：CanvasLayer 栈 MODAL=50 < TOAST=90；`UI.modal(node)` 推弹窗（绑定当前场景 tree_exiting → 场景切换自动清，防跨场景残留）+ `UI.modal_open()`（过滤待删）+ `UI.toast(msg)`（统一 1s 停留 0.5s 淡出，F2 替换 4 处复制粘贴用）。project.godot 注册。
- **`view/ui/modal.gd` 弹窗基类**：全屏锚 + 根 STOP 兜底（真正隔离由 CanvasLayer 层级保证）+ 可配暗幕（`dim_alpha`，0=无）+ `closed` 信号 + `_on_bg_click()`（默认按 `close_on_bg_click`，子类可覆写做跳过动画）；子类覆写 `_build()` 搭内容、勿覆写 `_ready`。
- **battle/net_battle 结算层迁入 MODAL**：`_result_layer/_end_result_layer` 改 Modal（`dim_alpha=0`，演出黑幕仍由 `_draw_end_screen` 渐入），`_start_ending` 时 `UI.modal()` 推入——**KAN-98 根治**（原 net_battle 结算层建于 `_ready`、手牌按钮建于进房后，Control 输入按树序命中 → 按钮压层拦不住；弹窗层恒高于场景层，与建立顺序无关）。战斗中途离场时 `_exit_tree` 兜底释放未入树的结算层。顺手修隐患：battle 教程 `_input` 加 `_ending` 早退（防教程未走完的局吞掉结算按钮点击）。
- **DragScroll 双保险**：`_covered()` 先查 `UI.modal_open()`（本层是 `Node._input` 前置拦截，CanvasLayer 挡不住它，必须自觉让路）再走原 hovered 遮挡判定。
- **踩坑（runner 架构现实，记档）**：test_runner 在 `SceneTree._initialize` 跑 = **离线树**——`_ready` 不触发、`push_input`/绝对路径 get_node/`get_viewport()` 全不可用（autoload 也晚于测试加载，game_helper 日志在汇总后打印可证）。应对：①Modal 装配改**幂等 `_assemble()` 双入口**（`_ready` + `UI.modal` 显式调）；②DragScroll 找 UI 改 `Engine.get_main_loop().root` 相对路径 + `get_viewport()` null 守卫；③"modal 拦点击"的行为级测试降级为**结构断言**（宿主层=50/根 STOP/全屏锚——GUI 按 CanvasLayer 从高到低分发是引擎行为，不替引擎测），行为验证走真人 F 组。
- **验证**：`tests/test_ui_layers.gd` +6（层值序/推入开闭/closed 信号/暗幕装配/隔离结构/DragScroll 让路/toast），全量 **372/372**；headless 实跑主场景冒烟无错（autoload 加载正常）；editor 过导入无告警。**纯 view+project.godot，docker 零操作。**
- **真人验收**：台账 F 组 4 例（单机结算回归 / ★联机结算演出期点手牌无反应=KAN-98 验证 / 发奖弹窗回归 / 中途退出抽查）。Jira：KAN-98 → In Review；KAN-97 保持 正在进行（F2 存量迁移/F3 规约固化未做）。

**F2 · 存量覆盖层迁移（✅ 代码+单测完成，2026-07-05，待真人验收 F-5~F-8）**：
- **reward_chest → Modal 子类**：删自有 `signal closed`/锚/STOP（基类管）；暗幕保留自绘（`_init` 置 `dim_alpha=0`——基类 ColorRect 是子节点会盖住自身 `_draw` 的宝箱演出，故暗幕必须留在 `_draw` 垫底）；`_gui_input` 跳过逻辑 → 覆写 `_on_bg_click()`；`_close` 走基类 `close()`。stage_map `add_child(chest)` → `UI.modal(chest)`（与 DragScroll 的滚动区彻底分层，KAN-96 类穿透机制上绝迹）。
- **run_scene 奖励/结算覆盖层 → Modal**：原「场景内 `_overlay` 容器 + `_dim()` ColorRect STOP」树序压层模式 → `_refresh_overlay` 按 mode 建 Modal 实例（基类 0.72 暗幕）推 `UI.modal`、mode=none 时 queue_free；`_dim()` 删除、`_overlay = _layer()` 删除。奖励三选一/跳过/结算回菜单回调零改动（内容仍挂 `_overlay` 变量，类型换成 Modal）。
- **4×toast → `UI.toast` 一行转发壳**（base_camp/card_detail/account_create/deck_builder）：14 行×4 的复制粘贴体消灭，场景级默认参数保留（card_detail 错误红 y=760 / account_create 停 1.4s / deck_builder y=920）；`UI.toast` +`hold` 停留参数；deck_builder 字号 22→24 统一（顺带）。toast 现落 TOAST 层（90）恒不挡手。
- **battle 教程覆盖补输入实体**：新 `_tut_layer`（Modal，dim=0，视觉仍由 `_draw_tutorial` 在场景层画）——**tap 步 STOP 吞点击防误出牌 / action 步（card_played）IGNORE 放行出牌**，每步 `_tut_sync_layer()` 切换；教程走完或进结算自动撤层；**删前置 `_input` 手搓吞点击**（三套并行输入系统再消一套）。Modal +`bg_click_cb`（免建子类的点空白回调，教程 tap 推进用）。
- **验证**：`test_ui_layers` +2（bg_click_cb / chest 迁移形态：继承+dim0+按钮装配+点空白跳过≠关闭），全量 **374/374**；一次性脚本扫 view/+view/ui 全部 .gd 可编译实例化（8 个被触碰场景无一被单测 preload，防漏）；headless 实跑主场景冒烟零错误。docker 零操作。
- **真人验收**：F 组追加 F-5 开箱全流程 / F-6 肉鸽弹层 / F-7 新手教程回归★ / F-8 四处 toast 抽查。

**F3 · 规约固化（✅ 2026-07-05，随 F2 同批提交）**：四条 UI 层级规约入 **CLAUDE.md 架构铁律区**（第 4 条铁律「UI 层级走骨架，不走树序」）+ **pixel_ui.gd 文件头**（样式库入口处提醒）：①覆盖类 UI 一律继承 modal.gd 经 `UI.modal()` 推入 ②提示/跳字走 `UI.toast()` ③z_index 只管绘制不管点击、挡输入必配 mouse_filter ④前置 `Node._input` 拦截器必须查 `UI.modal_open()` 让路。至此 **KAN-97 F1~F3 代码/文档全部完成**，剩 F 组 8 例真人验收（过后 KAN-97/98 → Done）。

**Jira 看板补账（Atlassian MCP 本会话已授权，全部代建）**：
- 新建 **KAN-90** 三国化-A1A2（Story，In Review）/ **KAN-91** A2.5 占位精灵（Task，In Review）/ **KAN-92** A3 美术清单（Task，In Review）/ **KAN-93** A4 素材+文本+回填（Story，待办）/ **KAN-94** 横版战斗 H1~H6（Story，In Review，H1H2 已完成）/ **KAN-95** 首批 BGM（Task，In Review）/ **KAN-96** DragScroll 滚动+穿透修复（Bug，In Review）/ **KAN-97** UI 体系改造 F1~F3（Task，待办）/ **KAN-98** net_battle 结算层树序 bug（Bug，待办，随 F1 修）——全部挂 Epic KAN-50。
- **KAN-88** 描述追加三国化 A1 降级的 5 项增强觉醒升级项（左慈领队溅射/司马懿冻结/孙尚香燃烧地带/庞统落地减速/于吉范围眩晕）；**KAN-87** 加挂起备注（轨道A 后复盘，CV 离群结论保留）。
- PLAN_V5_SANGUO §4 手工清单就此结清；此后 Jira 恢复由我经 MCP 维护（用户 2026-07-05 授权开启）。

---

### V5 · 框架地基#1 SceneRouter 场景路由（KAN-99，✅ 代码+单测完成待真人验收，2026-07-06）

**背景（开源框架调研，同日完成）**：用户担忧 vibe coding 从零长出来的工程缺框架性骨架 → 调研社区公认 Godot 框架/实践（Maaack's Game Template / crystal-bit GGT / TakinGodotTemplate / GDQuest 事件总线·FSM 模式 / godot-statecharts / gdUnit4·GUT / Loggie / gdtoolkit / netfox·Snopek rollback）。结论：**Godot 无大一统手游框架，社区上乘 = 外壳模板 + 领域积木 + 架构模式**；我们的强项（确定性战斗 sim / Go 权威 lockstep / 服务器权威经济、Excel↔JSON↔服务器配置管线）无现成替代、不动；比对出**四缺口：①场景路由 ②事件总线 ③日志 ④lint 工具链**，用户拍板逐个补（UI 体系改造 KAN-97 已完成翻篇，不在缺口内）。

**#1 SceneRouter 落地（抄 crystal-bit GGT 集中式场景管理模式）**：
- **`view/scene_router.gd`（autoload `Router`，第 4 个业务 autoload）**：ROUTES 路由表集中登记 13 个可达场景（main_menu/battle/net_battle/run/stage_map/level_select/campaign/deck_builder/card_collection/card_detail/base_camp/settings/account_create——收编原先 11 个文件各自重复定义的 `const *_SCENE` 路径常量）；`Router.goto(route, params={})` 唯一切场景入口（fire-and-forget 协程）：黑幕 0.15s 淡出 → `change_scene_to_file` → 等 2 帧新场景挂树 → 0.15s 淡入；转场幕布 CanvasLayer=**100**（恒压 MODAL 50 / TOAST 90），转场期 `mouse_filter=STOP` 挡输入（防连点），静止时 IGNORE+全透明不挡手；`Router.reload()` 重载当前路由（params 保留；编辑器 F6 直启场景无路由历史时退引擎 `reload_current_scene` 兜底）；params 深拷贝隔离 + `Router.param(key, def)` 读——为后续 GameState 静态握手参数化铺路（**本步存量握手一律不动**，KAN-99「不做」，风险最小化）。
- **收编 43 处调用（15 个 view 文件）**：main_menu(8) / battle_scene(7，含 rematch reload) / deck_builder(7) / settings(3，含换语言/换版式 reload×2) / net_battle_scene(3，含再来一局 reload) / run_scene(3) / base_camp(2，顺带删 stage_map 未建时代的 `_go` 兜底死代码) / stage_map(2) / card_collection(2) / campaign_scene(2) / level_select(2) / card_detail(1) / account_create(1)。引擎切场景 API 直调清零（唯一豁免 = Router 本体）。
- **新规约固化**：CLAUDE.md 架构铁律第 5 条「场景切换走 Router，不散装」+ ui_layers.gd 头层级图补 100 层。加新场景须先登记 ROUTES（view/ 根 tscn 全登记有单测校验）。
- **验证**：`tests/test_scene_router.gd` +7（路由表路径存在 / view 根 tscn 全登记 / resolve 纯函数 / params 往返+深拷贝隔离 / 幕布层结构（=100>TOAST、静止 IGNORE）/ **规约扫描**（view/net/ai 全量禁直调引擎切场景 API）/ **view+view/ui 全量脚本编译扫描**（load+can_instantiate，防收编常量后残留引用——对齐 runner 的 logic 预检思想）），全量 **381/381**；headless editor 过导入干净。goto/reload 换场行为需活树+渲染，headless 测不了 → 真人验收。纯客户端改动，docker/服务端零操作。
- **踩坑修复（真人首验即中，2026-07-06）**：创号→回主菜单→自动进新手引导战**卡死在「登录中…」**——主菜单 `_ready` 登录路由的重定向 `goto(battle)` 落在上一段转场（menu 淡入）收尾窗口内，被 busy 防连点保护**误丢**（日志 `转场进行中，忽略 goto(battle)` 实锤）。修复 = busy 期到达的 goto 改**暂存接力**（`_pending` 只留最后一个；转场收尾若有暂存 → 幕布保持黑、跳过淡入直接链去终点，不闪屏）+ `_fade_to` 已在目标态短路（接力链免空等）。凡「场景一进来就自动重定向」的流（登录路由/闯关报到失败弹回）全被此修保护。+1 单测（busy 暂存/后到覆盖先到），全量 **382/382**。
- **踩坑修复②（真人验收再中一发 P0，2026-07-06）**：新手引导提示窗点不动、下层手牌却照常可拖出兵。headless 实跑探针实锤根因：**Modal 根/暗幕/转场幕布的实际矩形 = 0×0**——F1 起用的 `set_anchors_preset(FULL_RECT)` 只改锚点且默认**保留当前矩形**（新建节点 0×0 → 永远 0×0），真铺满必须 `set_anchors_and_offsets_preset`。零面积 = 接不到点击也挡不住输入 → **F1 以来所有弹窗层「输入隔离」从未真正生效**（F 组真人验收一直欠着故未暴露：结算拦手牌/chest 点空白跳过/run 弹层暗幕其实全线失效；锚点断言单测全绿 = 假阴性）。修复：① modal 根+暗幕、Router 幕布换 and_offsets 版（探针复跑 rect 0×0→**720×1280** ✓）；② 全 view 13 处裸调用清零（7 处 bg 贴图恰 720×1280、迁移零视觉差；2 容器本就 IGNORE 无输入副作用）；③ **源码封禁**：view 层禁裸 `set_anchors_preset(`（test_scene_router 扫描）+ 真树实际矩形断言（offline 无视口自动跳过）+ pixel_ui.gd 规约头补第 5 条；④ UI.modal 推入/自动清理/收到点击 三处永久日志。全量 **384/384**。**教训**：结构断言（锚点/filter）测不出几何失效——涉输入遮挡的 UI 必须「真树实际矩形」级验证 + 真人验收兜底，欠着的 F 组验收正是本 bug 存活至今的原因。
- **验收尾修③（2026-07-06，真人过主流程后）**：日志两次「Lambda capture at index 0 was freed」（转场链上触发）——UI.modal 的场景退出自动清 lambda **捕获弹窗对象本身**：弹窗先于场景正常关闭（教程撤层/开箱看完关掉）后场景再退出，one-shot 兜底被唤起时捕获已死 → 引擎报错（有 is_instance_valid 守卫、行为无恙，纯噪声）。修 = 捕获 `instance_id` + `instance_from_id` 查活（ID 永不复用，查无此人安静跳过），lambda 零对象捕获。384/384。
- **真人验收用例（KAN-99）**：R-0 GM 重置账号→创号→**应自动进新手引导战**（本次踩坑的回归验证★）；R-1 主菜单六入口各进一次+返回（观察 0.3s 黑幕转场顺滑）；R-2 闯关全链 基地→地图→组卡→开战→战后回地图开箱；R-3 设置页换语言+换战斗版式（reload 重建正常、语言即时生效）；R-4 单机战斗「再来一局」（=Router.reload 保留模式重开）；R-5 天梯 组卡→匹配→对局→结算回菜单+「再来一局」；R-6 探险肉鸽/新手引导（GM 重置后）各过一遍；R-7 转场中快速连点乱按（应被黑幕挡住、无双跳/穿透）。
- Jira：**KAN-99** 建单挂 Epic KAN-50 → 正在进行 → 代码+单测完成转 **In Review**（验收过再 Done）。缺口 #2 事件总线 / #3 日志 / #4 lint 后续逐单立项。

---

### V5 · 框架地基#2 Events 事件总线（KAN-100，✅ 代码+单测完成待真人验收，2026-07-06）

**做了什么（GDQuest Events 单例模式）**：
- **`view/events.gd`（autoload `Events`）**：首个信号 `economy_changed(cache)`——经济/养成服务器快照更新广播。加新信号原则 = 有真实消费方才加（YAGNI）。
- **发射端收口**：`EconomyStateCache` 快照落地归一到 `_apply`（顺带消掉 refresh 里的重复代码）+ `seed_from_local`，两处尾调 `_emit_changed()`——refresh/领挂机/升级/升阶/解锁/通关发奖/GM 全部自动广播。本类是 RefCounted，经 main_loop root 动态查找总线并判空（offline 单测树/极早期启动安静跳过，对齐 DragScroll 找 UI 方案）。
- **订阅端改造（只接真有页内经济动作的三页）**：base_camp（领挂机）/ card_detail（升级/升阶/解锁）/ settings（GM 8 按钮）——`_ready` 订阅一次，动作 handler 里的手动重刷全删（「加新动作忘刷新」类 bug 机制上绝迹）。**刻意不接** stage_map/card_collection：无页内经济动作，且「缓存已加载不重拉」的入场路径必须保留显式 populate，强行订阅只会双重刷新（YAGNI 实证）。
- **边界铁律**：logic/ 战斗逻辑层禁用总线（lockstep 确定性要求调用顺序严格固定）——`test_events` 源码扫描（`\bEvents\.`）把关；入 CLAUDE.md 架构铁律第 6 条。
- **验证**：`tests/test_events.gd` +5（信号契约 / seed 广播 / _apply 广播（服务器快照 shape fixture）/ 无总线安全 / logic 封禁扫描），全量 **389/389**；headless 冒烟干净。纯客户端，docker 零操作。
- **踩坑（记档纠偏）**：--script 单测模式下 **autoload 其实已挂 root**（F1 时期笔记「autoload 晚于测试加载」不准确——晚的是 _ready 级处理，不是节点挂载）。测试再 add_child 同名节点会被引擎自动改名 → 发射端查到真 autoload、订阅连在孤儿节点上收不到（探针二分实锤）。正解 = get-or-create 复用真 autoload（对齐 test_ui_layers._ui 先例）+ 测完 disconnect；「无总线」用例用临时改名藏 autoload 模拟缺席。
- **真人验收用例（KAN-100）**：E-1 基地领挂机 → 钱包/挂机额即时刷新；E-2 卡详情升级/升阶/解锁 → 数值/按钮态即时刷新（金币扣减可见）；E-3 设置页 GM 任按一个 → 状态行即时更新；E-4 回归：闯关开箱/图鉴排序切换行为不变（未接总线页面）。
- Jira：**KAN-100** 建单挂 Epic KAN-50 → 正在进行 → 代码+单测完成转 **In Review**。缺口 #3 日志 / #4 lint 待做。
