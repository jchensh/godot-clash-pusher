# 方案 B：单机容器编排架构实施计划 (GCE + Firebase Hosting)

根据您的确认，我们将采用 **方案 B：单机容器编排架构** 进行部署。本计划列出了具体的步骤，详细说明了后续哪些步骤将由 Antigravity IDE 自动执行，哪些步骤需要您（用户）配合操作。

---

## 浏览器 Mixed Content 关键约束 (必须知悉)
> [!IMPORTANT]
> **HTTPS/WSS 限制**：因为 Firebase Hosting 默认强制使用 **HTTPS**，浏览器安全策略限制在 HTTPS 网页中只能向后端发起 **HTTPS** 和 **WSS (WebSocket Secure)** 请求。
> 
> 如果后端只提供 `http://` 和 `ws://`，浏览器会拦截连接并报错 `Mixed Content`。因此，部署在 GCE 上的服务端**必须配置 SSL 证书**。
> **建议方案**：使用一个临时子域名解析到 GCE 实例，由 Nginx (或 Traefik) 和 Let's Encrypt 自动申请和维护免费 SSL 证书。

---

## 实施步骤拆解与执行人归属

本计划分为 **5 个阶段**。Antigravity IDE 将负责生成所有配置文件、打包脚本和部署文件，您只需在控制台进行云端创建与 CLI 授权。

### 阶段 1：本地客户端 Web 打包准备 (Antigravity IDE 执行)
1.  **添加 Web 导出预设**：在 [export_presets.cfg](file:///f:/godotTowerPush/release/export_presets.cfg) 中追加 `Web` 预设配置，开启多线程及 ASTC/ETC2 贴图压缩支持。
2.  **网络配置支持动态域名**：修改 [session.gd](file:///f:/godotTowerPush/release/net/session.gd) 以动态适配 Web 页面的 Host（支持检测开发模式与生产模式，自动获取后台 API 域名）。
3.  **编写打包脚本**：在 `tools/` 目录下编写 `build_web.ps1` 脚本，以便一键编译 Godot Web 客户端。

### 阶段 2：Firebase Hosting 托管部署 (Antigravity IDE 准备，用户执行部署)
1.  **创建 Firebase 配置文件**：在根目录下生成 [firebase.json](file:///f:/godotTowerPush/release/firebase.json) 配置文件，配置 COOP / COEP 头部信息。
2.  **打包与上传 (用户配合)**：
    *   用户需安装 `firebase-tools` 并通过命令行登录：`firebase login`。
    *   Antigravity 执行打包命令：生成 `build/web/`。
    *   用户在本地运行部署：`firebase deploy --only hosting`，部署成功后将获得类似 `https://your-app.web.app` 的前端域名。

### 阶段 3：GCE 服务端多容器生产编排 (Antigravity IDE 执行)
1.  **编写生产环境 Compose 配置**：
    *   新建 `server/docker-compose.prod.yml`，对 Postgres 和 Redis 容器**移除外部端口映射 (5432 / 6379)**，仅允许在 Docker 内部网段互通，保障数据库安全。
    *   配置 `gateway` 和 `api` 容器，挂载 `/app/config` 目录。
2.  **反向代理 (Nginx) 配置**：
    *   新建 `server/nginx.conf` 模板，定义 `:80` 与 `:443` 监听，配置对 `api` (:8080) 的 HTTP 代理以及对 `gateway` (:8081) 的 WebSocket 代理（开启 `Upgrade` 和 `Connection` 头部转发）。
    *   或者引入 `nginx-proxy` + `acme-companion` 容器，实现全自动的 SSL 申请（强烈推荐，可省去手动配置 Nginx 证书的过程）。

### 阶段 4：GCE VM 实例准备与网络配置 (用户操作)
1.  **创建虚拟机**：在 Google Cloud Console 中创建一台 GCE 实例（例如 Debian/Ubuntu 系统，`e2-small` 或 `e2-micro` 类型）。
2.  **防火墙开通**：在 GCP 防火墙策略中，开通该 VM 实例的 **HTTP (80)** 和 **HTTPS (443)** 端口（用于 Web 流量及 Let's Encrypt 证书申请）。
3.  **域名解析**：将您的一个域名（或子域名）指向该 GCE 实例的固定公网 IP。

### 阶段 5：云端拉取与一键启动 (用户 + Antigravity IDE 配合)
1.  用户在 VM 上安装 Docker 与 Git，并克隆代码。
2.  在服务端的 `.env.prod` 文件中配置 `JWT_SECRET` 以及数据库密码。
3.  在 VM 上执行部署命令：`docker compose -f docker-compose.prod.yml up -d` 启动全部容器，包括 `migrate` 迁移。

---

## Proposed Changes (拟新增与修改文件)

### 🎮 Godot 客户端修改

#### [MODIFY] [export_presets.cfg](file:///f:/godotTowerPush/release/export_presets.cfg)
*   追加 Web (HTML5) 导出预设配置。

#### [MODIFY] [session.gd](file:///f:/godotTowerPush/release/net/session.gd)
*   优化 `_load_network()` 函数。当检测到 `OS.has_feature("web")` 且 `window` 对象下提供了动态域名时，优先使用动态域名（避免打包时把 IP 地址写死，方便在不同部署环境下运行同一个包）。

#### [NEW] [firebase.json](file:///f:/godotTowerPush/release/firebase.json)
*   定义 Firebase Hosting 配置，注入 `Cross-Origin-Opener-Policy: same-origin` 和 `Cross-Origin-Embedder-Policy: require-corp` Headers。

### 🖥 Go 服务端部署修改

#### [NEW] [docker-compose.prod.yml](file:///f:/godotTowerPush/release/server/docker-compose.prod.yml)
*   包含多容器配置（Nginx + Let's Encrypt 自动证书申请 + Postgres + Redis + API + Gateway）。

#### [NEW] [production.env.example](file:///f:/godotTowerPush/release/server/production.env.example)
*   服务端生产环境环境变量模版。

---

## Verification Plan (验证与测试方法)

### 1. 客户端 Web 首屏与 Header 验证
在本地运行 Web 包：
```bash
# 启动本地包含特殊 Headers 的 web 服务器进行验证
npx serve build/web --cors
```
在 Chrome 开发者工具控制台，检查 Headers 中是否包含 COOP 与 COEP，且无 `SharedArrayBuffer` 跨域报错。

### 2. 双端网络联调验证
1.  部署至 Firebase Hosting 后，通过 HTTPS 访问静态页面。
2.  测试客户端请求 API 的接口（如 `/v4/auth/login`）能否连通。
3.  测试客户端连接 WebSocket（如 `/v5/session/ws`）能否正常建立持久会话并下发配置。
4.  通过开启两个浏览器窗口模拟玩家匹配，验证联机对战（lockstep）能否在云端容器内正常驱动。
