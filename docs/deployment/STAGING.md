# Staging 部署基线

状态：E0 目标拓扑；当前 `server/docker-compose.yml` 仅用于本地开发，不是 Staging 清单。

## 1. 目标拓扑

```text
Internet
  -> Caddy / managed LB (public 443; TLS, limits, request id)
       -> API (private)
       -> single active Gateway (private; WSS)
  private network
       -> verifier worker
       -> PostgreSQL
       -> Redis
```

公网只暴露 443；80 仅做 HTTPS 重定向。API、Gateway、verifier、PG、Redis、metrics 和管理端点不分配公网监听。Staging 使用独立域名、数据库、Redis、对象/日志空间和密钥，不与 Prod 共享状态。

## 2. 制品与配置

- 同一 Git commit 生成带 digest 的 API/Gateway/verifier 镜像；禁止 `latest`。
- 运行时以只读 root filesystem、非 root 用户、drop capabilities、资源 requests/limits 启动。
- 配置通过环境/挂载的不可变 bundle 注入；secret 来自 secret manager，启动时校验缺失即退出。
- migration 是部署前独立 job；成功后才允许新服务 ready。服务启动不得自动执行不可逆迁移。
- 客户端 Staging 包只指向 Staging HTTPS/WSS 域名，构建产物扫描不得含 Prod 密钥或本地地址。

## 3. Caddy 入口责任

- TLS 1.2+、自动续期/HSTS（确认全域 HTTPS 后启用）、HTTP/2；WS 正确透传。
- `/api/*` 路由 API，`/ws/*` 路由唯一 active Gateway；管理/metrics 路径不对公网。
- access log 采用字段白名单：request id、route、status、duration、bytes、受信源 IP；不记录 query、Authorization、Cookie、WS 首帧或响应 body。
- 设置 header/body 大小、HTTP 超时、每 IP 连接/请求速率、WS 握手速率和并发上限。
- CORS 精确列出允许的 HTTPS Origin、method 和 header；原生客户端不依赖 CORS 作为鉴权。

## 4. 探针契约

| 服务 | `/livez` | `/readyz` |
|---|---|---|
| API | 进程事件循环可响应 | 非 shutdown；配置有效；migration 版本匹配；PG/Redis 必需依赖可用 |
| Gateway | HTTP/WS 事件循环可响应 | 非 drain；配置/协议版本有效；持久化与匹配依赖可用；容量未触顶 |
| verifier | worker loop 活着 | PG 可用；Godot verifier 可执行；配置/build 版本匹配；队列未被人工暂停 |

`/livez` 不能因为外部依赖短暂失败而触发重启风暴；`/readyz` 可在依赖失败或 drain 时摘流。探针响应不泄露 DSN、版本密钥或内部错误栈。

## 5. Staging 验收

1. 从空环境执行 migration、部署、探针和烟测；无需手工进容器改文件。
2. 完成登录 → ticket → WSS 首帧认证 → 配置下发 → 经济快照 → PVE/PVP 最小闭环。
3. 验证 Prod-like 安全：GM 仅在 Staging 域名和 Staging 制品存在，非 allowlist Origin 被拒。
4. 对 Gateway 执行 SIGTERM 排空演练；新会话被拒、旧对局按预算完成、超时行为可解释。
5. 执行前一版本回滚和兼容 migration 演练。
6. 执行慢消费者、重连风暴和 verifier 超时故障注入，确认资源有界与告警触发。
