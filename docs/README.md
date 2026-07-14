# docs/README.md — 全仓文档地图

> **用途**：全部文档的一行式索引（是什么/什么状态/何时读），agent 与人的检索总入口。**新增文档必须在此登记一行**（规约见 [engineering/AGENT_SHARED_RULES.md](engineering/AGENT_SHARED_RULES.md)「共享文档维护」）。
> 真相源优先级：用户指令 > PLAN > HISTORY.md + Jira > 操作手册 > 归档。

## 根级（agent 必读入口）

| 文档 | 一句话 | 状态 |
|---|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Claude Code 操作手册（纪律/铁律/工具链/工作流） | 🟢 活跃 |
| [../AGENTS.md](../AGENTS.md) | Codex 等其他智能体操作手册（与 CLAUDE.md 同口径） | 🟢 活跃 |
| [../HISTORY.md](../HISTORY.md) | **进度真相源**：总览表 + 决策日志 + 当前阶段逐步（已收官段见下方归档） | 🟢 活跃·只追加 |
| [../PLAN_GRAND.md](../PLAN_GRAND.md) | 全项目 roadmap（V1→V5→V6+） | 🟢 活跃 |
| [../PLAN_V5.md](../PLAN_V5.md) | **当前阶段权威规划**：在线 F2P 闯关养成 + 上线工程线 E0~E9（§13） | 🟢 活跃 |
| [../PLAN_V5_SANGUO.md](../PLAN_V5_SANGUO.md) | 三国题材改版轨道A 施工图（A1~A4） | 🟢 活跃（A4 进行中） |
| [../PLAN_V5_HBATTLE.md](../PLAN_V5_HBATTLE.md) | 横版战斗施工图（H1~H6） | 🟡 H1/H2 完，H3~H6 未开工 |
| [../PLAN_V5_UIFRAME.md](../PLAN_V5_UIFRAME.md) | UI 层级骨架改造施工图（F1~F3） | 🟡 代码全完，欠 F 组真人验收 |
| [../README.md](../README.md) | 仓库门面（对外简介） | 🟢 |

## 已收官规划（存档备查，不再更新）

| 文档 | 一句话 |
|---|---|
| [PLAN_V1.md](PLAN_V1.md) / [PLAN_V2.md](PLAN_V2.md) / [PLAN_V3.md](PLAN_V3.md) | V1 机制白膜 / V2 3-lane+换皮 / V3 2D 战斗 reboot 各阶段规格 |
| [PLAN_V4.md](PLAN_V4.md) | V4 联网升级 + 实时对战（S0~S4 收官，S5 暂缓） |
| [PLAN_V5_S9_ACCOUNT_UX.md](PLAN_V5_S9_ACCOUNT_UX.md) | V5-S9 账号身份 + 引导/菜单改版（真人验收过） |

## 历史归档（只查证、不追加）

| 文档 | 一句话 |
|---|---|
| [HISTORY_ARCHIVE.md](HISTORY_ARCHIVE.md) | V1/V2 详细逐步历史 |
| [HISTORY_V3_DETAILED.md](HISTORY_V3_DETAILED.md) | V3 详细逐步历史 |
| [HISTORY_V4_DETAILED.md](HISTORY_V4_DETAILED.md) | V4 详细逐步历史（S0~S4） |
| [HISTORY_V5_DETAILED.md](HISTORY_V5_DETAILED.md) | V5 **已收官子步**详细段（S0~S7+/N1~N7/卡池/框架地基#2~#4 等；子步收官后随手搬入） |

## 上线工程契约（E0 产出；`tools/check_docs.py` 门禁校验）

| 文档 | 一句话 |
|---|---|
| [engineering/AGENT_SHARED_RULES.md](engineering/AGENT_SHARED_RULES.md) | 智能体共享规则真相源（AGENTS/CLAUDE 镜像块的母本） |
| [engineering/MEEGLE_WORKITEM_GUIDE.md](engineering/MEEGLE_WORKITEM_GUIDE.md) | 飞书项目(Meegle) CLI/MCP 建单通用避坑指南（必填角色卡点、模板ID查法、字段格式协议） |
| [architecture/ONLINE_RUNTIME_CONTRACT.md](architecture/ONLINE_RUNTIME_CONTRACT.md) | 在线运行时边界（强制登录/断线行为/离线训练边界） |
| [architecture/GATEWAY_STATE_MODEL.md](architecture/GATEWAY_STATE_MODEL.md) | Gateway 状态所有权表（外置前单活） |
| [architecture/CONFIG_AUTHORITY.md](architecture/CONFIG_AUTHORITY.md) | 配置权威分层（服务端 bundle 为在线权威） |
| [adr/0001-single-active-gateway.md](adr/0001-single-active-gateway.md) | ADR：单活 Gateway（Accepted） |
| [adr/0002-server-config-authority.md](adr/0002-server-config-authority.md) | ADR：服务端配置权威（Accepted） |
| [adr/0003-offline-training-boundary.md](adr/0003-offline-training-boundary.md) | ADR：生产主流程不离线降级（Accepted） |
| [security/THREAT_MODEL.md](security/THREAT_MODEL.md) | 威胁模型（客户端/网络/提交字段全不可信） |
| [security/AUTH_AND_WS_TICKETS.md](security/AUTH_AND_WS_TICKETS.md) | 认证契约（短 access/refresh rotation/WS 单次 ticket——E2 目标态） |
| [deployment/STAGING.md](deployment/STAGING.md) | Staging 目标拓扑（当前 compose 仅本地开发） |
| [deployment/PRODUCTION_GATES.md](deployment/PRODUCTION_GATES.md) | **上线门禁清单**（P0/P1 未过不得发布；含当前已知阻断） |
| [runbooks/GATEWAY_DRAIN.md](runbooks/GATEWAY_DRAIN.md) | Gateway 排空 runbook（drain 代码待 E4） |
| [runbooks/ROLLBACK.md](runbooks/ROLLBACK.md) | 回滚 runbook |
| [runbooks/INCIDENT_RESPONSE.md](runbooks/INCIDENT_RESPONSE.md) | 事件响应 runbook（SEV 分级 + 首十分钟） |

