# HISTORY.md — 开发历史与进度记录

> **本文件用途**：给任何接手的人/agent（新开对话也一样）一个**准确、自足**的项目进度与历史。
> 阅读顺序：[PLAN_GRAND.md](PLAN_GRAND.md)（roadmap）→ [PLAN_V5.md](PLAN_V5.md)（**当前阶段权威规划**）+ [PLAN_V4.md](docs/PLAN_V4.md)（V4 联网线参考）→ [CLAUDE.md](CLAUDE.md)（操作手册）→ 本文件（进度总览 + 决策日志 + 当前阶段逐步）。
> **完成阶段的详细逐步历史已归档**：V1/V2 → [docs/HISTORY_ARCHIVE.md](docs/HISTORY_ARCHIVE.md)；V3 → [docs/HISTORY_V3_DETAILED.md](docs/HISTORY_V3_DETAILED.md)；V4 → [docs/HISTORY_V4_DETAILED.md](docs/HISTORY_V4_DETAILED.md)；V5 已收官子步 → [docs/HISTORY_V5_DETAILED.md](docs/HISTORY_V5_DETAILED.md)。本文件只保留**进度总览 + 决策日志 + 当前阶段**。已完成阶段的 PLAN（V1/V2/V3）也已归档到 `docs/`。
> **维护约定**：每完成一步（或重要决策/踩坑）在此追加（当前阶段直接写本文件；已收官版本线/子步的详细段搬去对应 docs/ 归档），随该步 commit。

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

46. **V4 = 联网升级 + 实时对战（玩法验证导向）**：用户判断 V3 单机已收尾，要为 PvP/匹配/赛季/排行榜搭服务端基础。锁定：①**战斗权威 = lockstep + 状态哈希校验**（沿用现有 `logic/` 10Hz 确定性 tick，不重写 Go 战斗逻辑）；②**服务端语言 = Go**（高并发 WS、tick 循环、protobuf 一流）；③**网络协议 = WebSocket + protobuf**（移动友好、二进制紧凑；不用 UDP）；④**数据库 = PostgreSQL + Redis**（PG 主存账号/档案/战绩；Redis ZSET 匹配队列+榜单+对局缓存+限流）；⑤**认证 = JWT + refresh token**，前期**匿名 device_id 登录**（无 SMS/邮箱/三方）；⑥**商业模式长期 F2P + 内购解锁/养成**（schema 预留 `purchases`/`unlocks`/`currency` 字段，但**前期完全不实现支付/IAP/养成**）；⑦**部署 = 本地 docker compose**，不上云、不做合规、不做监控告警；⑧**V3 Roguelite + 短战役保留为单人训练营**，不动；PvP 走全新主轴入口；⑨**仓库结构 = 单仓 `/server` 子目录（Go）+ `/proto` 共享 schema**；⑩**客户端平台 = Android + Windows**（iOS/Mac/Linux 不做）。**反作弊深度**：基础 JWT + 状态哈希 + 速率限制；异常检测/封禁推后到 S7。**新增 DO-NOT**：客户端禁止权威化战斗状态——所有指令走服务端转发、状态以双方+服务端三方 hash 对帐为准。**阶段划分**：S0~S5 玩法验证（脚手架/匿名登录/档案云存/lockstep 对战/匹配/赛季+榜）；S6~S12 产品化（战绩回放/反作弊深化/部署/版本/IAP/正式登录/合规/聊天好友）推后。**与 V3-9 关系**：V3-9 平衡剩余子项（数值/节奏调优）与 V4-S0~S2 可并行。施工图见 [PLAN_V4.md](docs/PLAN_V4.md)。

> 47 为 **V5 单机闯关养成方向锁定 + V4 服务端线暂缓**，用户 2026-06-26 确认。

47. **V5 = 单机 F2P 闯关养成（暂停 V4 服务端线）**：用户判断当前首要是丰富单机玩法与留存，暂停 V4-S5+（赛季/排行榜/部署，KAN-41 退回 To Do），转向把单机做成养成驱动的闯关 RPG。锁定（详见 [PLAN_V5.md](PLAN_V5.md)，Epic KAN-50）：①**核心范式 = 战力为底·操作为顶**（养成给有上限的数值；难度 = 系数 + AI 档 + 脏卡组；中等战力差可操作弥补、巨大战力差不能）；②**关卡 = 模板池 × 难度系数曲线**（~15 遭遇模板 + 系数递增 + boss 特化，100+ 关）；③**养成 = 10 级 × 3 阶浅养成**（单卡满 ≈ ×3.0；升级花金币提数值、升阶花碎片 + 解锁技能积木）；④**难度系数线性 1.0→~2.6 + boss 小跳**；⑤**初始 8 张 + 推关攒碎片解锁其余 8 张**；⑥**货币 = 金币（升级）+ 碎片（每卡，解锁 + 升阶）+ 宝石（占位，只产不充）**；⑦**节奏 = 挂机离线金币 + 无体力**；⑧**全程单机本地存档（user://）、不依赖服务端**（V4-S0~S4 成果保留不动）。施工 S0~S8（KAN-51~59）。复用现有 CampaignState/SaveSystem/RunModifiers/SkillSystem/ConfigLoader。**唯一较重新管线 = 出兵数值乘区**（我方按卡 level/rank、敌方按关卡 coef，注入 SkillSystem 生成路径，V5-S1）。

> ⚠️ **决策 47 已被决策 48 取代**（2026-06-26 当日转向）：V5 不再是"单机本地"，改为实时在线 F2P、服务器权威。

> 48 为 **项目转向实时在线 F2P 手游 + 服务器权威（推翻决策 47「单机本地」）**，用户 2026-06-26 确认。

48. **项目定位 = 实时在线 F2P 商业手游（服务器权威）**：用户拍板把项目从"买断/单机本地"彻底转为**按多人在线网游标准开发**。**推翻决策 47「全程单机本地、不依赖服务端」**，并更新决策 36「买断制单机」/ 46「V4 玩法验证·前期不实现支付」的定位（方向就是商业化 F2P；支付/合规按上线节奏推进，不再是"范围外"）。锁定：①**进游戏强制登录 + 持久连接**（启动登录 → 建持久 WS 会话 → **断线即不可玩**，网络抖动自动重连、长断回登录）；②**服务器唯一权威**——账号/钱包/货币/卡养成(等级/阶/解锁/碎片)/关卡进度/挂机 全在服务器 + PG DB；所有产出/扣费/解锁/升级/升阶/挂机结算走服务器（**服务器时钟**，改本地时钟/改存档均无效）；③**配置服务器化**——服务器持权威配置，登录后下发带版本配置包，客户端只内存持有 + 薄版本缓存（**非零配置**：lockstep 战斗需 units/cards/skills/arena 在客户端算，但源在服务器）；④**客户端 = 瘦表现层**——UI + 战斗 sim（lockstep 仍客户端跑保确定性）+ 非权威本地缓存（秒启动/只读展示，永远以服务器覆盖）；⑤**战斗仍客户端 lockstep**（决策 46 不变）——PvE 开战服务器下发权威输入(卡组 + 我方 level/rank)，胜负先**信任客户端 + 服务器 sanity 限制**（服务器复算/反作弊并入后续）；⑥**复用 V4 地基**（Go + PG + 账号 S1 + WS + lockstep），V4 服务端线从"暂缓"转为**主干**。施工：在线地基 N1~N2（持久会话+登录门 / 配置下发）→ 服务器经济 N3~N6（状态/结算/发奖/挂机服务器时钟）→ 瘦客户端 N7 → 原 S7 UI（接服务器）/ S8 内容平衡顺延其后。本地原型 S0~S6 算法镜像进 Go 做权威结算，客户端那份保留做 UI 预览 + 战斗内计算。施工图见 [PLAN_V5.md](PLAN_V5.md)。

---

## V4 — 联网升级 + 实时对战（✅ S0~S4 全部收官；S5 赛季/榜暂缓 KAN-41）

> 方向见决策 46，规划 [docs/PLAN_V4.md](docs/PLAN_V4.md)。**详细逐步历史已归档 → [docs/HISTORY_V4_DETAILED.md](docs/HISTORY_V4_DETAILED.md)**（S0 脚手架+双端 pb / S1 匿名登录 / S2 档案云存档 / S3 lockstep 实时对战★ / S4 匹配 ELO+Redis，均含两台 Windows 真机验收记录）。

---

## V5 — 实时在线 F2P 闯关养成（进行中，服务器权威）

> 方向见**决策 48**（推翻决策 47「单机本地」），权威规划见 [PLAN_V5.md](PLAN_V5.md)，Epic KAN-50。养成驱动的养成驱动的闯关 RPG：100+ 关闯关推关（难度系数）+ 货币经济（金币/碎片/宝石）+ 卡牌养成（升级提数值 / 升阶解锁技能积木）+ 挂机产出，**战力为底·操作为顶**，全程单机本地存档、不依赖服务端（V4-S0~S4 成果保留不动）。施工 S0~S8 = KAN-51~59。每步追加在本段。

> **已收官子步的详细段已归档 → [docs/HISTORY_V5_DETAILED.md](docs/HISTORY_V5_DETAILED.md)**（S0~S6 本地原型 / N1~N7 在线化 / S7·S7+ UI / 工程迁移 / KAN-49 联机视觉 / 卡池 16→48 / 框架地基#2~#4）。本段只保留**进行中与欠验收**条目；子步收官后详细段随手搬去归档文件。

