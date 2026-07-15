# PLAN_V5_S9_ACCOUNT_UX.md — 账号身份 + 引导/菜单改版（V5-S9）

> 本文件是 **V5-S9 这批改动的权威施工图**，从属于 [PLAN_V5.md](PLAN_V5.md)（当前阶段权威规划）。一批 5 项需求（4 项 + 1 项显示子项），围绕「账号身份 + 新手引导自动化 + GM 解禁 + 主菜单重构 + 天梯选卡组」。
> **沿用决策 48（服务器权威）**：昵称/头像/引导完成标志全在服务器 + PG，客户端瘦表现层；动作走服务器 API 校验，本地仅非权威缓存。
> **开发纪律沿用 V1~V5**：一步一确认、每步 commit、逻辑/服务端步必配单测、表现/真机步交真人验收、每步同步 HISTORY.md + Jira（project KAN）。

---

> ## ✅ 全部完成（2026-07-01，真人验收通过）
> KAN-70~75 六项全部落地并真人验收：客户端 **313/313** + Go build/vet/单测全过（含 `TestValidateNickname`）+ 真 docker 重建（api/gateway）+ migration **0007**（schema v7，profiles 加 avatar_card_id/tutorial_done）。Jira 由用户手工维护。详细 as-built 见 [HISTORY.md](HISTORY.md) V5-S9 段。

## 0. 需求来源 + 已确认决策（用户 2026-07-01 确认）

| # | 需求 | 关键决策（已拍板） |
|---|---|---|
| 1 | 新增账号系统：新号首进起名（中英数，宽度≤10）+ 选一个怪物卡当头像 | 数据**服务器权威**；头像可从**全部怪物卡**选（含未解锁）；存 `card_id` 字符串 |
| 1.1 | 名字+头像在主菜单 + 对战界面（PVP/PVE）显示 | 设计像素名片组件，PVP 显示双方（对手走匹配下发的 ProfileSummary） |
| 2 | 新号创号后直接进新手引导，**打完一局**（胜负不论）→主菜单；此后主菜单无引导入口 | 引导=**只打一场**引导战（教学第 1 关 + 引导层）；`tutorial_done` 标志**存服务器** |
| 3 | 取消 GM 环境限制，所有客户端（含正式云部署）都能在设置 GM 里点击拿资源 | 去掉服务端 `GM_ENABLED` 门控，`/v5/gm/*` 始终挂载 |
| 4 | 主菜单按钮调整 | **保留基地做 PVE 中枢**方案：见 §4 |
| 5 | 点天梯对战→先进卡组选择→选好→再进匹配队列 | 选好的卡组先存**卡组槽 1**（服务器权威）→带槽进匹配 |

**stated defaults（用户未反对，按此执行）**：
- **名字规则**：按显示宽度限制——中文/全角算 1、英文数字算 0.5，**上限 10**（≈最多 10 中文 / 20 英数）；去首尾空格；**不做重名校验/敏感词过滤**（小游戏，后续要再加）。客户端实时拦，服务器权威复校（越界 400 拒）。
- **头像存储**：存 `card_id` 字符串（比整数 `avatar_id` 稳健、跟卡表解耦），新增字段，不动旧 `avatar_id`。
- **新号识别**：登录响应加 `is_new`（服务器 `Account.Created` 已有，透出来即可）。
- **GM 风险**：解禁后线上任何人都能在设置刷资源——**按用户明确要求执行**，文档去掉"prod 必关"措辞，保留一句风险说明。
- **PVP 选卡组**：天梯卡组池=**已解锁卡**（与收藏一致）；PVP 战斗机制本批不动（仍 lockstep flat、不接 per-card 养成乘区，属另一议题）。

---

## 1. 改动 1：账号身份系统（服务器权威）

### 1.1 服务端（Go + PG + proto）

