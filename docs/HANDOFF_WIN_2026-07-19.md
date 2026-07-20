# 项目交接：Mac → Windows 接续（2026-07-19）

> **用途**：从 Mac 换回 Windows 继续开发时，把本文件整篇喂给 Windows 上的 coding agent，
> 环境差异 + 本轮进度一次交接完。写作时仓库真相源 = `origin/master @ 本文件所在 commit`
> （前一条为 `c9be26c` 防作弊文档）。若与 HISTORY.md 对不上，以 HISTORY.md + Jira 为准。
> 上一份反向交接（Win→Mac）见 [HANDOFF_MAC_2026-07-16.md](HANDOFF_MAC_2026-07-16.md)。

## 第一步：先读三份文档（协作纪律不变）

1. `CLAUDE.md`（最高优先级：一步一确认、用户说"提交"才 commit+push、表现层验收交真人）。
2. `HISTORY.md`（进度真相源——本轮新增 2026-07-18/19 的 8 个条目，务必读完）。
3. `docs/README.md`（文档地图；本轮新增 `DESIGN_KINGDOM.md`、`SECURITY_ANTICHEAT.md`）。

⚠️ Windows 命令翻译提醒（与 Mac 相反方向）：`CLAUDE.md` 工具链段的 godot 命令是 Mac 原生
（`HOME=/private/tmp/godot-home godot ...`）；Windows 上用你机器的 godot_console 路径、
HOME 隔离可省略。根 `Makefile` 的 `GODOT` 默认值本来就是 Windows winget shim，直接可用。

## 第二步：环境自检

```bash
git pull                       # 拉到本文件所在 commit
godot --version                # 4.6.3.stable
cd server && docker compose up -d --build && docker compose run --rm api /usr/local/bin/migrate
curl http://localhost:8080/healthz   # ok；docker compose ps 应 6 容器
# 客户端全量单测（Windows 版命令自行翻译 HOME 部分）——期望 427/427
godot --headless --path . --script res://tests/test_runner.gd
```

- **schema 已到 v9**（`0009_kingdom`：kingdom_state/kingdom_buildings）——老库必须重跑 migrate。
- **Go 工具链**：本轮服务端测试在宿主机跑（Mac 装了 go1.26 + protoc + protoc-gen-go）。
  Windows 机若没装，`winget install` 或照 `docs/ENVIRONMENT.md`；改 proto 才需要 protoc。
- ⚠️ **集成测试铁律（本轮事故教训，最高优先）**：`INTEGRATION_DB_URL` **必须指 `gcp_test` 库**，
  绝不能指开发库 `gcp`——auth/profile/economy/kingdom 的集成测试 setup 会 `DELETE FROM accounts`
  等表，2026-07-19 已实锤把用户开发账号清掉过一次。Windows 的 PG volume 是另一份，
  **gcp_test 需要先建**：
  ```bash
  docker exec server-postgres-1 psql -U app -d gcp -c "CREATE DATABASE gcp_test;"
  docker compose run --rm -e DB_URL="postgres://app:dev@postgres:5432/gcp_test?sslmode=disable" api /usr/local/bin/migrate
  # 之后：INTEGRATION_DB_URL="postgres://app:dev@localhost:5432/gcp_test?sslmode=disable" go test -count=1 -p 1 ./...
  # battle 的 lobby 集成测试还需 INTEGRATION_REDIS_URL="redis://localhost:6379/1"
  ```
- MCP：Jira（Atlassian）与飞书项目（Meegle）在 Mac 会话已连通；Windows 环境需各自重配
  （见 `docs/ENVIRONMENT.md` 与 `docs/engineering/MEEGLE_WORKITEM_GUIDE.md`）。

## 本轮做了什么（2026-07-16 交接以来，按 commit 顺序）

1. **PVP 场景视觉补课**（`93b5351`）：net_battle_scene 补齐三国分色塔/整图 BG 特征对齐/
   32×32 屏幕格/塔+单位 Y-sort/0715 单位特效全套；side2 翻转视角的塔锚点/箭口改屏幕语义。
   **真人双端验收欠**（并入 KAN-76 台账）。
2. **主界面 CR 式改版 + 入口改名配 icon**（`f26773d`/`6f3d828`，**KAN-111 Done 已真人验收**）：
   五区布局（名片+货币行/挂机+探险活动轨/章节主视觉+进度/中排大簇/底部五页签）；
   中排 = 布阵/国王征途/对战，页签 = 商店(灰)/卡牌/王国/宫廷(灰)/外交(灰)；
   `view/ui/menu_icons.gd` 程序化像素 icon 占位；**基地页 base_camp 废弃下线**（场景保留未删）。
3. **三国化 A4 文本/遭遇/奖励 + 游戏名**（`c8cf28e` 前半，KAN-93 仍 In Progress——素材接入未做）：
   10 章三国时间线命名（黄巾之乱→三分天下，i18n `chapter_1..10`）；遭遇模板 15→27（32 新卡
   进敌方卡组）；奖励 `shard_cards` 轮转池**覆盖全 48 卡**（`build_stages.py` 生成器改造）；
   教程文案三国化；**游戏名定《乱世推塔》**（Warring Towers，i18n+窗口名+登录页标题）。
