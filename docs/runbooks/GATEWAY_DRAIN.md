# Gateway 优雅排空 Runbook

状态：E0 操作契约；当前 Gateway 尚未实现完整 drain，本文是后续代码验收标准。

## 1. 触发与预算

触发：滚动发布、节点维护、容量迁移或 SIGTERM。默认总预算应由环境配置，例如 120 秒；编排器 termination grace 必须大于应用预算再加安全余量。

## 2. 状态机

```text
SERVING -> DRAINING -> QUIESCED -> STOPPING -> EXITED
              \-> DEADLINE_FORCED
```

1. 收到 SIGTERM 后原子进入 `DRAINING`，重复信号幂等；第二次人工强制信号可立即退出。
2. `/readyz` 立刻失败，Caddy/LB 摘除；`/livez` 保持成功。
3. 停止签发/兑换本实例新 session/battle ticket，拒绝新 WS、新匹配和新房间。
4. 从匹配队列移除本实例等待者，向客户端返回可重试状态；不把半匹配留在 Redis。
5. 已认证 session 可收到维护通知；已有房间继续到自然结束或 deadline。
6. 房间结束后幂等持久化，释放重连索引、历史、连接和计时器。
7. 所有房间/写任务清零进入 `QUIESCED`，再关闭 HTTP server、DB/Redis、日志并退出 0。
8. deadline 到达时，把未完成房间标记为明确的中止原因，执行可重试持久化/告警，关闭连接并退出非零或约定退出码。

## 3. 操作步骤

排空前：确认新实例 `/readyz` 成功且版本一致；确认只有一个 active Gateway；观察房间数、对局最长剩余时间和持久化错误。

排空中：观察 `drain_phase`、`gateway_rooms`、`connections`、`match_waiters`、`pending_persist`。若房间数不降，检查僵尸连接、无 deadline DB 调用和旧 context。

排空后：确认旧实例 not ready、连接归零、Redis 无孤儿 waiter、DB 无重复/缺失结算、Caddy 只路由新实例。

## 4. 禁止操作

- 不先摘 readiness 就直接 `Shutdown`。
- 不在排空期继续创建新房间。
- 不用无界 `context.Background()` 启动房间或持久化。
- 不因为 deadline 到达而静默丢弃对局/经济写；必须有最终状态和告警。
- 不在状态仍在进程内时进行双 active Gateway 滚动发布。

## 5. 演练用例

- 空闲实例 SIGTERM：5 秒内退出。
- 有等待者：等待者收到可重试错误，Redis 无残留。
- 有进行中短局：自然结束、结算一次、随后退出。
- 有慢消费者/断线重连：排空期间不接受新重连到旧实例，客户端转新实例后的失败语义明确。
- DB 短暂失败和 deadline 强退：不死锁，告警与补偿记录完整。