**proto 改动**：
- `auth.proto` `LoginResp` 加 `bool is_new = 4;`（首次建号=true）。
- `profile.proto` `Profile` 加 `string avatar_card_id = N;` + `bool tutorial_done = N;`（N 取下一个未用 field number）。
- `profile.proto` 新增 `ProfileUpdateReq { string nickname; string avatar_card_id; }` / `ProfileUpdateResp { Profile profile; }`。
- `common.proto` `ProfileSummary` 加 `string avatar_card_id = 6;`（PVP 对手名片要用）。
- `common.proto` `MsgId` 加 `PROFILE_UPDATE_REQ`（按现有分段补号）。

**migration `0007_profile_identity.up.sql`**：
```sql
ALTER TABLE profiles ADD COLUMN avatar_card_id TEXT NOT NULL DEFAULT '';
ALTER TABLE profiles ADD COLUMN tutorial_done  BOOLEAN NOT NULL DEFAULT FALSE;
-- nickname 仍保留服务端默认 'Player{id}'；用 is_new + nickname_set 判定是否进创号
```
> **是否需要 setup 完成标志**：用「`is_new`（首次登录）+ 本地是否已提交过创号」即可触发创号页；服务器侧用 `nickname` 是否仍为默认/空兜底判定。施工时若发现"创号后退出再进"会重复弹创号，则加一个 `nickname_set BOOLEAN` 列显式标记（成本极小，留 S9-1 施工时定）。

**业务层**：
- `internal/auth`：`FindOrCreateByDevice` 已返回 `Created`；`handler.go` 登录响应填 `LoginResp.IsNew = acc.Created`。
- `internal/profile/repo.go`：`UpdateIdentity(ctx, accountID, nickname, avatarCardID)`（带服务端名字宽度校验 + 头像 card_id 合法性可选校验）；`SetTutorialDone(ctx, accountID)`。乐观锁 `version` 自增。
- `internal/profile/handler.go`：加路由 `POST /v4/profile/update`（鉴权，account 取令牌不信 body）。`tutorial_done` 置位走单独轻接口 `POST /v4/profile/tutorial-done` 或并进 update（S9-2 定，倾向单独轻接口，语义清晰）。
- `toPbProfile` / `ProfileSummary` 填 `avatar_card_id`。

### 1.2 客户端（net + view）

- `net/profile.gd`：加字段 `avatar_card_id` / `tutorial_done` / `is_new`；加方法 `update_identity(http, token, nickname, avatar_card_id)` + `mark_tutorial_done(http, token)`；`_apply_profile` 读新字段；离线缓存 `profile.cfg` 加这两列。
- `net/session.gd`：`ensure()` 后暴露 `is_new()` / `nickname()` / `avatar_card_id()` / `tutorial_done()`，供登录路由 + 名片读取。`LoginResp.is_new` 透到 session。
- 新场景 `view/account_create.gd/.tscn`（创号页）——见 §1.4 设计。

### 1.3 数据流（创号）

```
启动 → main_menu/boot → session.ensure()（匿名 device 登录）
  ├─ is_new（且未起名）→ account_create 页（起名 + 选头像）
  │     → profile.update_identity → 服务器落库 → 进引导（改动 2）
  ├─ 已起名但 !tutorial_done → 进引导（改动 2）
  └─ 已起名 + tutorial_done → 正常主菜单
```

### 1.4 UI 设计：创号页 `account_create`

像素风、复用 `PixelUI`（夜色背景 menu_bg + 9-slice 石碑 + 金描边），竖屏 720×1280 布局：