### V5-S8 — 内容铺量 + 平衡（🚧 进行中，KAN-59；S8a~d 代码完成、S8e 真人验收待）
**口径（用户 2026-06-27 拍板）见 [PLAN_V5.md](PLAN_V5.md) §11.3**：生成器铺量、10 章×10 关、coef 曲线、`rec=920×coef×T`、敌塔 HP 随 coef。服务器经济**完全配置驱动** → 铺量是纯配置、客户端+服务器两端自动吃到、无需改业务逻辑。
- **S8a 遭遇模板池 3→15**（按原型补 12 deck）+ ConfigLoader 校验加固（archetype 枚举 + deck 8 张互不重复）。客户端 **300/300**。提交 `844fb33`。
- **S8b 平衡 probe harness**：`tools/balance_probe.gd`（headless AI-vs-AI 确定性扫战力门槛）+ **AIController 可选边改造**（构造第 4 参 `controlled_owner`，opponent 默认边恒等→零回归）。客户端 **305/305**。提交 `844fb33`。
- **S8c stages 铺到 100 关**（生成器）：`config/stages_spec.json` + `tools/build_stages.py`（+`--check`）→ `config/stages.json`（coef 1.0→2.842、rec 800→2275、boss ×1.1、奖励随章放大）。gameconfig sha256 自动 bump，服务器需重启读新配置。客户端 **311/311** + Go 集成测对真 docker PG 全过。提交 `d7730dd`。
- **S8d 平衡 pass**：敌塔 HP 随 coef 放大（`Match.scale_opponent_towers`，我方塔不缩放）+ 真关卡 probe 报告器 `tools/run_stage_balance.gd` + 平衡报告 [docs/BALANCE_V5_S8.md]。**核心发现**：AI-vs-AI 非可靠绝对裁判（规则 AI 不主动推塔→早期关王塔满血却超时输），但曲线形状被验证（王塔剩血 100%(ch1~3)→0%(ch4+)，难度咬人在 ch4≈coef1.5，符合"早苟中养成"）；曲线保持公式默认、不拟合 AI 假象，手感绝对校准交 S8e 真人。客户端 **313/313**。提交 `d7730dd`。
- **GM 作弊工具（KAN-68 Done）**：随 S8 提交，服务器权威改 `economy_*` 表（加货币/碎片/解锁/满养成/通关到第 N 章/重置）+ 设置内 GM 面板；env `GM_ENABLED` 门控、**prod 必关**，走会话鉴权只能改自己账号。真 PG 集成测全过 + 真人验收过。提交 `d7730dd`。

> **下一步 = V5-S8e 真人验收**：从第 1 章推进体验难度曲线（用例 [docs/ACCEPTANCE_V5_S8.md](docs/ACCEPTANCE_V5_S8.md)），验收过 + 用户同意后 KAN-59 → Done。之后：联机对战美术对齐（KAN-49，把单机精灵/FX/手感搬进 `net_battle_scene`）/ 上线化（IAP·合规·赛季榜，V6+）。

---

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

---

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

---

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

---

### V5 三国改版 · A3 场景与系统美术清单（✅ 表已产出待评审，2026-07-04，未 commit 待用户指示）

**用户四决策**（已入 PLAN_V5_SANGUO §0 决策 7~10）：①**塔分阵营皮肤**（我方汉军套恒定 + 敌方魏/蜀/吴/群雄四套随章节，P0=我方+黄巾）②**UI 本次小改**：保像素风、中式化配色纹样（大改版后续另立项）③**头像首批 16**（四阵营×4）④**塔损毁=坍缩残骸图**（低矮不挡兵路；现状为程序化"原图压低 42%+染暗"，battle_scene:351——正式图逐套替换）。

**产出 [docs/design/scene_system_art_spec.xlsx](docs/design/scene_system_art_spec.xlsx)**（6 sheet / 69 行，与 48 卡表同风格：目标路径/现资源对照/尺寸规格/优先级/状态列）：
- **塔与战场 14 项**：塔 5 套（我方汉军 P0 / 黄巾 P0 / 魏蜀吴 P1，均 3/4 俯视方向无关构图=横版兼容）+ 坍缩残骸×5 套 + 地形 3 主题（中原 P0 / 山地·江河 P1，对应章节叙事）+ 浮桥（**标注横版两朝向变体强约束**，联动 PLAN_V5_HBATTLE H3 素材约定）+ 装饰物件。
- **战斗 FX 18 项**：状态 FX 统一 5 套（结霜/眩晕/冻结/灼烧[T7 预留]/治疗，全池共用阵营只差符纹——对齐 T3 引擎架构）+ 9 张法术落点表现 + 通用 4（命中/亡语召唤/入场/塔损爆）。
- **UI 系统件 8 项**：品质框 4 档（对照现 RARITY_COL 色值，加中式角饰递进）+ **阵营徽记×4（新增，图鉴筛选/卡面角标/未来羁绊 UI 复用）** + 货币 3（五铢钱/玉璧/虎符碎片）+ 按钮 3 套×3 态与面板 2（同尺寸同 9-slice 结构中式重绘，PixelUI 框架不动）+ menu_bg + 章节节点；**表内显式记录"UI 大改版=后续另立项"**。
- **头像 16**：四阵营×4（魏：虎贲校尉/典韦/司马懿/荀彧；蜀：黄忠/周仓/庞统/无当火油手；吴：周瑜/孙尚香/黄盖/山越旋刃卫；群雄：张角/于吉/左慈/黄巾力士），128×128 方形大头。
- **音频方向 6**：BGM×3+胜负 stinger+SFX 换皮方向，落地走既有 AudioConfig.xlsx→audio_assets.json 管线。
- **资产盘点结论**（建表前核实）：塔现用 building1(王)/building6(公主)、库存 2-5/7-8；UI 皮=12 张（按钮 3×3+面板 2+menu_bg）；地形=Lonesome_Forest 系 tileset；Boss vampire_lord 全套为奇幻遗产（三国 Boss 素材列"储备"，随 A4/后续）。
- **验收**：属文档评审（用户+美术过表：项齐/规格对/优先级认），已挂 [ACCEPTANCE_SANGUO.md](docs/ACCEPTANCE_SANGUO.md) 台账第 4 条，Jira 建议 三国化-A3 → In Review。**代码/config 零改动**（部署区高亮等 3 项标注"保持程序化、无需素材"）。

---

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

---

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

---

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

---

### V5 · 🐞 发奖弹窗「继续」按钮失灵 → DragScroll 遮挡判定修复（✅ 修复+单测过，2026-07-05）

**用户回报**（横版验收时发现，实为 DragScroll 引入的回归、与横版无关）：闯关发奖开箱弹窗点【继续】无反应、控制台无报错；点屏幕其它地方"反而能退出"。
- **根因**：`view/ui/drag_scroll.gd`（2026-07-04 滚动交互修复引入）按下时只判"落点在 ScrollContainer 矩形内"就代管并吞事件，**不知道上面盖了弹窗**——reward_chest 是 stage_map 根下的全屏层（PRESET_FULL_RECT + STOP），其【继续】按钮 (240,880) 正落在闯关列表滚动区矩形内 → press 被吞、按钮收不到点击、无报错。
- **更隐蔽的第二刀**：轻点派发 `_hit_button` 只搜滚动子树 → 命中**弹窗底下被遮住的关卡按钮**直接 `pressed.emit()` = **穿透误触**（用户看到的"点别处能退出"其实是误触关卡按钮切了场景，不是正常退出）。
- **修复**（一处通用，组卡/创号/图鉴/闯关四界面同享）：press 代管前加 `_covered()` 判定——`get_viewport().gui_get_hovered_control()` 取鼠标下最顶层 Control，不属于本 ScrollContainer 子树（含自身）= 滚动区被盖 → 不代管、点击走正常 GUI 路径（弹窗按钮恢复、穿透同时堵死）。触摸路径不受影响（DEVICE_ID_EMULATION 事件本就跳过）。
- **验证**：客户端全量 **366/366** 零回归。真人回归 = 台账 **C-6**（发奖弹窗按钮 + 不再穿透）——**2026-07-05 真人验收通过**，与横版 H1H2 一并提交（69bfe6a + 82fdc44 已推 master）。

---

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

### V5 · 上线工程 E0 契约与文档真相源（KAN-103，✅ 用户确认完成，2026-07-12）

**背景**：对前后端、网络和基建进行 Staging/Prod 架构审计后，确认“在线功能已完成”与“可安全上线”之间仍有工程化缺口。用户拍板先做 E0，只处理文档和代码工程规范，不碰游戏内容；继续一步一确认，Jira/文档齐备、用户确认后才 commit+push。

**本步锁定的新工程决策**（目标契约，不伪装成当前代码已实现）：
- **Prod 不离线降级**：登录失败/掉线只允许登录、重连、更新提示和当前页面只读；可选 `offline_training` 必须是显式非权威沙盒，结果永不写回在线进度。
- **Prod 无 GM**：E0 安全基线收紧 V5-S9“所有部署常开 GM”的历史决定。GM 仅存在于 Staging 隔离制品/路由；Prod 制品与路由表必须不存在 `/v5/gm/*`。当前代码仍常开，留 E2 实做。
- **Gateway 近期单活**：房间/连接/重连状态外置前只允许一个 active Gateway；API/verifier 可独立扩缩。多活 E9 只有在状态外置、跨实例重连/匹配一致性与负载证据齐备后立项。
- **认证目标**：长期 JWT 只走 HTTPS Authorization；WS 改为短时单次 ticket + WSS 首帧认证，Origin allowlist，代理日志不记录 query/凭据。

**新增工程文档**：
- `docs/architecture/`：在线运行时状态机、Gateway 状态所有权/有界重连、服务器配置权威与版本绑定。
- `docs/adr/0001~0003`：单活 Gateway、服务端配置权威、生产不离线降级。
- `docs/security/`：威胁模型、access/refresh/WS ticket 生命周期与首帧认证契约。
- `docs/deployment/`：Staging 私网+Caddy 基线、Production P0/P1 门禁和 E0 时点已知阻断。
- `docs/runbooks/`：SIGTERM Gateway drain、不可变制品回滚、SEV 事件响应。
- `docs/engineering/AGENT_SHARED_RULES.md`：Claude/Codex 共享真相源优先级、施工纪律、环境占用规则和上线边界。

**规范与 CI**：
- `AGENTS.md` / `CLAUDE.md` 增加逐字一致的 `AGENT-SHARED` 镜像块；当前进度标题明确降为快照，真实进度只看 HISTORY + Jira。
- `tools/check_docs.py`（stdlib）校验 14 个 E0 必备文档、两根级镜像块和相对 Markdown 链接；顺带发现并修复 `PLAN_GRAND.md` 既有 V2 链接路径错误。
- `.github/workflows/lint.yml` 扩为代码+文档静态门禁：Markdown/规则/校验脚本变化时运行 `gdlint .` + `python tools/check_docs.py`。
- `PLAN_GRAND.md` / `PLAN_V5.md` 新增 E0→E9 上线工程线；E0 后按 E1 主流程接线 → E2 公网安全 → E3 Gateway 有界状态 → E4 排空探针 → E5 基建 → E6 verifier → E7 可观测 → E8 CI/CD，E9 HA 条件后置。