4. **王国领地系统 K0~K5 + GM**（`c8cf28e` + `f708786`，**KAN-112 In Progress 验收欠**）：
   - 设计 = `docs/DESIGN_KINGDOM.md`（用户拍板四原则：对战维度=塔/金币不可买城建资源/
     卖时间不卖上限/服务器权威永久）。K6 IAP 随支付线另排。
   - K0 `config/kingdom.json` 7 建筑逐级表；K1 `internal/kingdom` + migration 0009 +
     `/v5/kingdom/*`；K2 **SLG 场景化主城**（地形+路网+中世纪建筑落图+SpriteDB 小人巡游+
     点建筑弹 `kingdom_building_modal`）；K3 铸币坊接管挂机金库（economy `CollectIdle`
     弃用去积累，主界面挂机口切 kingdom 源）；K4 PVE 塔加成（`PveStartResp` 下发 +
     `pve_battles.progress` 的 `_towers` 保留键 + 重放验证器同源）；K5 PVP 城防下发
     （`JoinRoomResp.side1/side2_towers` + 双端对称注入 + lockstep 两条命门测试）。
   - 王国 GM：`/v5/kingdom/gm` + 设置页 GM 区 12 键三列（粮草/木石/完成施工/重置王国）。
   - **用户已验收**：王国页签进入 + 场景化主城交互 OK；其余项欠（见下）。
5. **防作弊体系文档 + 减速风险挂账**（`c9be26c`）：`docs/SECURITY_ANTICHEAT.md`
   （三套子系统三防法 + 加速器四攻击面盘点 +「进战斗新数值维度必交两条 lockstep 测试」成规）；
   PVE 减速残余风险 → **KAN-113**（待办，批次节奏分析优先）。
6. **事故与修复**：跑集成测试误清开发库账号（见上面铁律）→ 建 gcp_test 隔离 + 记忆沉淀；
   顺带修 `session.ensure` 死角（login-name 被 4xx 拒 → 清本地凭据回登录页，原会永卡重试门）。
7. **Jira/Meegle**：Jira 建 KAN-111(Done)/112(In Progress)/113(To Do)；飞书项目「三国CR」空间
   补建 13 条镜像单（9 需求+4 缺陷）——**用户拍板：Meegle 只当名录、不追状态**（story 是
   8 节点流推不动，详见 MEEGLE_WORKITEM_GUIDE 补充踩坑）。

**基线**：客户端 **427/427**；Go 全量（含 gcp_test 真 PG+Redis 集成）全过；gdlint/gofmt 绿；
schema v9；docker 6 容器；gateway 配置包 17 文件（新增 kingdom.json）。

## 验收欠账（不是 bug，别瞎修；能验的先验）

1. **KAN-112 王国**：铸币坊挂机领取入账链路（主界面挂机口→领取→金币入包）/ 建筑升级/
   倒计时/加速/收取/王城门禁提示 / **K4：修城墙后打 PVE 我方塔变硬**（日志 `城防=+X%hp`）/
   verifier 对带城防的对局 verdict=pass。
2. **KAN-76 + K5 两机验收**（8 用例一场清）：`docs/ACCEPTANCE_V5_PVP_PROGRESSION.md`
   （用例 7/8 = 城防双端一致/重连不丢城防）+ PVP 视觉补课肉眼验收。
3. 存量：S8e 难度曲线（100 关）、三国 A 组/UI F 组、KAN-96 C 组等，台账见各 ACCEPTANCE_*。

## 下一步候选（用户未指定，开工前问）

- KAN-93 A4 素材分批接入（等美术图，到了就接）；KAN-108 体型三档（宜随 A4 一起）。
- E2 完整公网安全（登录凭证/去 GM/WS ticket/限流）——公开上线前硬门槛。
- K6 王国 IAP 挂点（随全局支付线）；KAN-113 PVE 减速观察口（低优先）。
- 主界面其余屏 CR 化（卡牌页/闯关页 mockup 在 docs/design/ui_mockups/，需用户先评审）。

## 协作红线速记（本轮强化项）

- **INTEGRATION_DB_URL 只准指 gcp_test**（重要到写了两遍）。
- 改 `logic/`/`config/` 必须 `docker restart server-verifier-1`；改 proto 双端重生成
  （`make gen-proto-go` + godobuf headless，Makefile PROTO_NAMES 已含 kingdom）。
- 任何新数值维度进战斗 = 必交「同值哈希全等 + 异值必分叉」两条 lockstep 测试
  （`docs/SECURITY_ANTICHEAT.md` §1.2 成文）。
- 王国经济铁门：建筑成本禁 gold（双端配置校验把关，别放开）。
- 用户偏好中文大白话汇报；一步一确认；说"提交"才 commit+push。