```
┌────────────────────────────┐
│        创建你的英雄          │  ← 像素金标题 + 描边
│      CREATE YOUR HERO        │
│                              │
│   ┌──────────────────────┐   │
│   │  [ 输入名字…        ] │   │  ← LineEdit，居中，大字
│   └──────────────────────┘   │
│        7 / 10  ✓             │  ← 实时宽度计数（中1/英数0.5），超限红
│   中英文数字皆可 · 最多10字   │  ← hint
│                              │
│   选择头像                    │
│  ┌──┬──┬──┬──┐               │  ← 怪物卡头像网格（可滚动）
│  │🛡│🏹│👹│💀│  ...          │     全部怪物卡，选中=金边
│  ├──┼──┼──┼──┤               │     立绘走 SpriteDB.card_portrait_tex
│  │..│..│..│..│               │
│  └──┴──┴──┴──┘               │
│                              │
│      [   确  认   ]          │  ← gold CTA，名字合法+选了头像才可点
└────────────────────────────┘
```
- 名字框：`LineEdit`，`max_length` 不够（按宽度而非字符数），用 `text_changed` 实时算显示宽度 + 更新计数 + 越界禁用确认。
- 头像网格：只列**有怪物立绘的卡**（兵种卡；`SpriteDB.card_portrait_tex(id)!=null`），法术卡排除。每格 = 立绘 + 卡名，选中加金边 `Panel`（复用 deck_builder 的 `_frames` 范式）。
- **mockup 先行**：施工时先出可视 mockup 给真人过目，再落代码（沿用 UI/UX 准则）。

### 1.5 UI 设计：名片组件 + 落位（需求 1.1）

新增 `HudWidgets.nameplate(nickname, avatar_card_id, loader, trophies=-1, align)` → 返回一个像素名片 `Control`：
```
┌────┐
│ 头 │  昵称名字        ← 头像方块(9-slice 边框, ~64px, 怪物立绘) + 昵称(金/描边)
│ 像 │  🏆 1240         ← 可选杯数（trophies>=0 才显示）
└────┘
```
落位：
| 场景 | 落位 | 数据来源 |
|---|---|---|
| **主菜单** `main_menu` | 顶部（替换/合并现有"杯数 …"label，左上角名片 + 杯数） | session（本地玩家档） |
| **PVE 战斗** `battle_scene` | 己方一角（HUD 角落，不挡战场/拇指区） | session（本地玩家档） |
| **PVP 对战** `net_battle_scene` | **双方**：己方一角 + 对手对角（顶部） | 己方=session；对手=匹配下发 ProfileSummary（nickname + avatar_card_id） |

> 对手头像依赖 §1.1 给 `ProfileSummary` 加 `avatar_card_id` 并由服务端匹配/建房时填充（matcher/lobby/room 取对手 profile）。

---

## 2. 改动 2：新手引导自动化

- **触发**：登录路由（§1.3）——`!tutorial_done` → 强制进引导战，**不经主菜单**。
- **引导内容**：只打**一场**——教学战役第 1 关（`campaign_01` + 其 tutorial.json 引导层）。复用 `battle_scene` 的「战役模式」通道（已会挂引导层），但用**单关 CampaignState**（只 `campaign_01`）或新增轻量 `GameState.tutorial=true` 分支。
- **战后**：不管胜负，**不重打不推进**——置 `tutorial_done`（调 `profile.mark_tutorial_done` 服务器落库）→ `change_scene` 回主菜单。需在 `battle_scene._add_result_buttons` 加一个 tutorial 分支（单按钮"完成"→ 标记 + 回菜单）。
- **菜单入口移除**：`main_menu` 删 `新手战役`(menu_campaign) 按钮（并入改动 4 的菜单重构一起做）。`campaign_scene` / `campaign.json` / 其余 5 关**保留不删**（只是不再从菜单进；`campaign_01` 被引导复用）。
- **验收**：新号（GM 重置或新 device）→ 自动进引导 → 打完（胜或负）→ 回菜单 → 重启再登录**不再**强制引导；菜单无新手战役入口。

> **数据落点**：`tutorial_done` 在 `profiles` 表（服务器权威）——换机/重装不重复引导。

---

## 3. 改动 3：GM 解禁

