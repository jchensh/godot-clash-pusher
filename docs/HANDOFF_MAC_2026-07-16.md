# 项目交接：Mac 开发环境接续（2026-07-16）

> **用途**：从 Windows 换到 Mac 继续开发时，直接把本文件整篇喂给 Mac 上的 Claude Code（或其他
> coding agent），环境搭建 + 项目状态一次性交接完。写作时的仓库真相源 = `origin/master @ 8a08f37`
> （`docs: HISTORY 首批 BGM 标记听验通过`）。之后仓库肯定会继续推进，若本文档提到的提交号/测试
> 数字与 HISTORY.md 对不上，以 HISTORY.md + Jira 为准，本文档只保证写作当天的快照准确。

---

你正在接手一个跨平台开发的项目——之前在 Windows 上开发，现在换到 Mac 继续。这条文档是给你的
完整环境搭建 + 状态交接，照着做完就能在 Mac 上无缝续接开发。

## 第一步：先读三份文档（决定你怎么协作）

1. `CLAUDE.md`（协作纪律，最高优先级）—— 一步一确认、用户说"提交"才 commit+push、
   Jira 转 Done 需用户拍板、表现层验收交真人。
2. `HISTORY.md`（进度真相源，看"当前进度总览"表 + 最后 5~6 条决策日志）
3. `docs/README.md`（全仓文档地图，之后按需查）

⚠️ 有一处要注意：`CLAUDE.md` 里"工具链"那段的 Godot 命令是**原生 Mac 命令**
（`HOME=/private/tmp/godot-home godot --headless ...`）——项目最早就是在 Mac 上写的，
这些命令不用像 Windows 那样翻译路径，直接抄就行。

## 第二步：拉代码

```bash
git clone https://github.com/jchensh/godot-clash-pusher.git
cd godot-clash-pusher
git log -1   # 应该看到 8a08f37 "docs: HISTORY 首批 BGM 标记听验通过"（或更新的提交）
```

分支说明：
- **master** = 你要工作的分支，实时在线 F2P 闯关养成阶段（决策 48，服务器权威）。
- **release** = 安卓/Web 打包发布分支，**默认不要碰**（有独立的部署配置，跟 master 走单向合并，
  不在 release 上开发）。上一轮刚做完首次公网部署（GCP 后端 + Firebase Web 前端），
  由另一个 agent（Antigravity，运行在一台 Windows 机器）负责，你不用管。

## 第三步：Godot 4.6.3 stable

这台 Mac 上大概率已经装好正确版本（此前有别的 agent 会话在这台机器上工作过）。先核实：

```bash
godot --version   # 期望包含 4.6.3.stable
HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd
```

期望：`==== 测试汇总: 共 418, 通过 418, 失败 0 ====`，exit code 0。这是客户端逻辑层
的验收主手段（`tests/test_*.gd`，零依赖自写 runner）。如果版本不对或命令跑不通，
再去官网 https://godotengine.org/download/macos/ 下载 4.6.3 stable 装。

## 第四步：Docker（这台 Mac 上目前没装，需要装）

装 Docker Desktop for Mac（https://www.docker.com/products/docker-desktop/，
Apple Silicon 选 arm64 版、Intel 芯片选对应版）。装完验证 `docker compose version` 能跑。

⚠️ 芯片架构提醒：如果是 Apple Silicon（M 系列），本地开发**不用担心架构问题**——
`server/docker-compose.yml` 里的基础镜像（`golang:1.25-alpine`/`postgres:16-alpine`/
`redis:7-alpine`）都原生支持 arm64，`docker compose build` 会自动编到本机架构，
不需要加 `--platform` 之类的参数。跨架构编译只有"发布到 GCP amd64 服务器"才需要考虑，
那是 release 分支部署流程的事，不归你管。

起服务端六容器：

```bash
cd server
cp .env.example .env   # 本地开发直接用默认值即可，不用改一个字段
docker compose up -d --build
```

首次 build 会拉 Go 依赖，几分钟起。起完验证：

```bash
curl -s http://localhost:8080/healthz   # 期望 200/ok
docker compose ps                        # 期望 6 个容器：postgres/redis/gateway/api/battle/verifier
```

跑数据库迁移（首次起库需要）：

```bash
docker compose run --rm api /usr/local/bin/migrate
```

⚠️ 运维铁律（写进 `CLAUDE.md` 的，容易忘）：改了 `logic/` 或 `config/` 目录下的文件后，
必须 `docker restart server-verifier-1`（PVE 反作弊重放验证器挂载了这两个目录的代码，
不重启就在跑旧逻辑）；新增卡牌还要多重启一次 `api` 容器（有个一次性播种逻辑）。

## 第五步：lint 工具链（用 uv，无需系统装 Python 包）

```bash
uv run --with "gdtoolkit==4.*" gdlint .    # GDScript 静态检查，提交前必须绿
```

Windows 版 `CLAUDE.md` 里提到下载走代理（`HTTPS_PROXY=http://127.0.0.1:7897`）——
那是 Windows 机器的网络环境专属配置，Mac 上大概率不需要，先不加试一次，
连不上再考虑要不要配代理。

## 第六步：MCP 连接器（按需，非阻塞）

以下这些是 Windows 会话里装配好的，Mac 是全新环境，要用到时才需要重新配：
- **Jira MCP**（Atlassian 连接器）：项目用 Jira project `KAN` 站点 `jchensh.atlassian.net`
  记结构化进度（Epic=版本线/Story=玩法/Task=工程/Bug=修复），与 `HISTORY.md` 并列作为真相源。
  没装的话先问用户要不要装，装的方法见 `docs/ENVIRONMENT.md`。