**环境与边界**：本步未启动、探测或占用 Godot/Docker，未修改 Go/GDScript、配置、资源或数据库；保留用户已有未跟踪目录 `testAssets/newAssets/`。Jira **KAN-103** 按 `Idea → To Do → In Progress → In Review` 流转；`python tools/check_docs.py`（18 files）与 `git diff --check` 通过。用户于 2026-07-12 明确确认，随后转 Done 并执行本步 commit+push。

---

### V5 · 三国正式素材首张接入：骑士行走帧+单位阴影+战场整图背景（KAN-104，✅ 真人验收通过，2026-07-12）

**做了什么（三国改版轨道A · A4 素材接入首批；素材源 = testAssets/newAssets/ 三张新图）**：
- **素材加工（python 管线）**：骑士行走 10 帧原图 2列×5行（199×472，帧格不整除）→ alpha 包围盒精确切帧 + 重打包**单行 strip**（`SpriteDB.frame()` 只按单行取帧）：100×96/帧、bbox 水平居中、**脚底对齐**（防走路上下跳）；**帧序=行优先**，经「相邻帧循环像素差总分」算法验证（行优先 186 vs 列优先 261，分低=顺滑）。产出 `assets/units/sanguo_knight_walk.png`（1000×96）+ `unit_shadow.png`（46×39）+ `assets/map/battle_bg.png`（720×1400）。
- **knight_body（虎贲校尉）换皮**（sprite_db「替换正式素材三步」首次实战）：新条目 fw100/fh96/cols10/n10/fps12；单方向素材无背面行（row_up 删）；**攻击帧未出 → 不配 "attack" 键**，frame() 缺省回退走帧（等美术补劈砍帧）。卡面肖像自动跟随（col0 帧）。
- **新条目字段 ×2（正式素材通用，后续 38 张换皮全受益）**：`natural`=true → 战斗内**轻染 22% 队伍倾向**（同塔的画法；原「全强度乘队伍色」会把高饱和正式素材糊成黑剪影——首截图即中招）；`shadow`=true → battle_scene 画脚下椭圆影（贴图自带 30% alpha 单遍太淡且大半被人物盖住——先画成纯红定位确认「在画、位置对、纯粹太淡」，后叠两遍≈51% 黑 + 宽 0.9box 压脚线）。
- **战场整图背景「特征对齐」接入**（`_draw_bg_image`，`BG_ENABLED=false` 可回退 tile 铺地）：直接拉伸会**竖向压扁 25% + 桥错位 ≤32px**（python 测图上河带中心 y=669.5/47.8%、双桥中心 x=171.5/528 vs 逻辑 50%/22.2%/77.8%）→ 改「**双桥中心定 x 缩放 + 河中心锚 y**、等比取源区域」贴 `_field_rect`，逻辑河/桥与图上河/桥重合（士兵过桥踩在画的桥上）；代价=图边装饰被裁（顶部小屋/右上湖/左右树带各半）。横版 = `draw_set_transform` 绕场心转 90° 复用同公式。竖/横截图验证均过。水动画 tile 在 BG 模式下不再画（静态河，试点可接受）。
- **美术出图规格产出**：`docs/design/battle_bg_template_720x1050.png` 标注模板（画布 720×1050 可等比 2x/4x；河中心 y=50%、桥中心 x=22.2%/77.8% 宽 80px、六塔 footprint 框、18×32 参考网格；画布内=100% 可玩区禁边框装饰）——美术垫底作画，按此出图程序零裁切直接铺满。
- **验收揪出 P1 显示 bug（组卡卡池骑士图标严重超框）+ 根因链**：`TextureRect` **expand_mode 必须先于 texture/size 赋值**——默认 EXPAND_KEEP_SIZE 下赋 texture 的瞬间 minimum size=帧尺寸，后设的 size 被 clamp 顶大（52×40 → 100×96）；旧 24×24 帧比框小故潜伏至今。headless probe 实测坐实（texture 先=顶成 100×96 / expand 先=正常 52×40；**决定性条件 = size 赋值时 expand_mode 已生效**）。修 `sprite_db.make_card_portrait`（组卡/养成/卡详情/创号全收口）+ `hud_widgets` 名片头像（同坑预防）；用户直觉正确——**养成图鉴 96×96 框实际也被撑到 100×96 溢 4px**，一并修复。回归测试 `test_make_card_portrait_size_not_inflated_by_large_frame` 锁死顺序，经「注入 bug 顺序→测试变红(报 100×96)→还原→绿」**真反证**验证有效（第一次反证只挪 texture 没挪 size=假阴性，教训：反证手术必须精确复现原 bug；顺带教训：临时实验文件还原**禁用 git checkout**——会把未提交改动一起丢，当场吃过一次被迫重建 sprite_db 全部改动并 diff 核对）。坑已入长期记忆（TextureRect expand 顺序，类比 set_anchors_preset 陷阱）。
- **验证**：客户端单测 **393→394**（+1 回归）全过零回归；gdlint 全绿；截图自检（竖/横战场+阴影 zoom）+ **真人 worktree 实机验收通过（2026-07-12）**：战斗背景河桥对齐/骑士走路动画+阴影/横版一局/组卡·养成·卡详情图标复查。纯客户端，docker 零操作。`tests/_shot_harness.*`（临时截图 harness）随验收完成删除。
- Jira：**KAN-104** 建单挂 Epic KAN-50 → Done（真人验收+用户拍板）。A4（KAN-93）素材接入自此开张：38 张单位换皮沿本步管线逐条替换（sprite_db 三步 + 帧序算法 + natural/shadow 字段现成）。

---

### V5 · 上线工程 E1 在线主流程接线（KAN-105，✅ 完成，2026-07-12）

**目标**：把 N1/N2 已存在但未进入生产场景流的 `SessionConn` / `ConfigPush` 接起来；登录、持久 WS、服务器配置与经济快照全部 ready 后才开放在线业务。开工时用户仅授权 Docker、Godot 由 Claude 在另一 worktree 占用；收尾时用户进一步授权使用 Godot。验证始终用显式指向 E1 worktree 的独立 headless 进程与隔离 userdata，未触碰 master 编辑器及 8000 端口。

**唯一在线运行时**：
- 新增 `net/online_runtime.gd` 并注册唯一 autoload `Online`：持有账号 Session、持久 `SessionConn`、服务器配置 `ConfigLoader`、`EconomyStateCache` 和内部 HTTP 同步器；状态机 = BOOTSTRAP → AUTHENTICATING → CONNECTING → SYNCING → ONLINE_READY / DEGRADED / SIGNED_OUT。
- 既有 `session.ensure(http)` 语义升级为“认证 + profile + Session WS + ConfigPush + economy snapshot 均成功”；重复场景复用同一实例。`GameState.session/config/economy` 在真实 SceneTree 中统一委托 `Online`，纯逻辑无树测试才保留本地构造 fallback。
- `config/network.json` 显式增加 `session_ws_url`；战斗 WS `ws_url` 保持不变。E2 前仍沿用当前 URL JWT，本步不越界改认证协议。

**配置权威与 fail closed**：
- `ConfigLoader.load_from_files(files)` 对服务器 bundle 先用候选实例完整结构/交叉引用校验，成功才原子替换；缺文件/坏包保留上一快照并进入 DEGRADED。
- `SessionConn` 增加 `config_failed`、拒绝“up_to_date 但本地空缓存”、重连使用最新确认 cfgver、主动 close 不再误触发重连。
- `EconomyStateCache` 所有写入口（挂机、养成、通关、PVE start/report、GM）统一走 Online ready guard；掉线直接返回 `online session not ready`，不发 HTTP。
- `net/session.gd` 不再把 profile 离线缓存视为登录成功；缓存只保留只读用途。

**场景收口**：
- 主菜单登录失败只显示“重试连接”，删除 `_build_menu(false)` 离线业务菜单；本地存档权威的旧“探险”入口禁用并明确标成离线原型未开放。
- battle/net_battle/deck_builder/level_select/campaign/run 不再各自 `ConfigLoader.load_all()`，统一读取 `GameState.config()` 的服务器快照。
- 在线 PVE 在 session DEGRADED 时冻结 sim/卡牌输入；PVP 继续 poll 独立 battle WS 以维持网络顺序，但阻止本地出牌并显示恢复中。恢复 ONLINE_READY 后继续。

**测试与验证**：
- 新增/扩展 GDScript 单测：服务器 bundle 成功/坏包原子性、空缓存 up_to_date 拒绝、重连 cfgver、Online 初始非 ready、经济写 gate、唯一 autoload、生产场景禁止本地 `load_all` 与离线菜单源码门禁。
- Godot 4.6.3 headless 导入/解析零错误；E1 开发基线 **408/408**、rebase KAN-104 后合并基线 **409/409** 通过。`uv run --with "gdtoolkit==4.*" gdlint .` 全库通过；`python tools/check_docs.py`（18 files）与 `git diff --check` 通过。
- Go `go test ./...` + `go vet ./...` 通过；授权 Docker 的 PG/Redis 全套 integration（auth/profile/economy/matchmaking/battle/verify，`-p 1`）通过；API/Gateway `/healthz` 均 200。
- 运行中 Gateway 真实 WS 探针成功：`/v5/session/ws` 返回 MsgId 60 ConfigPush，单帧 186023 bytes，证明现有 Docker 服务端契约可用。
- 真启动链 smoke 通过：隔离新用户启动后依次完成登录 → profile → Session WS → ConfigPush → economy snapshot → 主菜单路由，日志确认 `ready cfg=3aceb94356e37d32`。
- Gateway 受控重启 smoke 通过：客户端观测到 disconnect，约 2 秒后重新连接，再次拉取 economy 并回到同一配置版本的 ONLINE_READY（Connected=2、Ready=2）；重启后 API/Gateway `/healthz` 均 200，六个 compose 服务正常。

