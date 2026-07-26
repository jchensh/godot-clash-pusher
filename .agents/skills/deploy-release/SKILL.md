---
name: deploy-release
description: Deploys the Godot Clash Pusher release branch to the external testing environment (GCP Backend with Caddy TLS + Firebase Web Frontend). Trigger when user requests deployment to GCP, Firebase, external test environment, or release build deployment.
---

# Deploy Release Build Skill (`deploy-release`)

> **定位与用途**：自动化全流程部署最新的 `release` 分支代码到外网测试环境：
> 1. **GCP 后端服务器** (`https://towerpushserver.jeffgame.tech`) — 经 IAP SSH & Docker Compose
> 2. **Firebase Web 前端** (`https://tower-push-godot.web.app`) — 经 Godot Headless 导出 & Firebase CLI

---

## 1. 部署前检查单 (Pre-Deployment Checklist)

1. 确认当前 Git 分支为 `release` 且工作树干净 (`git status`)。
2. 确认本次部署版本与改动范围：
   - 检查 `server/` 或 `proto/` 是否改动（若有，Docker 构建镜像为硬性依赖）。
   - 检查 `server/migrations/` 是否有新数据库迁移（若有，硬性执行 `docker compose run --rm api /usr/local/bin/migrate`）。
   - 检查 `logic/` 或 `config/*.json` 是否改动（若有，重启 `server-verifier-1` 为**仓库铁律**）。
3. 查阅 [docs/DEPLOY_WEB_GOTCHAS.md](file:///f:/godotTowerPush/release/docs/DEPLOY_WEB_GOTCHAS.md) 确认最新踩坑及排除项。
   - **特别提示**：第 7 条 `GM_ENABLED` 已在 S9 后失效（GM 端点无需门控），切勿去改环境变量。

---

## 2. 后端部署步骤 (GCP VM `towerpush-backend`)

在本地 PowerShell 中执行以下命令（通过 GCP IAP 隧道）：

```powershell
# 1. 登录 GCP 虚拟机并同步 release 最新代码
gcloud compute ssh towerpush-backend --zone=asia-east1-b --tunnel-through-iap --command "sudo git -C /opt/godot-clash-pusher fetch origin release && sudo git -C /opt/godot-clash-pusher checkout release && sudo git -C /opt/godot-clash-pusher pull origin release"

# 2. 重建并启动后端容器栈
gcloud compute ssh towerpush-backend --zone=asia-east1-b --tunnel-through-iap --command "cd /opt/godot-clash-pusher/server && sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build"

# 3. 重启重放验证器容器（反作弊铁律）
gcloud compute ssh towerpush-backend --zone=asia-east1-b --tunnel-through-iap --command "sudo docker restart server-verifier-1"

# 4. 校验 API 与 WebSocket 健康度
curl.exe -s https://towerpushserver.jeffgame.tech/healthz
curl.exe -si https://towerpushserver.jeffgame.tech/v5/session/ws -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA=="
```

---

## 3. Web 前端导出与 Firebase 部署步骤

在本地 Windows PowerShell 中执行：

```powershell
# 1. 导出 Godot 4.6.3 Web client 静态包并注入生产域名变量
powershell -ExecutionPolicy Bypass -File .\tools\build_web.ps1 -ApiUrl "https://towerpushserver.jeffgame.tech" -WsUrl "wss://towerpushserver.jeffgame.tech/v4/battle/ws" -SessionWsUrl "wss://towerpushserver.jeffgame.tech/v5/session/ws"

# 2. 检查 build/web/index.html 确认 UTF-8 编码与 window.GAME_API_URL 注入正常

# 3. 部署至 Firebase Hosting
firebase deploy --project tower-push-godot
```

---

## 4. 部署后记录与 Git 归档 (Post-Deployment Logging)

1. 在 [HISTORY.md](file:///f:/godotTowerPush/release/HISTORY.md) 追加本次部署日志（包含 commit 哈希、修改范围、校验结果）。
2. 提交并推送 HISTORY.md：
   ```powershell
   git add HISTORY.md; git commit -m "docs: 记录 release 部署至外网测试环境及验证结果"; git push origin release
   ```

---

## 5. Skill 修改与维护入口 (Maintenance & Update Entry Point)

当后续部署流程、域名或依赖发生变化时，按以下入口更新维护：
- **技能文件主入口**：[SKILL.md](file:///f:/godotTowerPush/release/.agents/skills/deploy-release/SKILL.md)
  修改本文件第 2/3 节的部署命令参数。
- **GCP 域名/TLS/架构变更**：更新 [docs/deployment/GCP_RELEASE_TLS.md](file:///f:/godotTowerPush/release/docs/deployment/GCP_RELEASE_TLS.md) 并同步修正本 SKILL.md。
- **打包注入脚本变更**：更新 [tools/build_web.ps1](file:///f:/godotTowerPush/release/tools/build_web.ps1)。
- **避坑台账更新**：追加至 [docs/DEPLOY_WEB_GOTCHAS.md](file:///f:/godotTowerPush/release/docs/DEPLOY_WEB_GOTCHAS.md)。
