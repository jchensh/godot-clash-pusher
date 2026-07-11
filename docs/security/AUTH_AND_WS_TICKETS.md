# 认证与 WebSocket Ticket 契约

状态：E0 目标契约；替代当前 URL 携带 access JWT 的方式。

## 1. Token 类型

| 凭据 | 建议 TTL | 存储/传输 | 重放控制 |
|---|---:|---|---|
| access JWT | 15 分钟 | 客户端安全存储；HTTPS Authorization Bearer | 短 TTL、aud/iss/kid/jti、账号 session version |
| refresh token | 30 天滑动，90 天绝对上限 | 仅认证端点；服务端只存 hash | 每次轮换、token family、旧 token 重用即吊销整族 |
| WS ticket | 30 秒，未使用即过期 | HTTPS 换取；WSS 首帧发送 | 128-bit+ 随机、服务端 hash、原子一次兑换 |
| connection epoch | 单连接 | 首帧响应后内存持有 | 同账号/用途旧 epoch 失效 |

TTL 是 E1 的安全默认值；如业务要调整，必须经过威胁评审与压测，不能退回 30 天 access token。

## 2. HTTP 认证流程

1. 登录/refresh 返回 access 与 refresh；响应头 `Cache-Control: no-store`。
2. access 只出现在 `Authorization: Bearer`，禁止 query、path、日志和指标 label。
3. refresh rotation 在一个事务中执行：锁定族 → 验证 hash/状态 → 标旧 token 已用 → 签发新 token → 提交。
4. 检测到已用 refresh 再次出现时，吊销族并要求重新登录。
5. 多并发 401 只允许一个 refresh 在客户端飞行，其余请求等待同一结果。

## 3. WS ticket 换取

`POST /v1/ws-tickets`

```json
{
  "purpose": "session|battle",
  "battle_id": "optional",
  "client_build": "1.2.3",
  "protocol_version": 4,
  "config_version": "sha256"
}
```

请求使用 access Bearer。成功响应只返回一次明文 ticket：

```json
{
  "ticket": "opaque-random-secret",
  "expires_in_ms": 30000
}
```

服务端保存 ticket hash、account id、purpose、battle/side、build/protocol/config、issued/expires、used_at。Redis 使用原子 GETDEL 或 Lua compare-and-delete；数据库不是热路径。

## 4. WSS 首帧认证

- 客户端连接固定 URL，例如 `wss://game.example.com/ws/session` 或 `/ws/battle`；URL 不带 token/ticket。
- Upgrade 成功后 5 秒内第一条二进制 protobuf 必须是 `WsAuth{ticket, client_nonce}`；认证前只允许这一帧，最大 1 KiB。
- Gateway 原子兑换 ticket，校验 purpose、过期、版本和可选 battle/side，返回 `WsAuthOk{connection_epoch, heartbeat_ms, server_time_ms}`。
- 任一失败使用统一关闭码并关闭连接；不得在 reason 中回显 ticket 或账号细节。
- 首帧超时、超限、错误消息或重复认证立即关闭。认证成功后清除 ticket 明文引用。

## 5. Origin 与代理

- 浏览器/Web 构建只接受精确 HTTPS Origin allowlist；不使用 `*` 或后缀模糊匹配。
- 原生 Godot 可能不发送 Origin，但仍必须持有有效单次 ticket；是否允许空 Origin 由环境配置明确决定，Prod 默认只允许已知原生客户端 user-agent 不是安全控制，ticket 才是控制。
- Caddy access log 不记录 query/header/body；Authorization、Cookie、ticket 字段一律 redact。
- 只信任来自已知代理网段的 forwarded header；限流源 IP 从受信代理链解析。

## 6. 密钥与轮换

- JWT 使用非对称签名（EdDSA/ES256 优先）或至少每环境独立的强密钥；`kid` 支持双钥轮换。
- Dev/Staging/Prod 密钥完全隔离，来自 secret manager，不进入 compose、仓库、镜像层或命令行。
- 轮换顺序：发布新验证钥 → 用新签名钥签发 → 等旧 access 最大 TTL → 移除旧钥。

## 7. 验收测试

- 同一 ticket 并发兑换只有一个成功；过期、错 purpose、错 battle、错版本均失败。
- WSS URL、Caddy/Gateway 日志和错误追踪中无 JWT/ticket。
- 非 allowlist Origin、认证前业务帧、首帧超时、超大帧均被关闭。
- refresh 并发轮换、旧 token 重放、账号 session version 吊销均有集成测试。