**真人验收反馈与修正**：
- 用户完成 PVE 验收：Docker 全套服务重启后 PVE 正确冻结；主菜单“探险（离线原型·未开放）”是 E1 刻意禁用的旧原型入口，不代表当前会话离线。PVP 真人验收仍挂账。
- 全套服务重启令 Gateway/PG 约 41 秒不可用，暴露 `WebSocketPeer` 尚在 CONNECTING/CLOSING 时每 2 秒重复 `connect_to_url` 的 `ERR_ALREADY_IN_USE`。根因位于共享 `WSClient` 与 Session/PVP 两处重试循环；此前仅快速重启 Gateway 的 smoke 未覆盖慢恢复窗口。
- 修复为 `WSClient.can_connect()` 只允许 CLOSED 状态拨号，有效重连时换新 peer 丢弃旧内部状态；SessionConn 与 BattleClient 均只在 socket 可连接时消费重试周期。新增两条 fake socket 回归测试覆盖 CONNECTING 不重入、CLOSED 立即重试。
- PVE 冻结期间新增全屏“在线会话中断 / 恢复中…”状态层；sim、卡牌输入与经济写的原 fail-closed gate 不变。
- 复验：Gateway 停止 8 秒（跨 4 个重试周期）后恢复，Connected=2、Ready=2、重入错误=0，配置版本保持 `3aceb94356e37d32`，Gateway `/healthz` 200。
- 用户第二轮只关 Battle/API 复验又暴露复合可用性缺口：Battle 当前只是占位进程、不参与 PVE，关闭后 PVE 继续属预期；但 Gateway 仍在线时 API 停止约 13 秒，旧 `ONLINE_READY` 未感知 API 故障，PVE 继续推进到结算。服务恢复后 battle=1105 最终只结算一次（gold 0→300、verifier PASS），没有重复发奖。
- **踩坑③ API 健康未进入在线状态**：Online 只看持久 Gateway WS；EconomyClient 无 timeout，权威请求可无限 `await request_completed`。修复为所有经济/PVE HTTP 统一 5 秒 timeout，并检查 HTTPRequest transport result；transport/5xx 经 EconomyStateCache reporter 反向驱动 Online → DEGRADED，PVE 随即冻结；Gateway 在线时 Online 每 2 秒重拉配置/经济快照，API 恢复后再回 READY。
- **踩坑④ 战后双击绕过 final flush**：`_on_stage_return` 首次点击等待 recorder flush 时按钮仍可点；第二次进入后，`PveRecorder._flushing` 直接返回并提前跳场景，故日志打印两次。数据库实证 battle=1105 摘要 432 tick、最后 hash 仅 tick 400。修复为战后提交 single-flight + 按钮立即禁用/显示“提交战报中”；`PveRecorder.flush` 明确返回 bool，失败证据回队且停留结算页显示“重试提交”，只有最终证据提交成功才允许离场。
- **踩坑⑤ pending 先删后报会丢结算凭据**：stage_map 旧逻辑先清 `stage_last_result` 再 await StageClear；失败后 battle_id/summary 消失。修复为服务器确认后才清；失败保留 pending、禁止开新局并显示“结算服务不可用·点击重试”。服务端把相同 `battle_id + stage + stars + summary` 的重复 StageClear 改为幂等返回当前状态、绝不二次发奖；变造 claim 仍 fail closed，覆盖“事务已提交但响应丢失”。
- 自动复验：Godot E1 开发基线 **408/408**、合并基线 **409/409**；Go economy/verifier unit+vet 与真 PG integration 通过（含幂等重试不加钱、变造重放拒绝）；真实 API 停服 smoke 中权威请求 5 秒有界失败、Online READY→DEGRADED，API 恢复约 2 秒后重新拉经济状态并回 READY，config=`3aceb94356e37d32`、API `/healthz` 200。
- **E6 挂账**：verifier 当前允许末段周期 hash 缺失，只要已有 hashes、全指令重放结果、duration/king_hp 最终对帐一致仍可 PASS；E6 必须增加 final report/最后 hash 覆盖结算 tick 的完整性门禁。本步不混改 verifier 协议。
- 用户于 2026-07-12 确认 KAN-105 转 Done 并提交合入 master；PVE Gateway 断线与恢复已真人通过，PVP 真人验收作为明确挂账保留，不阻断本步收口。

---

### V5 · 文档体系重整（✅ 完成，2026-07-12）

**动因**：文档越写越长（HISTORY.md 1046 行、CLAUDE.md 进度快照流水账化且已过时），检索与 agent token 成本上升。用户拍板：①V4+V5 已收官段归档 ②PLAN_V4/PLAN_V5_S9 移 docs/、UIFRAME 留根（欠 F 组验收）③决策日志整体保留 ④不建 Jira 单、只记 HISTORY。
- **HISTORY.md 拆分**：V4 详细段 → [docs/HISTORY_V4_DETAILED.md](docs/HISTORY_V4_DETAILED.md)；V5 已收官子步 → [docs/HISTORY_V5_DETAILED.md](docs/HISTORY_V5_DETAILED.md)；主文件只留 快速上手 + 进度总览表 + 决策日志 + 活跃线（S8 / 三国轨道A / 横版 / UI 框架 / KAN-99 / E0·E1）。
- **根目录收纳**：PLAN_V4.md、PLAN_V5_S9_ACCOUNT_UX.md 移入 docs/（已收官，对齐 V1~V3 惯例），全仓引用链接同步更新。
- **CLAUDE.md 快照瘦身**：「当前进度快照」压至指针式短摘要（与 AGENTS.md 同文），运维要点（verifier/api 重启铁律）移入工具链段——快照本就非真相源，长版流水账反而误导（schema/GM 口径都曾落后）。
- **新增 [docs/README.md](docs/README.md) 文档地图**：全部文档一行式索引（用途/状态/何时读），agent 检索总入口。
- **规约固化**：AGENT_SHARED_RULES.md「共享文档维护」补文档纪律——单文档目标 ≤300 行、版本线/子步收官即归档详细段、新专题开新文件不追加旧文件。
- **顺带收编**：testAssets/newAssets/ 三张 KAN-104 素材源图（BG/knight_walk_1/shawdowm + .import）入库跟踪（原始源图归 testAssets 惯例；加工成品已在 assets/）。
- **验证**：`python tools/check_docs.py` 全过；纯文档 + 素材源收编、不涉代码与引擎单测。

---

### V5 · AI 生图管线首战：骑士攻击帧占位（✅ 完成·真人实机验收通过，2026-07-13）

**背景**：knight 只有走帧、攻击缺省回退走路（KAN-104 遗留）。用户用 Nano Banana Pro（Gemini 3 Pro Image）按 agent 提供的参考图+prompt 出图，agent 做确定性后处理并接入——docs/NOTE_image_gen_mcp_pipeline.md §0 架构的首次实战（§7 全记录）。
- **两轮试错**：v1 传原始扁条带 → 体型跑成写实比例/帧重复/拖影；v2 换「单帧×6放大白底比例参考+条带」双参考图 + 比例硬约束 + 降到 6 帧 2×3 网格 → 三头身锁住、姿势齐全带弧光火花。
- **后处理管线**（uv+pillow+numpy，脚本可复放）：抠绿去 spill → 网格切帧 → 收势帧锚定统一缩放（对齐走帧 94px 身高）→ **身体密度窗口**定位（踩坑：底部质心会被落地剑尖+火花拉飞）→ 脚底对齐基线 → 100×96×6 单行条带。
- **接线**：assets/units/sanguo_knight_attack.png + sprite_db.gd knight_body 加 attack 状态（cols 6/n 6/fps 12）+ headless 导入；view/logic 零改动（frame() 自动切换）。占位定位：正式美术到位整条替换。
- **验证**：全量单测通过（exit 0 零回归）；gdlint 未涉及（仅数据条目）。**真人 F5 实机验收通过**（2026-07-13，PvE 实战骑士接敌挥剑）。banana 原图收编 testAssets/newAssets/knight_attack_1.png（对齐 knight_walk_1 命名惯例）。Jira：KAN-106（补单直 Done，用户指示）。
- 顺带：修复 Docker 引擎重启后 api 容器崩溃循环（配置挂载空+postgres 时序，compose up -d api 恢复）；清理误跑散容器 focused_haibt。飞书规格文档新增第八章实物案例（走帧图集/单帧切图/程序化占位/AI 生成版对比）与第九章 AI 生图经验。Jira：暂记 A4 素材线名下（KAN-93 开工时并入），未单独建单。

---

### V5 · 战场屏幕格改 32×32 正方形（KAN-107，✅ 完成·真人实机验收通过，2026-07-13）

**背景**：美术评审对 40×32.8 非正方形屏幕格提出维护顾虑；36×36 需 1152px 高、手牌区放不下 → 用户拍板 **32×32**（当前 HUD 下最大整数方格 + 行业标准砖尺寸）。
- **view 一处函数收口**：`battle_scene._field_rect()` 竖版分支改「格边长取整数 letterbox 居中」→ 720×1280 基准下战场 **576×1024**、两侧各 72px 装饰边栏（露 COL_BG 深底，边栏素材另出）。横版 H2 分支不动；`_t2s/_s2t` 契约不变（H1 变换层收口红利：一处改全生效）。**logic/config 零改动**（确定性/联机/反作弊不受影响）。
- **既有 battle_bg 自动兼容**：KAN-104 的特征对齐是"图内特征→field rect 比例"映射，field 缩放自动跟随，无需重出。单位渲染基准 `_ur()` 36.4→32px（缩 12%），sprite scale 先不动、待实机手感定。
- **美术口径切换**：出图画布 720×1050 → **576×1024**（1 格=32×32 整除、全表整数；2x=1152×2048）；飞书规格书九章全量更新（正文/表格/FAQ 改版记录/三张画板重画）；模板图重出 docs/design/battle_bg_template_576x1024.png（旧 720×1050 版删除）；GDD 附录B/docs README 同步。
- **测试**：`test_hbattle_transform` 竖版基线更新（field 72,67,576,1024 / tile 32×32 / ur 32 / footprint 128 / 部署区），全量 **409/409** 零回归；gdlint 绿。**真人 F5 验收通过**（2026-07-13：竖版居中+边栏观感/部署命中/单位手感/横版回归四项全过，sprite scale 未调）。

---

### V5 · 三国 A4 首批正式素材：骑士全家桶 + 阵营分色塔 + 新战场 BG（KAN-93 开工，✅ 真人三轮验收通过，2026-07-15）