- `server/cmd/api/main.go`：删除 `if os.Getenv("GM_ENABLED") == "1"` 判断，**始终** `economy.NewGMHandler(...).Mount(mux, authMW)`。
- `server/docker-compose.yml`：`GM_ENABLED` 注释/变量可留可删（不再被读）；去掉"prod 必须关"措辞，改风险说明。
- 注释/文档同步：`view/settings.gd`、`net/economy_*.gd`、`PLAN_V5.md §11.3`、`CLAUDE.md`、`HISTORY.md` 里"`GM_ENABLED` 门控 prod 必关"的描述改为"GM 始终开放（用户决策，含 prod）"。
- **仍走会话鉴权**：GM 只能改自己账号（不变）。
- **验收**：不设 `GM_ENABLED`（或设 0）启动 api，设置里点 GM 按钮仍能加资源（`/v5/gm/apply` 返回 200）。Go 集成测：GM 路由无门控始终可达。

> ⚠️ 风险说明（写进 HISTORY 决策）：线上任意玩家可自助刷资源——经济不再防作弊。属用户明确取舍（当前阶段/demo 定位），非疏漏。

---

## 4. 改动 4：主菜单重构（保留基地做 PVE 中枢）

**改前**
- 主菜单：`天梯对战`(金→net) / `新手战役`(→campaign) / `探险Roguelite`(→run) / `开始`(→base_camp) / `设置` / `退出`
- 基地 base_camp：`闯关`(CTA→stage_map) / `养成` / `卡组` / `天梯`(→net) + 钱包/挂机/战力

**改后**
- **主菜单**（6 钮 + 名片）：
  | 按钮 | 类型 | 去向 |
  |---|---|---|
  | **天梯征途** | gold CTA | 选卡组 → 匹配（改动 5）。合并原"天梯对战"+基地"天梯"为唯一 PVP 入口 |
  | **闯关** | stone | → base_camp（PVE 中枢） |
  | **养成** | stone | → card_collection（上提自基地） |
  | **卡组** | stone | → deck_builder（edit 模式，上提自基地） |
  | **探险** | stone | → run_scene（Roguelite，保留） |
  | **设置** | stone | → settings |
  - 去掉 `退出`、去掉 `新手战役`（改动 2）。顶部加玩家名片（§1.5）。
- **基地 base_camp 瘦身**：删 `养成`/`卡组`/`天梯` 三按钮；**保留** `闯关`(CTA) + 钱包 + 挂机 + 战力 + 返回。
- **i18n**：加 `menu_ladder_journey`="天梯征途"/"Ladder"；复用 `menu_*` 其余键；清理不再用的键引用（不删键，避免连带）。
- **验收**：菜单 6 钮布局正常（像素风/拇指区/按下反馈）；点养成/卡组直达；闯关进基地、基地内只剩闯关+钱包+挂机+战力；无退出/新手战役；天梯征途走改动 5 流程。真人验收。

---

## 5. 改动 5：天梯先选卡组再匹配

- **流程**：主菜单 `天梯征途` → `deck_builder`（新增 **ladder/pvp 模式**）→ 选满 8 张点"出征" → 把卡组**存到卡组槽 1**（`profile.update_deck(slot=1, set_active=true)`，服务器权威）→ `change_scene` 到 `net_battle_scene` → net_battle 用槽 1 `FindMatch`（现状即槽 1，无需改 battle_client）。
- **deck_builder ladder 模式**：
  - `GameState.deck_mode = "ladder"`（新值）；候选池=**已解锁卡**（`_card_pool` 现成逻辑，登录后即已解锁集）；不需要 stage 推荐战力着色（PVP 无 coef），只显战力数值。
  - 确认按钮文案"出征 / 匹配"；`_on_battle` ladder 分支：先 `await update_deck` 存槽 → 成功再进 net_battle；存失败给 toast 不进。
  - BACK 回主菜单。
