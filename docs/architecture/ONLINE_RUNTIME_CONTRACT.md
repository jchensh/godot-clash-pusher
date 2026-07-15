# 在线运行时契约

状态：E0 目标契约（KAN-103）。E1（KAN-105）已落实唯一在线运行时、服务器配置 gate、经济写 fail-closed、Gateway/API 复合故障降级与自动恢复；WS ticket/首帧认证仍是 E2 目标，因此本文完整契约仍不代表当前代码已经全部实现。

## 1. 适用范围与真相源

- 适用于 Godot 客户端、Go API、Gateway、PVE verifier，以及入口反向代理。
- 账号、钱包、养成、关卡进度、挂机时间和运行时配置由服务端与 PostgreSQL 权威持有。
- 战斗仍采用 10Hz 客户端确定性 lockstep；服务端权威分发输入、保存对局事实并执行校验。
- 当前实现证据见 `net/online_runtime.gd`、`net/session_conn.gd`、`view/game_state.gd`、`server/cmd/{api,gateway}/main.go`。上线门禁见 `docs/deployment/PRODUCTION_GATES.md`。

## 2. 生命周期状态机

| 状态 | 可做 | 禁止 | 退出条件 |
|---|---|---|---|
| `BOOTSTRAP` | 读取本地非权威版本缓存、发现服务地址 | 进入任何会写在线进度的页面 | 开始认证 |
| `AUTHENTICATING` | 登录或 refresh；显示可重试错误 | 使用过期 token；静默进入离线业务 | access token 有效 |
| `CONNECTING` | 换取 WS ticket、建立 WSS、首帧认证 | 把长期 JWT 放入 URL | 首帧认证成功 |
| `ONLINE_READY` | 接收配置、拉取权威快照、进入在线功能 | 在配置未就绪时开始战斗或经济动作 | 配置版本和经济快照就绪 |
| `DEGRADED` | 保留当前只读画面、展示重连状态、指数退避重连 | 新开战、领奖、升级、匹配或使用本地结果补写 | 恢复 `ONLINE_READY` 或退出 |
| `FORCE_UPDATE` | 展示最低版本要求和更新入口 | 继续访问业务 API/WS | 安装兼容版本 |
| `SIGNED_OUT` | 回到登录页、清理会话密钥 | 继续持有可用 refresh token | 重新认证 |

生产构建中“断线不可玩”的精确定义是：断线后不再接受任何会改变服务端状态或产生待补写结果的操作；已加载页面可只读展示。不得自动退回本地权威模式。

## 3. 启动与恢复顺序

1. 客户端只从环境构建配置读取 HTTPS API 基址，不接受运行时任意 URL 覆盖。
2. refresh/login 成功后，使用 Bearer access token 请求一次性 WS ticket。
3. 通过 WSS 建连；ticket 只用于握手路由，随后必须在限定时间内完成首帧认证。
4. 服务端发送配置版本；客户端以服务器版本覆盖本地薄缓存。
5. 客户端拉取账号/经济权威快照；两者成功后才进入 `ONLINE_READY`。
6. 重连必须重新换 ticket；旧连接、旧 ticket 和旧 epoch 均不可复用。

## 4. 离线训练边界

- Prod 不提供自动离线降级。
- 如保留 `offline_training`，必须是显式构建特性：独立入口、醒目标记、只用固定演示配置、无登录凭据、无在线奖励、无回放补写、无排行榜或任务进度。
- `offline_training` 的本地结果永远不能转换为在线资产或通关记录。

## 5. 失败语义

| 类别 | 客户端行为 | 服务端行为 |
|---|---|---|
| 401 access 失效 | 单飞 refresh；失败则 `SIGNED_OUT` | 不泄露账号是否存在 |
| 403 Origin/版本/环境拒绝 | 停止重试并展示可诊断错误 | 结构化记录拒绝原因 |
| 409 状态冲突 | 重新拉取权威快照，不做本地合并 | 返回当前版本/epoch |
| 429 限流 | 尊重 `Retry-After`，抖动退避 | 按 IP、账号、设备和路由限流 |
| 5xx/断线 | 进入 `DEGRADED`，有上限地重连 | 保持幂等；不得半提交经济事务 |

E1 运行时补充：Gateway WS 在线只代表会话通道存活，不等于权威 API 可写。经济/PVE transport 失败或 5xx 必须把 Online 降为 `DEGRADED`；API 快照重新同步成功后才能恢复 `ONLINE_READY`。PVE 战后最终证据与 StageClear 均为 single-flight：失败留在原地重试，pending 只在服务器确认后清除；相同 battle claim 重试由服务端幂等返回且不重复发奖。

## 6. 可验证门禁

- 生产包扫描不到 `http://`、`ws://`、localhost 或 GM 路由入口。
- 主流程实际持有且驱动唯一 `SessionConn`；配置就绪前业务入口被 gate。
- 断网测试中，升级、领奖、匹配和新开战均不可操作且不会生成待补写数据。
- access token 不出现在 URL、反代 access log、错误页、指标 label 或客户端普通日志。
- 所有跨进程写操作具有 request id / idempotency key，并可从日志追到最终结果。