**做了什么（素材源 = testAssets/newAssets0715/ 十一张图，美术命名+试图识别自动归位，worktree feat/assets-0715）**：
- **虎贲校尉(knight_body) 正式全家桶**：走帧 10 帧重打包 100×96 单行（统一缩放 ×1.492 对齐 94px 峰值身高、bbox 居中、脚底 y95——KAN-104 管线复用）；**攻击帧 8 帧上 152×152 大方格**（挥砍横扫缩放后宽 124px 装不进 100 格）+ sprite_db 新用 `sc=1.583(=152/96)` 补偿——基线 y123 由 sc 反解（foot_frac=0.5+(95/96-0.5)/sc），保证走↔攻切换脚底不跳；**前冲下压位移全局锚定保留**（收势帧 f7 锚定，劈砍落点 129/134 不逐帧对齐——逐帧对齐会吃掉美术画的下压动作）。
- **立绘卡面**：322×346 原图入库；sprite_db 条目新增 `portrait` 字段，`card_portrait_tex` 优先立绘（卡面/图鉴/卡详情/头像全自动跟随）。
- **配套战斗特效三条带（view 新机制）**：sprite_db 条目新增 `fx` 字典（attack/hit/death → tex/fw/fh/n/dur/size）+ `unit_fx()` 访问器；battle_scene 新 `_ufx` 列表 + `_spawn_unit_fx/_draw_unit_fx`。攻击刀光=近战冷却上升沿触发（`_detect_attacks` 重构：ranged→投射物 / 有 fx 近战→刀光落目标身上，目标在右侧水平镜像 draw_set_transform）；受击星芒=`_on_hit` 加 unit_id 参数、有配套 fx 时替换程序化火花；死亡白烟=`_detect_events` 新 `_ulast` 记最后存活位置、消失即触发。**帧网格勘误**：death 原图=8 帧×200（非目测 10 帧，切缝 alpha 验证）；hit 原图非均匀摆放 → 按谷切 6 帧重打包 72×40；attack_ef 4×116×116 网格干净原样用。
- **首套阵营分色塔**：我=蓝顶/敌=红顶中式塔楼 ×4（sanguo_tower_{king,arrow}_{blue,red}.png）；`_draw_towers` 按 owner 选贴图、队伍色乘法 0.5→natural 轻染 0.22（同单位正式素材画法）；中式塔纵向比例（王 130×169）→ 宽系数 1.35/1.05 压到 0.95/0.85 防塔身过高（验收可调）。废墟态/血条/王冠/闪白照旧。
- **新战场 BG 特征对齐接入**：720×1502 卡通风整图（⚠️ 未按 KAN-107 576×1024 规格出图，特征对齐吸收）；python 精测 河带 y=648 / 桥质心 x=188.8·505.2 → battle_scene 三常量更新。**惊喜发现：图上黄土路正好绕六塔逻辑位画**（美术按真实塔位出图，塔落在路环节点上）。
- **验证**：客户端单测 **412/412**（+3：立绘 override / unit_fx 边界合法 / 攻击帧 152+sc）；gdlint 绿；worktree headless 导入干净（8 新贴图 .import 生成）；python 合成自检图（BG 裁切+六塔逻辑位贴放）确认河桥塔对齐。纯 view/assets 改动，logic/config 零改（无需重启 docker；master 编辑器全程未碰）。
- **收尾**：用户改为直接在 master 验收 → worktree 提前合回（095d57c）+ 两轮反馈修复（19567fd）→ **三验通过、已推送**。挂账：net_battle_scene（PVP）塔分色/配套FX/Y-sort 同步接入 = A4 后续小步；72px 边栏素材已被 BG 铺满全屏覆盖（填充边直接露出，边栏素材需求消失）。Jira：KAN-93「正在进行」+ 两条批次评论。
- **验收反馈修复轮①（2026-07-15，真人首验后）**：①塔位微调——`TOWER_YOFF_TILE` 纯视觉 y 偏移（敌箭塔上移 0.5 格贴 BG 侧边节点、我王塔下移 0.5 格沉底部平台；python 实测 BG 节点坐标定值，逻辑塔位不动）；②**镜像朝向机制**——sprite_db 新 `mirror` 字段（单方向侧脸素材），battle_scene 走路按屏幕移动方向、攻击按目标方位水平翻转（绕单位中心 -1 缩放，攻击刀光 FX 本就带 flip 保持一致）；③**攻击态阴影偏离修复**——根因=阴影用了含 sc 补偿的攻击大方格 box（1.583× 放大+下坠），frame() 新增 `base_scale`（不含 sc 的身体基准），阴影改用之，走/攻阴影恒定；④**BG 铺满全屏**——用户澄清美术出图四周树林/湖为屏幕填充边（长屏适配），新 `_bg_full()` 把 dest/src 从场地矩形同步扩展到视口边（特征对齐锚不变；竖版横版都接，图左侧填充边差 ~9px 露深底可忽略）。**gdlint 踩线**：battle_scene 一度 1525 行超 1500 上限 → 翻转绘制统一走 draw_set_transform 单路径（顺带消掉 if/else 重复）+ 压缩本轮注释 → 1499 行。全量 **412/412**（+2 断言：base_scale/mirror）；gdlint 绿。修复轮改动未提交，随验收通过后一并 commit。
- **验收反馈修复轮②（2026-07-15，二验后）**：①我王塔再上移一格（`king_p` yoff +0.5→**-0.5**，二验实感定值）；②**单位/建筑伪深度 Y-sort 机制**（用户点出缺口）——塔+单位并入 `_draw_world` 单通道，按屏幕「接地线」升序绘制（塔=footprint 底边、单位=脚线近似 c.y+r×ur）：屏幕上方（远）先画、被下方（近）盖住，符合自下往上的俯视视角；空军 +100000 恒最上层；平局按收集序稳定 tiebreak 防闪烁。原 `_draw_towers/_draw_units` 拆为 `_draw_tower_one/_draw_unit_one`（`_seen` 记账随收集、清理循环并入）。③**行数腾挪**：程序化 FX 助手（seq/dust/arrows/heal）原样抽到新文件 `view/fx_draw.gd`（纯静态、canvas 传参），battle_scene 1499→1482 行（<1500 lint 上限）。全量 **412/412**；gdlint 绿；headless 导入干净。镜像/攻击阴影/BG 铺满 二验通过 ✓。

---

### V5 · UI 系统策划启动 + 单位体型三档定稿（KAN-108 建单，2026-07-15）