- **飞书（lark-cli）MCP**：有几份仅存在飞书、repo 无镜像的文档（GDD 策划案、战场+单位美术
  规格书、UI 系统策划案），如果要读改这些得先配好。
- **godot-ai MCP**：编辑器联动辅助（Godot 编辑器开着时才有），可选，见 `docs/ENVIRONMENT.md`。

这些都不影响你直接开始写代码/跑测试，缺了就跟用户说一声，不要瞎猜配置。

## 项目当前状态快照（2026-07-16，origin/master @ 8a08f37）

一句话：**V5 实时在线 F2P 闯关养成阶段**，主干功能全部完成并已首次公网部署验证成功。

**架构铁律**（写代码前务必知道，`CLAUDE.md` 有完整版）：
- 逻辑层/显示层彻底分离；不用物理引擎做碰撞；圣水/时间走固定 10Hz tick；
- **决策 48**：客户端不权威化任何经济/养成/进度——全部服务器算 + PG 落库；
- UI 层级走骨架（`UI.modal()`/`UI.toast()`）、场景切换走 `Router.goto()`、
  跨模块通知走 `Events` 总线、日志走 `Log.d/i/w/e`（禁裸 print）——这四条都有源码扫描测试把关，
  违反了会在单测里直接报错。

**最近几轮做完的东西**（按时间倒序）：

1. **首次公网部署验证通过**（release 分支，GCP 后端 `towerpushserver.jeffgame.tech` + Firebase
   Web 前端 `towerpush.web.app`〔⚠️ 该前端地址 2026-07-21 已弃用、Firebase 项目已删，
   现行地址 = `tower-push-godot.web.app`，见 GCP_RELEASE_TLS.md〕）：新玩家注册、PVE 反作弊全链路、经济发奖、真人双浏览器 PVP
   对战全部实测通过。详细踩坑记录在 release 分支的 `HISTORY.md`「发布与打包」附录，
   **不在 master 上**（部署记录是 release 独有内容）。
2. **首批正式 BGM**：菜单曲（Snowland 循环）+ 战斗双曲轮播（曲终随机换）+ 选卡曲（Heroic Demise），
   `view/audio_manager.gd` 新增 `play_music_set()` 轮播集能力。真人听验过。
3. **KAN-110 E2-lite**：Caddy TLS 反代模板（`server/docker/Caddyfile.prod` +
   `server/docker-compose.prod.yml`，只在部署时叠加用）+ secrets 模板化 + GCP 发布手册
   `docs/deployment/GCP_RELEASE_TLS.md`。**这套只做了"加密"一项**，E2 完整版的登录凭证/
   去 GM/限流故意没做（用户拍板：有限测试人员场景，风险可接受）。
4. **KAN-109 username 登录改版**：抛弃了"本地有没有数据判新老玩家"的旧逻辑，改成**服务器
   查库权威判断**——新玩家查名→选头像→注册→自动新手引导；老玩家查名→直接登录进主界面。
   新增登录页 `view/login.gd`；`view/account_create.gd` 改成注册模式（登录前没有服务器配置，
   有个本地展示配置回退的机制，别删）；设置页加了登出按钮。当前是**裸登录无凭证**（用户名
   即可登录，无密码），这是明确的已知安全边界，不是 bug——正式上线前要在完整 E2 补凭证。
5. **KAN-107**：战场屏幕格从非正方形改成 32×32 正方形，`battle_scene.gd._field_rect()` 收口。
6. **0715/0716 三国正式美术批次**：骑士全套素材（走/攻/立绘/攻击刀光/受击星芒/死亡白烟）+
   阵营分色塔 + 新战场背景，外加**单位/建筑 Y-sort 伪深度**渲染排序机制。

## 已知欠账（不是 bug，是明确记录的 TODO，别自己瞎修）

1. **`net_battle_scene.gd`（PVP 场景）视觉没跟上**：上面第 4/6 点的美术改造只进了单机
   `battle_scene.gd`，PVP 场景还在用最老的贴图（`building1.png`/`building6.png` 旧塔、
   16px 像素拼贴地形、没有 Y-sort）。逻辑是对的（PVE/PVP 共用同一套战斗逻辑代码，
   服务器权威判定不会错），纯粹是视觉资产没同步，PVP 对局里"感觉兵在河上走"就是这个。
   **要修的话属于新一轮开发任务，先跟用户确认要不要做、什么时候做**（涉及改完还要合并
   release 重新触发一轮 GCP+Firebase 部署）。
2. **KAN-108**（Jira 待办）：单位视觉体型三档映射（中/大/超大）还没接进 view 层，
   建议随 A4 素材继续换皮时一起做。
3. **真人验收债**：还有一批表现层功能代码写完但没走真人验收流程，具体清单问用户
   或翻 Jira（KAN-90~98 附近）。
4. **完整 E2 公网安全**：登录凭证/GM 端点关闭/WS ticket/Origin 限流——只要域名还是"仅发
   给指定测试人员"就不急，一旦要公开分享链接必须先做完这个。

## 协作红线（最容易踩的几条）

- **一步一确认**：不要连续做多步不停下汇报。
- **只有用户明确说"提交"才 commit+push**；Jira 转 Done 需用户拍板认可。
- **改 `logic/`/`config/` 后必须重启 verifier 容器**（见第四步）。
- **release 分支不要主动碰**，除非用户明确指示。
- **画面/手感这类表现层验收交真人肉眼验证**，别自己截图就号称测过。
- 用户偏好中文沟通、报告用大白话讲结果（不太看代码细节，靠自动化测试背书）。

开工前先跑一遍第三步和第四步的验证命令，跟用户确认「环境搭好了，418/418 全绿，
docker 6 容器起来了」，再问接下来做哪条线。