- **net_battle_scene**：入口不变（仍 `_client.start(ws_url, token, 1)`），只是改由 deck_builder 进来而非主菜单直达。主菜单/基地不再直达 net_battle。
- **验收**：天梯征途 → 选卡组（达标提示）→ 出征 → 卡组已存槽 1 → 进匹配队列 → 真机两端配对用的是刚选的卡组。

> **开放点**：PVP 是否该用玩家卡牌等级/阶（per-card 养成乘区）？当前 PVP 仍 flat（ladder_01）。本批**不改 PVP 战斗数值**，只加选卡组步骤。养成进 PVP 属独立议题（PLAN_V5 §12 已挂"联机养成同步"，留后续）。

---

## 6. 施工顺序 + Jira 映射

**依赖序**（一步一确认，每步 commit + 单测/真人验收）：

| 序 | 步骤 | 类型 | Jira | 依赖 |
|---|---|---|---|---|
| ① | **改动 3 GM 解禁** | Task | 新 Task | 无（最独立，先做暖身） |
| ② | **改动 1a 服务端账号地基**（proto/migration/repo/handler：is_new + avatar_card_id + tutorial_done + update 接口 + ProfileSummary 头像） | Story | 新 Story | 无 |
| ③ | **改动 1b 客户端创号流程**（account_create 页 + profile.gd + session 路由） | Story | （并入 1a Story 或拆子步） | ② |
| ④ | **改动 2 引导自动化**（登录路由→单场引导→tutorial_done→回菜单；删菜单入口） | Story | 新 Story | ②③ |
| ⑤ | **改动 1.1 名片显示**（HudWidgets.nameplate + 主菜单 + PVE + PVP 双方） | Story | 新 Story | ②（PVP 对手需 ProfileSummary 头像） |
| ⑥ | **改动 4 主菜单重构**（按钮 + 基地瘦身） | Task | 新 Task | ⑤（名片落位）、④（删引导入口） |
| ⑦ | **改动 5 天梯选卡组→匹配**（deck_builder ladder 模式 + 存槽 + net_battle 入口） | Story | 新 Story | ⑥（天梯征途按钮） |

**Jira 拟建工单**（Epic = V5 `KAN-50`；建单默认 `To Do`，开工改 `In Progress`，验收+用户同意才 `Done`）：
1. **Task**：GM 解禁——去掉 `GM_ENABLED` 门控（改动 3）
2. **Story**：账号身份系统——创号起名+选头像（服务器权威）（改动 1 + 1a/1b）
3. **Story**：身份展示——主菜单/PVE/PVP 名片+头像（改动 1.1）
4. **Story**：新手引导自动化——创号后强制一局→主菜单，移除菜单入口（改动 2）
5. **Task**：主菜单重构——去退出/提养成卡组/天梯征途/基地瘦身（改动 4）
6. **Story**：天梯先选卡组再匹配（改动 5）

---

## 7. 待施工时细化（不阻塞，开工对应步前定）

- `nickname_set` 是否单列 vs 靠 `is_new`+默认昵称兜底（S9-1 施工时验"创号后退出再进"不重复弹）。
- 名字宽度算法精确口径（全角判定：CJK/全角符号=1，其余=0.5；emoji 是否禁——倾向禁，只留中英数+常见符号）。
- `tutorial_done` 置位接口形态（独立轻接口 vs 并进 profile/update）。
- 头像网格是否需要分页/滚动（怪物卡约 10 张，单屏可放下，大概率不用滚）。
- ProfileSummary 头像在 matcher/lobby/room 哪一处填充最省（取对手 profile 的现有读取点）。
- PVP 卡组池：已解锁 vs 全卡（本文件定**已解锁**；若 PVP 要"全卡随便组"再调）。

> 范围锁定如上；PVP 接养成、支付/IAP、正式登录/合规——均不在本批，沿用 PLAN_V5/PLAN_GRAND 的产品化推后。
