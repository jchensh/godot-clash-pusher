# GCP 公网发布手册：HTTPS/WSS（E2-lite）+ Release 打包检查单

> **定位**：把服务端部署到 GCP 并以 **单域名 + TLS 加密** 对有限测试人员开放的完整操作手册，
> 同时是 release 分支打安卓/桌面包前的检查单。任何后续会话/Antigravity 照本文操作即可，无需上下文。
> **产出自** KAN-110（2026-07-16）。安全边界见文末——这是 E2-lite，不是完整 E2。

## 一、架构一句话

```
测试者手机/PC ──(https/wss, 443)──▶ Caddy 反代（TLS 终结·自动证书）
                                      ├─ /v4/battle/ws、/v5/session/ws ──▶ gateway:8081
                                      └─ 其余全部路径 ────────────────────▶ api:8080
        （battle/verifier/postgres/redis 仅容器内网，不对外）
```

- 一个域名一个 443 端口承载全部流量（api 与 gateway 的路径不重叠，Caddy 按路径分流）。
- 证书由 Caddy 自动向 Let's Encrypt 申请/续期，零人工维护；证书状态持久化在 `caddy_data` 卷。
- 相关文件（全部在 master，release 跟随合并）：
  `server/docker-compose.prod.yml`（overlay）· `server/docker/Caddyfile.prod`（反代模板）· `server/.env.example`（环境值样板）。

## 二、前置条件（一次性）

1. **GCP 虚拟机**：e2-small 起步即可；装好 docker + docker compose 插件；建议绑静态外网 IP。
2. **域名**：把一条 A 记录解析到上面的静态 IP（如 `game.example.com`）。裸 IP 拿不到公共证书，域名必须有。
3. **GCP 防火墙**（VPC 防火墙规则）：
   - ✅ 放行 TCP 80（证书签发校验用）+ TCP/UDP 443（业务流量）
   - ❌ **不放行** 8080/8081（明文后端）与 5432/6379（数据库/Redis）——基础 compose 为开发便利把它们发布到了宿主机，公网安全完全靠防火墙收口，这四个口一个都不能开。

## 三、部署步骤（在 GCP 机器上）

```bash
git clone <repo> && cd <repo>/server
git checkout release                      # 发布用 release 分支

cp .env.example .env                      # 填真值（真值只存在这台机器，永不进仓库）
# .env 里五处必改（样板里都有 ⚠️公网必改 标记）：
#   POSTGRES_PASSWORD =  openssl rand -base64 24 的输出
#   DB_URL            =  postgres://app:<同上密码>@postgres:5432/gcp?sslmode=disable
#   JWT_SECRET        =  openssl rand -hex 32 的输出（泄露=可伪造任意账号，最重要的一个）
#   DOMAIN            =  你的域名（如 game.example.com）
#   ACME_EMAIL        =  你的邮箱

docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

**部署后验证**（当场做完再发链接给测试人员）：

```bash
curl -s https://$DOMAIN/healthz                    # 期望 200 ok（api 经 Caddy）
curl -si https://$DOMAIN/v5/session/ws \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA=="
#   期望 HTTP/1.1 101（gateway 经 Caddy 完成 WS 升级；随后因无 token 被服务器关闭属正常）
docker compose logs caddy | tail -5                # 无证书报错（certificate obtained）
```

## 四、Release 打包检查单（客户端，给 Antigravity/打包人）

打包前逐项过，缺一不可：

- [ ] `config/network.json` 三个地址全部指向域名且为加密协议（**只有一个主机名，路径照抄**）：
  ```json
  {
    "api_url": "https://game.example.com",
    "ws_url": "wss://game.example.com/v4/battle/ws",
    "session_ws_url": "wss://game.example.com/v5/session/ws"
  }
  ```
- [ ] 安卓包**不需要**开 cleartext 明文豁免（wss/https 天然合规——这正是当年定「方式 B」的兑现）；
      导出模板里如果曾开过 `usesCleartextTraffic`，这次关掉。
- [ ] Godot 对正规 Let's Encrypt 证书开箱即用（内置系统 CA 信任），客户端**无需任何代码/证书配置**。
- [ ] 打包用 release 分支、且已从 master 合并到含 KAN-110 的版本（有 `server/docker-compose.prod.yml` 即对）。
- [ ] 装包实测一条龙：登录页注册 → 引导战 → 主界面（验证 https 与两条 wss 全通）。

## 五、日常运维速查

| 事项 | 命令/说明 |
|---|---|
| 更新版本 | `git pull && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build` |
| 改了 logic/ 或 config/ | 照仓库铁律 `docker restart server-verifier-1`；新增卡牌另需重启 api |
| 看业务日志 | `docker compose logs -f api gateway` |
| 看访问日志 | `docker compose exec caddy cat /var/log/caddy/access.log`（**query 已脱敏**，见下） |
| 证书状态 | `docker compose logs caddy \| grep -i cert`；证书在 `caddy_data` 卷，删卷会触发重签 |
| 数据备份 | `docker compose exec postgres pg_dump -U app gcp > backup.sql` |

## 六、本地冒烟模式（开发机验证反代配置，无需域名）

`.env` 里 `DOMAIN=localhost`（Caddy 自动改用内部自签 CA）+ `CADDY_HTTP_PORT=8088`、`CADDY_HTTPS_PORT=8443`（避开本机占用），
同一条 `-f -f up -d` 启动后：`curl -sk https://localhost:8443/healthz` 应回 200。
自签证书 curl 要 `-k`；Godot 客户端不认自签属正常——端到端 wss 验证放在真域名部署后做。
冒烟完 `docker rm -f server-caddy-1` 即回纯开发环境（基础 compose 不受 overlay 影响）。

## 七、安全边界声明（E2-lite ≠ 完整 E2，勿混淆）

本方案**已经覆盖**：传输加密（token/对局数据不再明文裸奔）、中间人不可见 URL、访问日志 query 脱敏
（WS token 在 URL 里，Caddyfile 的 log filter 把 query 替换为 REDACTED——这条配置勿删）、强随机 secrets。

本方案**明确没做**（用户 2026-07-16 拍板接受，限「域名只发给测试人员」的前提）：
- ❌ 登录仍是 username 裸登录（知道名字即可顶号）——KAN-109 已知边界
- ❌ GM 端点 `/v5/gm/*` 仍对所有登录者开放（可自助刷资源）
- ❌ 无 WS ticket / Origin 白名单 / 限流

**触发升级完整 E2 的条件**：域名要公开张贴、或测试范围超出可信人员时，先做完 PLAN_V5.md §13 E2
全项（凭证/去GM/ticket/限流）再扩散，参见 [../security/AUTH_AND_WS_TICKETS.md](../security/AUTH_AND_WS_TICKETS.md)
与 [PRODUCTION_GATES.md](PRODUCTION_GATES.md)（正式上线门禁不因本手册放宽）。
