# 上线威胁模型

状态：E0 基线，覆盖 Staging/Prod 的客户端、边缘入口、API、Gateway、Redis、PostgreSQL 与 verifier。

## 1. 保护资产

- 账号身份、refresh/access token、WS ticket 和设备标识。
- 钱包、卡牌养成、关卡进度、MMR/杯数、奖励与挂机时间。
- 对局输入、hash、结算证据、配置包和发布制品。
- 数据库、Redis、签名密钥、日志与备份。

客户端设备、移动网络、代理链和客户端提交的所有字段均不可信。内部网络降低暴露面，但不构成鉴权。

## 2. 主要威胁与控制

| 威胁 | 当前证据/风险 | 必须控制 | 上线验证 |
|---|---|---|---|
| URL 泄露长期 JWT | WS 客户端与 Gateway 当前使用 `?token=` | 长期 JWT 仅走 Authorization；WS 使用短时单次 ticket + 首帧认证 | 代理/API/Gateway 日志扫描无 JWT |
| 跨站 WS 劫持 | Gateway 当前 `CheckOrigin=true` | HTTPS/WSS；严格 Origin allowlist；无 Origin 的原生客户端走签名 ticket | 非 allowlist 握手 403 |
| refresh 重放 | 长 TTL 且缺少服务端轮换族状态 | refresh rotation、jti/族、重用检测、撤销 | 旧 refresh 第二次使用失败并吊销族 |
| GM 越权增发资产 | 当前所有部署挂载 `/v5/gm/*` | Staging 独立构建/路由；Prod 二进制路由表不存在 GM | Prod 路由探测 404，制品字符串门禁 |
| 暴力登录/资源耗尽 | 匿名登录、WS、匹配和未来 tick 可放大 | 分层限流、请求/帧/队列/房间上限、慢消费者断开 | 压测不导致无界内存增长 |
| 经济重放/重复提交 | 网络重试可能重复写 | 幂等键、唯一约束、事务内校验、权威响应 | 相同请求并发只成功一次 |
| 对局结果伪造 | 客户端 lockstep 与上报结果 | 权威输入、hash 证据、冲突 fail closed、PVE verifier | 篡改/缺报/冲突用例拒绝奖励 |
| 配置降级/错版 | 客户端仍可直接读本地配置 | 签名/摘要版本包、最低 build、对局绑版本 | 三进程版本不一致时 not ready |
| 内网横向移动 | 本地 compose 暴露 PG/Redis | 私网、最小端口、安全组、每服务独立凭据 | 公网端口扫描仅 80/443 |
| 供应链/秘密泄露 | dev 默认值和镜像构建 | 固定依赖、镜像扫描、secret manager、日志脱敏 | 仓库/镜像 secret scan 通过 |

## 3. 信任边界

1. 公网到 Caddy/LB：只开放 443（80 仅重定向），TLS 终止、请求大小和连接速率限制。
2. 边缘到 API/Gateway：私网、显式 upstream、透传 request id；不信任客户端转发的 `X-Forwarded-*`。
3. 服务到 PG/Redis：私网、认证/TLS、最小权限账号；数据库不对公网。
4. API 到 verifier：异步任务边界；外部进程不可持有长数据库事务。
5. 服务到日志/指标：字段白名单和脱敏；token、ticket、Authorization、设备原值不可记录。

## 4. 安全默认值

- 拒绝未知 Origin、未知环境、未知版本、超限帧、重复结算和冲突结果。
- Prod 不存在 GM/调试路由、pprof 公网入口或开发默认密钥。
- 错误响应不回显内部 SQL、栈、token、配置内容或账号存在性。
- 所有安全例外必须有 owner、到期日、补偿控制和 Jira issue；无到期例外不得上线。

## 5. 发布前攻击用例

- 重放旧 refresh、旧 WS ticket、旧 connection epoch 和重复经济请求。
- 伪造 Origin、Host、`X-Forwarded-For`，注入超长 header/query/frame。
- 慢读 WS、突发未来 tick、hash 洪泛、断线重连风暴。
- 双方提交冲突胜负、PVE 命令/配置版本篡改、verifier 超时。
- 在 Prod 探测 GM、health、metrics、pprof、数据库和 Redis 端口。