## 真人验收台账（欠账集中地）

| 文档 | 一句话 | 状态 |
|---|---|---|
| [ACCEPTANCE_SANGUO.md](ACCEPTANCE_SANGUO.md) | **验收欠账总台账**：三国化 A~F 六组 + 跨线索引 | 🔴 多组欠验收 |
| [ACCEPTANCE_V5_S8.md](ACCEPTANCE_V5_S8.md) | S8e 100 关难度曲线手感（KAN-59） | 🔴 欠验收 |
| [ACCEPTANCE_V5_PVP_PROGRESSION.md](ACCEPTANCE_V5_PVP_PROGRESSION.md) | PVP 养成同步两机验收（KAN-76/77） | 🔴 欠验收 |
| [ACCEPTANCE_V5_PVE_ANTICHEAT.md](ACCEPTANCE_V5_PVE_ANTICHEAT.md) | PVE 反作弊验收（KAN-78/79） | 🔴 欠验收 |
| [ACCEPTANCE_V5_S7.md](ACCEPTANCE_V5_S7.md) | S7 UI 整合验收（KAN-58） | ✅ 全过 |
| [ACCEPTANCE_V5_KAN49.md](ACCEPTANCE_V5_KAN49.md) | 联机视觉对齐双机验收（KAN-49） | ✅ 全过 |

## 设计 / 美术 / 平衡

| 文档 | 一句话 |
|---|---|
| [design/GDD.md](design/GDD.md) | **游戏策划总案（给人读）**：世界观/机制/系统/数值/路线图，测试·策划·程序·美术通读入口 |
| [design/01_research.md](design/01_research.md) ~ [design/04_awakenings_meta.md](design/04_awakenings_meta.md) | 卡池 16→48 设计四部曲（调研/宪法/卡库/觉醒） |
| [design/HANDOFF_next.md](design/HANDOFF_next.md) | 卡池扩充交接便签 |
| design/card_art_spec_48cards.xlsx | 48 卡美术规格表（三国版，美术真相源） |
| design/scene_system_art_spec.xlsx | 场景/系统美术清单（A3 产出，待评审 KAN-92） |
| design/battle_bg_template_576x1024.png | 战场背景出图规格模板（KAN-107 起 32×32 正方形格；完整规格书在飞书） |
| design/ui_mockups/ | UI 改版 HTML 示意图集（720×1560 画布+安全区线；配套飞书《UI 系统策划案》；预览 `.claude/launch.json` 的 ui-mockups 服务或直接开 html） |
| design/card_progression_design_doc.html | 卡牌升级/升阶系统策划案（HTML 单页） |
| [ART_ASSETS.md](ART_ASSETS.md) | 美术圣经（单位帧网格/塔/FX/地形 as-built，V3 定稿） |
| [DESIGN_V5_S7_UI.md](DESIGN_V5_S7_UI.md) | S7 UI 整合设计稿（已施工完，存档） |
| [BALANCE_V5_S8.md](BALANCE_V5_S8.md) | S8d 平衡报告（AI-vs-AI 局限 + 曲线形状验证） |

## 环境 / 杂记

| 文档 | 一句话 |
|---|---|
| [ENVIRONMENT.md](ENVIRONMENT.md) | 环境搭建 + MCP 安装注册 + 画面验收协议 |
| [V4_S3_g_real_machine_test.md](V4_S3_g_real_machine_test.md) | V4-S3g 两台真机对战测试记录（存档） |
| [NOTE_image_gen_mcp_pipeline.md](NOTE_image_gen_mcp_pipeline.md) | AI 生图素材管线（§7 已实战：骑士攻击帧 banana 出图+确定性后处理+入库全记录） |
| [../net/README.md](../net/README.md) / [../server/README.md](../server/README.md) | net 层 / Go 服务端模块内说明 |