**UI 正式资源立项（给主美/UI设计师）**：
- **风格拍板**：全面转卡通手绘 UI（与 0715 正式素材同源），程序化像素 UI 定性为占位、整体退役；适配口径升级——逻辑宽 720 恒定、高度弹性 1280~1600，标准设计画布 **720×1560**、出血 720×1600、16:9 兜底验证；安全区硬约束 顶 100px/底 60px（iPhone 灵动岛/安卓打孔换算取严）。
- **飞书《UI 系统策划案》**（docx/X3lwd7t4mo372GxpE1ecsurYnpd，用户 full_access）：八章=基调/屏幕适配/Design Tokens/组件库 20 项/图标 36 枚/逐屏 14 节/弹窗体系/交付规范 P0P1P2；用户反馈语气过正式+缺示意图 → 转向 **HTML 示意图先行**、飞书暂停手工优化中。
- **HTML 示意图集**（docs/design/ui_mockups/，9 文件 + 共享 ui_mock.css 模板；launch.json 加 ui-mockups 静态服务端口 8766）：主界面 CR 式改版（参考真机截屏 testAssets/20260715-051059.jpg，**用户已评审通过**：结构/六入口收编/章节主视觉居中）+ 卡牌页(图鉴组卡合一)/闯关页/战斗HUD/卡详情/结算开箱/创号匹配/覆盖层三合一 + index 目录页；每图带安全区红线开关 + 结构说明 + 给美术的资源点。导航架构改版：五页签(商店灰·卡牌·对战·闯关·探险灰)+顶部齿轮，旧六按钮主菜单与基地页废弃（挂机并入活动轨、闯关进度并入章节主视觉）。浏览器几何探针自检（分区无重叠/顶栏贴安全线）；其余屏待用户评审。
- **单位体型三档定稿**（与主美商定）：5 档→**3 档 中/大/超大**＝面积 1/2/4 格、直径 1.0/1.2~1.4/1.8~2.1 格、画布 100×96/128×128/**192×192**（密度统一≈96px/格）；用户原口径「中=直径0.5」经验算证伪（面积1格⇔直径1.0，差整 2 倍=半径口误）用户确认修正。飞书规格书第七章三处替换 + 比例画板 SVG 覆写重画（缩略图自检过）。**逻辑 body_radius 零改动**（确定性红线）；视觉三档映射建单 **KAN-108**（待办，宜随 A4 换皮一并做）。
- 顺带收编他会话遗留：docs/engineering/MEEGLE_WORKITEM_GUIDE.md + docs/design/card_progression_design_doc.html（登记文档地图）；CR 参考截屏入 testAssets。

---

### V5 · username 登录机制改版：服务器判新老 + 登录页 + 登出（KAN-109，🚧 代码+测试完成待真人验收，2026-07-15）

**需求与决策（用户拍板）**：玩家先输 username，**服务器查库**判新老（不再看客户端本地数据）——新玩家→选头像→新手引导，老玩家直进主界面；①开发阶段 username 裸登录不做凭证（顶号风险已知悉，E2 补）②username=游戏内昵称（全服唯一）③存量测试账号清空④V4-S1 device 匿名登录保留（客户端调用点注释、服务端 /v4/auth/login 仍挂载——正式上线"新设备直进引导"体验有意义）⑤设置加登出。

**服务端（零 migration！）**：身份复用 accounts `(provider, external_id)` 复合唯一键 → provider='name'/external_id=username，schema 保持 v8。新 `internal/auth/name.go`：`NameExists/FindByName/CreateByName`（建号事务=accounts+profiles 原子落库，昵称=username、头像注册时定）+ 三端点 `/v5/auth/{check-name,register,login-name}`（**JSON 请求 + 复用 pb LoginResp**，GM 端点同款先例，免双端 proto 重生成）+ `validateUsername`（复刻 KAN-71 宽度规则：中1/英0.5≤10）。登录 404=未注册、注册 409=重名、封禁 403 照旧。**测试**：unit（宽度边界 10全角/20窄字符/控制字符）+ integration 真 PG（七步全链：check新→登录404→注册→profile对帐(昵称=名/头像/引导未做)→重名409→check老→登录 is_new=false + device 登录仍通）。docker 共享镜像重建、api/gateway/battle 重启、healthz 200；**存量数据已 TRUNCATE**（8 表 RESTART IDENTITY）。

**客户端**：`net/auth.gd` 加 `username` 凭据（auth.cfg 记住我）+ `check_name/login_name/register_name`（`_post_json`→pb LoginResp 解析复用）+ `has_credentials`，logout 连 username 一起清（device_id 保留）；`net/session.gd.ensure` device 自动登录改为「无凭据即失败 + 有凭据静默 login_name 重登」（device 调用注释保留）+ 门面五件套；`net/online_runtime.gd.ensure` 加 needs_login 早退（SIGNED_OUT）+ `login_with_name/register_with_name/sign_out`（登出=清凭据+close 持久连接+状态复位；本地经济缓存不清，下账号登录被服务器快照整体覆盖）。**新场景 `view/login.tscn`**（Router 登记 "login"）：输名→宽度预检→check-name→老将直登/新名携参进创号页；`account_create` 双模式（注册模式=名号固定只选头像→`register_with_name`，旧起名+update_identity 模式保留兜底）；`main_menu._bootstrap` 无凭据→login 重定向；`settings` 登出按钮+Modal 确认框（UI.modal 层，KAN-97 规约）。

**踩坑 P0（真人首验即中，2026-07-16）**：新流程创号页在**登录之前**打开，而卡牌配置是登录后才经会话 WS 下发（ConfigPush）→ 注册模式头像池空网格、确认永远禁用（"卡死"）。旧流程先登录后创号故从未暴露；网络层烟测/单测未覆盖"场景在无配置态的组合"是真空档。修复 = 创号页注册模式配置为空时回退**本地 cards.json 纯展示枚举**（决策48 双端同源镜像；头像值仍服务器落库，经济/玩法权威不动，E1 门禁扫描列表外的合规例外）+ 头像池抽纯函数 `avatar_pool_for` + 回归测试锁"空配置也必须有 30+ 头像"（416/416）。

**验证**：Go build/vet + 全套 unit/integration（-p 1 真 PG）全过；客户端 **416/416**（+3：username 持久化/logout 清凭据/needs_login 门三态）；gdlint 绿；headless 导入 0 错；**客户端真代码烟测 PASS**（临时 harness 打真 docker：注册→判老→记住我重登→404 拒绝，用完即删；踩坑=SceneTree `_init` 期发 HTTP 必挂，须先 await process_frame，仅 harness 问题）。真人 F5 验收欠：全新进登录页/新名一条龙/登出换号/老名直进/记住我重启/非法名禁入。

---

### V5 · E2-lite：HTTPS/WSS 加密模板 + secrets 模板化 + 发布手册（KAN-110，✅ 代码+冒烟完成，2026-07-16）

**背景与拍板**：用户计划 master→release→Antigravity→GCP 公网发布（域名只发有限测试人员）。E2 五件套中 ①去GM/②登录凭证/⑤Origin限流 明确暂不做（风险接受）；③WS ticket 不做（TLS 后 token-in-URL 的暴露面只剩自家反代日志 → 以 Caddy query 脱敏替代，成本≈0）；**只做④加密**。架构决策：**基础设施代码进 master（模板化、零环境值），环境专属值到 release/部署侧 .env**——保住 release 单向跟随 master 的分支流。

- **`server/docker/Caddyfile.prod`**：单域名单 443 反代模板——`/v4/battle/ws`+`/v5/session/ws`→gateway:8081、其余→api:8080（两服务路径不重叠）；Let's Encrypt 自动签续；访问日志 JSON + **query 整体脱敏为 REDACTED**（WS token 在 query，勿删此段）；DOMAIN/ACME_EMAIL 全环境变量占位，DOMAIN=localhost 自动降内部自签 CA（本地冒烟模式）。
- **`server/docker-compose.prod.yml`** overlay：`-f -f` 叠加式启动，加 caddy 容器（证书卷持久化防续期风暴）+ 全员 restart:unless-stopped；不带 overlay = 原样开发环境零影响。基础 compose 发布的 8080/8081/5432/6379 靠 GCP 防火墙收口（只开 80/443）。
- **`.env.example` 强化**：五处 ⚠️公网必改 标记（PG 密码/DB_URL/JWT_SECRET/DOMAIN/ACME_EMAIL）+ 生成命令；真值只存部署机 .env 永不进仓库。
- **[docs/deployment/GCP_RELEASE_TLS.md](docs/deployment/GCP_RELEASE_TLS.md)**（详细手册，后续会话/Antigravity 免上下文可操作）：架构图/前置条件(域名A记录+防火墙清单)/部署步骤/部署后验证命令/**release 打包检查单**（network.json 三地址单域名规范、安卓免 cleartext=方式B兑现、Godot 对 LE 证书零配置）/日常运维速查/本地冒烟模式/**安全边界声明**（E2-lite≠完整E2，升级触发条件写明）。
- **本地冒烟 4/4 过**（DOMAIN=localhost + 8443，不扰动开发 6 容器）：①`https://…/healthz` 200 ②WS 路径路由至 gateway（401=网关收到无 token 拒绝，路由正确）③check-name JSON 经 TLS 正常 ④URL 里塞假 token → 访问日志 grep 无原文、REDACTED 计数 1（脱敏实证）。冒烟容器即起即删。
- 纯基建+文档，客户端零代码改动（Godot 原生 https/wss，release 只改 network.json）；服务端 Go 零改动。Jira KAN-110 In Progress → 待用户确认。

---

### V5 · 首批正式 BGM 接入：菜单/战斗轮播/选卡三组曲 + AudioManager 轮播集（✅ 真人听验通过，2026-07-16）

**素材（testAssets/audio 五首 mp3，用户 0716 提供）**：Snowland→主菜单默认曲（登录/创号/基地/图鉴/卡详情/闯关地图共用 music_main_menu）；Sauropod Spotting + Dentaneosuchus Hunt→战斗双曲**轮番随机播放**（music_battle_normal + 新 music_battle_hunt）；Heroic Demise (New)→战前选卡上阵曲（新 music_deck_prep，PVE 上阵/天梯选卡组共用）；**The Britons 未派用场留 testAssets**。四首改蛇形名入 sound/bgm/（mp3 原格式，Godot 原生支持）；旧两首占位曲（Oriental wav/battle ogg）删除。
- **配置管线**：audio_assets.json 改 2 条 + 新增 2 条（79→81）；战斗双曲 **loop=false 刻意为之**（曲终触发轮播换曲，effect_notes 写明勿改回）→ `build_audio_config.py --from-json` 重建 xlsx + `--check` 一致。
- **AudioManager 轮播集**：新 `play_music_set(ids)`（随机起播；同集在播幂等不打断——「再来一局」重入不断音乐）+ `_on_music_finished` 集内随机换下一首（不重复当前）+ `play_music/stop_music` 清集回单曲语义；选曲候选抽纯函数 `next_in_set`（静态，单测锁：排除当前曲/单曲集退化自身）。
- **接线**：battle_scene 普通战→轮播集，boss 关保留专属曲意图（music_battle_boss 素材未到位时自动落轮播）；net_battle_scene 同轮播集；deck_builder `_ready` 起 music_deck_prep。
- **验证**：客户端 **418/418**（+2：轮播纯函数 / 四曲条目-文件存在-loop 语义）；gdlint 绿；headless 导入 0 错。**真人听验通过（2026-07-16）**：菜单/选卡/战斗三处切曲、轮播换曲、再来一局不断音全过。已提交（4a274d1）并按铁律 restart verifier（动了 config/）。

### V5 · PVP 场景视觉补课：三国塔/整图 BG/32×32 格/Y-sort 同步进 net_battle_scene（🚧 代码+测试完成待真人验收，2026-07-18）

**背景**：0713~0716 的视觉改造（KAN-107 屏幕格 / KAN-93 三国正式素材 / Y-sort 伪深度 / 0715 单位特效）只进了单机 `battle_scene`，PVP `net_battle_scene` 还在用最老的贴图（building1/6 旧塔、16px 拼贴地形、无 Y-sort），「兵在河上走」观感即此。本步纯 view 层把差异全部移植，逻辑层/lockstep 零改动。改动仅 `view/net_battle_scene.gd` 单文件：

- **KAN-107 屏幕格**：`_field_rect` 换 32×32 正方形格 letterbox 版（格边长取整、两侧装饰边栏露深底），与单机同款；`_t2s/_s2t` 契约不变。
- **整图 BG**：`TEX_BATTLE_BG` 特征对齐（双桥中心定 x 缩放 + 河中心锚 y 反解源矩形 + 铺满全屏 `_bg_full`）移植竖版分支；**`_flip` 不参与 BG**（场地河/桥对称，双方视角贴同一张图）；旧逐格 tile 铺法保留为 `BG_ENABLED=false` 回退（`_draw_terrain_tiles`）。
- **三国分色塔**：四张 sanguo_tower 贴图按**屏幕语义**选色——本方（恒下半场，`_flip` 已保证）= 蓝、敌方 = 红；`_tower_anchor` 视觉半格偏移换算成屏幕语义（下半场王塔/上半场箭塔各上移半格对齐 BG 路环）；natural 轻染 0.22 + 宽度系数 0.95/0.85 与单机同参。
- **Y-sort 伪深度**：`_draw_towers`+`_draw_units` 合并为 `_draw_world` 单通道（塔+单位按接地线升序、空军恒最上层），与单机 0715 二验同款。
- **0715 单位特效体系**：脚下椭圆影（×2 叠加、base_scale 基准）/ natural 轻染 / mirror 朝向（`_face/_facex`，判定全用屏幕 x → `_flip` 视角自动正确）/ 攻击刀光（近战冷却上升沿，镜像判定用屏幕 x）/ 受击星芒（`_on_hit` 加 unit_id 参数）/ 死亡白烟（`_ulast` 消失检测）。
- **屏幕方向语义修正**：塔伤害数字锚点与塔箭口原来写死 `-y`（side2 翻转视角下会朝屏幕下方偏），统一改 `_screen_up_tiles()`（`_flip` 时逻辑 +y = 屏幕上）。
- **验证**：客户端 **418/418** 零回归；gdlint 绿。**真人双端验收欠着**（需两浏览器/两机对局肉眼看：塔素材/BG 对齐/Y-sort 遮挡/side2 翻转视角下特效方向），验完随 KAN-76 验收一并处理。

### V5 · 主界面 CR 式改版：布局/交互按新版示意图落地 + 入口改名配 icon（✅ 真人实机验收通过，2026-07-18，KAN-111）

**依据**：0715 UI 系统策划的主界面示意图 [docs/design/ui_mockups/main_menu_cr_style.html](docs/design/ui_mockups/main_menu_cr_style.html)（用户已评审通过）。本步只做**布局与交互**，全部视觉为 PixelUI 占位（灰阶/像素框 + 程序化像素 icon），正式卡通手绘资源到位后再换皮。改动 `view/main_menu.gd` 重写 + 新增 `view/ui/menu_icons.gd` + 三处返回键改道：

- **新结构**（替换旧「六按钮列表」）：①顶部 = 名片横幅(左，复用 HudWidgets.nameplate) + 货币行(右，wallet_bar 接 EconomyStateCache) + 公告(灰占位)/设置小钮；②左右活动轨 = 左挂机金库（有待领显示 +N 金币、点击直接 collect_idle 领取）/ 右探险灰占位；③中央章节主视觉占位（显示当前章「第 N 章」，整块可点进闯关地图）+ 闯关总进度条(已通关数/总关数)；④底部操作大簇（0718 定稿改名）= **布阵**(原卡组，角标=卡组张数) | **国王征途**(原闯关，金色主 CTA，副标=下一关 章-关) | **对战**(天梯，副标=杯数)；⑤底部五页签（0718 定稿改名）= 商店(灰) 卡牌 **王国**(灰·待开发) **宫廷**(灰·待开发) **外交**(灰·待开发)——旧「对战/闯关/探险」页签职责下沉到中排大簇。
- **入口 icon**（`view/ui/menu_icons.gd` 程序化像素占位，零贴图、16 网格 draw_* 原语）：布阵=3×3 阵型点 / 国王征途=军旗 / 对战=交叉双剑 / 商店=钱袋 / 卡牌=叠卡 / 王国=城堡 / 宫廷=王冠 / 外交=卷轴国书。`_entry_button` 统一装配（icon 居中 + 下方文字，金按钮深墨字、其余羊皮纸字）；待开发页签整体 modulate 压暗。正式 icon 素材到位后换 TextureRect、本组件退役。
- **数据接线**：进菜单后 `EconomyStateCache.refresh` + `Events.economy_changed` 订阅回填（钱包/挂机/进度/角标全服务器快照，决策 48）；拉取失败离线降级（钱包 0/挂机禁用/进度提示离线），登录门/创号门/引导门流程不动。
- **基地页(base_camp)废弃下线**（策划定论：挂机并入活动轨、进度并入章节主视觉）：主菜单不再有入口；`stage_map`/`card_collection`/`deck_builder(edit)` 的返回键从 base_camp 改道 main_menu。场景与路由保留未删（回滚成本低，待新版稳定后再清理）。
- **登录期 UI 收进 `_boot_ui` 容器**：标题/状态文案在菜单建成时整体移除（新版主界面无大标题，导航职责在页签+大簇）。
- **验证**：客户端 **418/418** 零回归（含 test_online_runtime 服务器配置规约/test_scene_router 路由规约）；gdlint 绿。**真人实机验收通过（2026-07-18）**：五区布局/挂机领取/各入口跳转与返回/离线降级/入口改名+icon 全过。正式卡通 UI 资源仍欠账（占位 → 换皮，随主美 P0 mockup）。

### V5 三国改版 · A4 世界观文本 + 遭遇扩容/奖励回填（🚧 代码+配置+测试完成待真人验收，2026-07-19，KAN-93）

A4 三块中的两块（素材分批接入等美术图，另行推进）。修掉「32 张新卡 PvE 零曝光零获取」断层 + 100 关三国时间线章节化：

- **章节三国化**：`stages_spec.json` 10 章改名 黄巾之乱→虎牢讨董→群雄割据→官渡之战→荆州风云→赤壁之战→汉中争锋→荆襄烽火→夷陵之火→三分天下；`i18n.json` 新增 `chapter_1..10`（zh/en），主菜单章节主视觉与闯关地图章头显示「第N章 · 章节名」。教程 4 条文案三国化叙事（**「圣水」术语保持不动**——改术语是全 UI 级决策另议）。
- **遭遇模板扩容 15→27**（`encounters.json` +12 个阵营主题模板）：黄巾人海/张角术法（群雄）、铁壁·寒计·汉中先锋（魏）、山道伏兵·孔明天灯（蜀）、水寨·火船·守御（吴）、南蛮火鸢巢、终章三家无双合流；10 章 encounters/boss 全部按时间线×阵营重排（32 张新卡全部进入敌方卡组曝光）。
- **奖励池回填全 48 卡**：spec 每章 `shard_card` 单卡 → `shard_cards` 轮转池（4~5 张/章，稀有度升序；非 boss 关按 index 轮转、boss 关发池尾压轴卡），`build_stages.py` 生成器同步改 + 校验；10 章合计**覆盖全 48 卡**（旧口径仅 8 张旧卡）。`--check` 过、重生成 `stages.json`。
- **回归锁 +2**（`test_v5_stages_content`）：①100 关奖励并集 == 48 卡全池（断层不复发）②i18n chapter_1..10 zh/en 齐全且 zh 与 spec 章名一致。
- **验证**：客户端 **420/420**；gdlint 绿；Go economy/gameconfig `-count=1` 过；按铁律 restart api+gateway+verifier、healthz ok。**真人验收欠**：闯关地图章名/新遭遇对局/新卡碎片掉落入账；游戏名 2026-07-19 用户拍板 = **《乱世推塔》**（en: Warring Towers）：i18n app_title/app_subtitle（副标「三国乱世 · 推塔对战」）+ project.godot 窗口名 + 主菜单登录页大标题改走 tr("app_title")，全库无 CLASH PUSHER 残留。

### V5 · 王国领地系统 K0~K2：城建经营 + 城防养成新维度（🚧 代码+双端测试完成待真人验收，2026-07-19）

**设计**：[docs/DESIGN_KINGDOM.md](docs/DESIGN_KINGDOM.md)（用户已拍板四原则：①对战维度=塔 ②金币不可买城建资源 ③卖时间不卖上限·上限全服统一·节奏运营/策划控 ④**服务器权威为永久原则**，客户端只收发+表现）。K0~K2 一次交付，K3 挂机整合/K4 PVE 塔加成/K5 PVP 下发/K6 IAP 后续分期。

- **K0 配置**：`config/kingdom.json`——7 建筑（王城/农田/工坊/粮仓/城墙/箭楼/铸币坊）逐级显式数值表（等级/成本/时长/产出/城防 pct，全〔示意〕；策划直接改表控节奏）；王城 10 级绑章节门（LvN 需通关第 N-1 章）、非王城上限=王城×2；**成本禁 gold**（商业化铁门：城防只能时间或宝石）。gameconfig bundle 自动收录 → 服务器结算与客户端下发同源（17 文件，版本 hash 自动 bump）。
- **K1a proto**：`proto/kingdom.proto`（ResourceAmount KV 避 map/跨文件坑，新资源零 proto 改动）+ common.proto MsgId 70~74；本机补装 protoc/protoc-gen-go，双端重生成（Go pb + godobuf .gd），Makefile PROTO_NAMES 收录 kingdom。
- **K1b 服务端**：migration `0009_kingdom`（kingdom_state.resources **JSONB 可扩展** + kingdom_buildings 配置键文本主键——用户要求的养成/货币经济扩展性）；`internal/kingdom/`：config 解析校验（keep 必在/等级表连续/成本禁 gold）+ repo（事务骨架=播种→锁读→**到点懒完级**→动作→落库；服务器时钟结算产出；升级=资源扣减+计时，王城章节门查 economy highest_cleared，加速=宝石定价 ceil(剩余×费率)，收取=入仓封顶+铸币金进主钱包）+ handler `/v5/kingdom/{state,upgrade,collect,speedup}`（错误码复用 economy 族）。**Go 测试**：纯函数单测（产出封顶/加速定价/仓库封顶）+ 真 PG 集成测试（播种/升级/加速/王城门/章节门/收取）全过；全服务端 suite 零回归。
- **K2 客户端**：`net/kingdom_client.gd`（pb HTTP）+ `net/kingdom_state_cache.gd`（EconomyStateCache 同款范式：非权威缓存 + `Events.kingdom_changed` 收口广播 + E1 fail-closed guard 接线进 OnlineRuntime）；ConfigLoader 收录 kingdom.json（镜像服务端校验规则）；`view/kingdom.tscn/gd` 王国页；Router 登记 `kingdom` 路由、主界面「王国」页签点亮。**同日按用户反馈场景化重做**（验收 1 过后拍板：要 SLG/4X 式主城，不要按钮列表）：battle_scene 同款纯 `_draw` 即时渲染——Lonesome 地形铺底 + L 型石板路网 + 老中世纪 building1~8 建筑组落图（空地=虚线地皮/施工=半透明+倒计时牌/待收取=金色脉动气泡）+ **SpriteDB 走路小人 5 个巡游**（广场↔建筑门口随机漫步、方向定帧行+镜像、脚下影）+ 建筑/小人 Y-sort 伪深度；点建筑 → `view/ui/kingdom_building_modal.gd`（F1 规约经 UI.modal 推入：等级/效果/成本/倒计时 + 建造/升级/加速）；HUD（资源/钱包/城防/收取/返回）Control 浮层。正式三国城建美术后整体换皮。
- **验证**：客户端 **425/425**（+5：配置校验/建筑齐全/gold 禁门/城防曲线 60%·40% 回归锁/pb 回环）；gdlint 绿；Go 全过（含真 PG 集成）；docker 重建+0009 迁移+healthz ok、gateway bundle 17 文件。**真人验收欠**：王国页建造/升级/倒计时/加速/收取/王城门禁提示、主菜单页签跳转。**K4 前城防只显示不进战斗**。

### V5 · 王国 K3+K4：铸币坊接管挂机金库 + PVE 城防塔加成接线（🚧 代码+双端测试完成待真人验收，2026-07-19）

- **K3 挂机整合（单一产出源）**：铸币坊产率 = `economy.json idle` 章节曲线 × 铸币坊 `idle_mult_pct`（Lv1=100% 基线 → Lv20=290%，封顶沿用 `idle.cap_hours`）；mint 入初始建筑（新号挂机体验不变）。kingdom repo 事务内统一读 `highest_cleared` → 章节（王城门/铸币产率共用）。**economy `CollectIdle` 弃用去积累**（只刷新基准不发金，堵「王国+旧挂机」双份领取；集成测试改为弃用回归锁）。客户端主界面挂机金库活动轨切 kingdom 源（`kingdom_changed` 回填 pending_gold、领取走 `/v5/kingdom/collect` + 经济重拉同步钱包）。
- **K4 PVE 塔加成（对战维度首次生效）**：`PveStartResp` 新增 `tower_hp_pct/tower_dmg_pct`（服务器权威定值：`kingdom.TowerBonus` 读城墙/箭楼累计，含到点未懒结转的施工）；同值写进 `pve_battles.progress` 的 **`_towers` 保留键**（复用现有列零 migration）→ 重放验证器 progress 透传 → `pve_replay` 同源注入。`match.setup_stage` 加 `tower_bonus` 参数 + `scale_player_towers`（整数百分比乘法，只动我方三塔、敌塔照旧走关卡 coef；0=no-op 零回归）。economy↔kingdom 循环依赖用 main.go 注入回调解开。战斗日志打 `城防=+X%hp/+Y%dmg` 观察口。
- **测试**：客户端 **427/427**（+2：塔加成只作用我方/0 加成零回归；`_towers` 重放全等+缺键必分叉——实证塔数值进 state_hash 反作弊闭环）；Go 全量含真 PG 集成过（+3：mint 挂机曲线纯函数 / PveStart 写 `_towers`+零加成不写键 / CollectIdle 弃用回归）；**顺带修 A4 遗留**：ShardDrop 集成测试钉死 skeletons → 改配置驱动（A4 后 stage_1_2 掉轮转池新卡）。gdlint/gofmt 绿；docker 重建+verifier 重启。**真人验收欠**（随 K2 场景化一并）：铸币坊挂机领取入账、修城墙后打 PVE 我方塔变硬、验证器对带城防的对局 verdict=pass。

### V5 · 🐞 事故：集成测试清空开发库账号 + 重试门死角修复（✅ 已恢复+防再犯，2026-07-19）

**事故**：跑 Go 全量集成测试时 `INTEGRATION_DB_URL` 误指开发对局库 `gcp`——auth/profile/economy/kingdom 的 integration test 在 setup 里 `DELETE FROM accounts/profiles/economy_*`，把用户实机账号清掉 → 客户端 login-name 查无此人、卡重试门（用户验收时发现「连不上服务器」；服务端六容器实际全健康）。
- **防再犯**：建独立测试库 `gcp_test`（同 PG 容器，migrate 到 v9），集成测试改指 gcp_test 验证全绿；写入 agent 长期记忆（memory/integration-test-db.md）。
- **顺带修 UX 死角**：本地记着 username 但服务器查无此人时，客户端会永远卡重试门（重试门无登出口）。`session.ensure` 改：login-name 被服务器 4xx 明确拒绝 → 清本地凭据 → 路由回登录页重注册；5xx/超时保留凭据只重试。客户端 427/427。
- **用户恢复路径**：重进游戏 → 自动跳登录页 → 重新注册（进度已被清库丢失，GM 面板可快速刷回金币/宝石/章节进度）。

### V5 · 王国 GM 命令扩容（✅ 2026-07-19，随 K 线；用户无资源验收诉求）

设置页 GM 区扩 12 键三列布局：新增 **粮草 +5000 / 木石 +5000 / 完成王国施工（加速类总开关）/ 重置王国**（宝石沿用既有 economy GM）。服务端新 `POST /v5/kingdom/gm`（`internal/kingdom/gm.go`，镜像 economy GM 纪律：JSON 入/KingdomState proto 出、会话鉴权只改自己、`add_resources` 直加不走仓库封顶）；客户端 `kingdom_client/cache.gm_apply` + settings `__kingdom` 路由分支（成功后 kingdom_changed 广播，王国页/挂机口自动刷）。客户端 427/427、gdlint 绿、api 重建 healthz ok。

### V5 · 王国 K5：PVP 城防塔加成下发（🚧 代码+双端测试完成待两机真人验收，2026-07-19）

完全复用 KAN-76「权威下发 + 双端对称注入 + hash 对帐」管线：
- **proto**：`battle.proto` 新增 `TowerBonus{hp_pct,dmg_pct}`（文件内 message 避 godobuf 跨文件坑）+ `JoinRoomResp.side1/side2_towers`（字段 11/12；缺省=白板向后兼容；**重连重放同一 resp 自动带上**）。双端 pb 重生成。
- **服务端**：`Lobby.KingdomCfg` 可选注入（gateway main 从 bundle 解析装配，解析失败零加成不阻塞对战）；建房时 `lookupTowers` 复用 K4 的 `kingdom.TowerBonus`（含到点未懒结转施工计级）读双方城墙/箭楼 → `player.towers` → `joinRespFor` 双端同发；**建房日志埋 `def[+X%hp/+Y%dmg]` 观察口**（2026-07-02 口径③：匹配暂不加战力维度、日志先行观察）。
- **客户端**：`battle_client._handle_join_resp` 在养成注入后调 `match.scale_side_towers`（side1→player_towers、side2→opponent_towers 固定顺序；两端对同一方注入同一份服务器定值 → 逐 bit 一致）；`match.gd` 抽 `_scale_tower_list` 共用（K4 PVE 的 `scale_player_towers` 委托同实现）。
- **测试**：客户端 **429/429**（+2 lockstep 命门：同城防同输入逐 tick 哈希全等 / 异城防同指令必分叉——塔数值实证在 state_hash 内，对帐网抓得住 desync/作弊）；Go battle 单测 `TestJoinRespCarriesTowerBonus`（含重连重放）+ 真 PG+Redis 集成 `TestLobby_JoinRespCarriesTowerBonus`（墙5/楼5 → +15%hp/+10%dmg、无王国方 nil）全过；集成测试跑在 **gcp_test 隔离库**。gateway 重建（log：kingdom tower bonus wired into lobby）。
- **真人两机验收欠**（并入 KAN-76 验收台账一起跑）：双端对局塔血肉眼一致、建房日志 def 对帐、全程无 hash mismatch、断线重连不丢城防。

### V5 · 防作弊体系盘点 + PVE 减速残余风险挂账（📋 文档+建单，2026-07-19，KAN-113）

用户加速器提问触发的体系盘点，沉淀 [docs/SECURITY_ANTICHEAT.md](docs/SECURITY_ANTICHEAT.md)（三套子系统三种防法：资源=服务器时钟 / PVP=双端 hash 对帐·节拍服务器驱动 / PVE=证据链+verifier 重放；"进战斗的新数值维度必须交两条 lockstep 测试"成文为规）。**结论：资源/PVP/PVE 加速均免疫或当场拦截；PVE 减速为低危残余风险**（墙钟校验刻意单向 ≤，减速打星变容易、重放抓不到）→ 建 **KAN-113**（待办）记对策选项（批次节奏分析优先，纯日志观察零误杀起步），不阻塞上线工程线。

### V5 · 0721 正式素材大批次：王国建筑/战斗塔+地图/5 角色帧动画（✅ 真人验收通过，2026-07-21，KAN-93/KAN-112）

素材源 = `testAssets/7.21.2026/`（王国领地 10 图 / 战斗场景 8 图 / 角色战斗动画 5 角色 20 图），Python 重打包管线同 KAN-104（谷切→碎段合并→脚线锚定/整高保留→单行帧条，脚本存 session scratchpad）：

- **王国领地换皮（KAN-112 视觉线）**：7 建筑正式图进 `assets/kingdom/`（palace→王城/farmLand→农田/factory→工坊/defenseTower→箭楼/foodStock→粮仓/coinMaker→铸币坊/wallGate→城墙），`kingdom.gd` BUILDING_TEX 整表切换 + 铸币坊槽位 130→175；新增 4 棵装饰树（3 图复用、Y-sort 参与、不可点）。注意：未建造建筑（Lv0）显示空地虚线框是设计行为，不是图没导入。
- **战斗塔 + 地图（并入 KAN-76 视觉线）**：4 塔换我/敌专属正式图（`sanguo_tower_{king,arrow}_{mine,enemy}.png`），**摧毁态接正式废墟贴图**（王塔破分敌我、箭塔破共用）且改为「地面贴花」——不进 Y-sort、先于一切单位绘制，单位可踩废墟不被遮挡；战场 BG 换绿地图（`battle_bg_green.png` 720×1560），桥/河特征对齐值脚本实测重标（桥1 x=160/桥2 x=543/河 y=768=桥板垂直中心）。单机+PVP 两场景同步。
- **角色帧动画 5 组（KAN-93 素材线；占位 ph 31→28）**：
  - 虎贲校尉（knight_body）美术更新版：走 10 帧 160² 脚线 y158 / 攻 8 帧 200² sc=1.25 / 新刀光 3 帧；受击/死亡/立绘沿用 0715。
  - 江东机关蜂（bat_body=黄蜂素材）：走 10/攻 7 帧 128²，飞行整高裁切保留悬浮起伏；scale 2.6（验收反馈调大）。
  - 黄巾攻城力士（giant_body）：走/攻各 12 帧（192²/256² sc=1.333 脚线锚定）；冲击波环 5 帧翻转成朝左规范做攻击命中特效。
  - 蜀汉火脉机关龙（inferno_dragon_body）：walk 10/attack 7 帧 272²；新增**龙火弹道**（3 帧、朝向镜像）+ 落点爆花 7 帧。
  - 刘晔霹雳车（royal_giant_body）：炮车正/背双行静帧（row/row_up）；新增**翻滚石弹弹道** + 弹着爆花 6 帧；「攻击.png」火焰爆炸判读为死亡特效（机关车炸毁）；**frame() 新增 face_up 朝向覆写**——攻击时炮口按目标屏幕方位转正/背面（验收反馈）。
  - 通用命中星芒 5 帧 = 4 新角色共用 hit 特效。
- **工程顺手**：投射物绘制两场景重复代码收口 `SpriteDB.draw_projectile`（arrow/bolt/fireball/stone/dragonfire 五类，battle_scene 借此降回 1486 行）；投射物系统新增**落点爆花**能力（弹道 dict 带 impact fx，到点在剔除前恰好触发一次）。
- **测试**：客户端 **429/429**（test_sprite_db 同步：占位 28、knight 攻击帧 200²/sc1.25/scale1.7）；gdlint 绿。验收：王国页/战斗地图塔/角色动画真人通过（黄蜂尺寸与炮口朝向两条反馈已修）。

### 运维 · Web 前端域名更替（📌 环境事实，2026-07-21）

**旧 Firebase 前端 `towerpush.web.app` 弃用，项目已整体删除**；现行 Web 前端 = **`https://tower-push-godot.web.app`**（后端不变 `towerpushserver.jeffgame.tech`）。历史文档/交接/HISTORY 里出现的旧地址一律作废。权威地址记录在 [docs/deployment/GCP_RELEASE_TLS.md](docs/deployment/GCP_RELEASE_TLS.md) 文件头；本批（0721 素材+王国系统）已由 Antigravity 部署至新地址（部署侧记录归 release 分支「发布与打包」附录）。
