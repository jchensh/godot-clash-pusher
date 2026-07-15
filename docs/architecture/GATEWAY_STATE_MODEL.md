# Gateway 状态模型

状态：E0 目标契约。近期拓扑采用单活 Gateway；在状态外置完成前，多副本不属于可用方案。

## 1. 状态所有权

| 状态 | 当前形态 | 近期责任方 | 生命周期上限 |
|---|---|---|---|
| WebSocket 连接与发送队列 | 进程内 channel | 单活 Gateway | 连接结束即释放 |
| 匹配等待者 | Redis ZSET + 进程内 waiter | Gateway + Redis | 匹配/取消/TTL |
| 房间、side、重连映射 | 进程内 map | 单活 Gateway | 对局结束 + 重连宽限 |
| tick 历史/ACK 水位 | 进程内 slice（当前为全历史） | Gateway | 有界重放窗口 |
| 账号经济/档案 | PostgreSQL | API | 持久 |
| 配置包 | 启动加载 + 下发 | API/Gateway，版本一致 | 发布版本 |

## 2. 并发与所有权规则

- 每个房间只有一个事件循环拥有可变房间状态；网络 goroutine 只向有界 inbox 投递事件。
- 锁内不得执行 socket 写、数据库调用、外部进程等待或可能阻塞的 channel send。
- 账号到连接、房间到账号的索引必须在同一所有权边界内原子增删；连接关闭、匹配取消、房间结束均执行幂等清理。
- 房间、等待者、未来 tick、hash、历史帧和重连记录必须有数量上限与 TTL；达到上限时 fail closed 并记录指标。
- 任何发送队列溢出不得静默丢权威帧。策略只能是断开慢消费者并允许其按 ACK 水位有界重连，或显式结束对局。

## 3. 重连协议目标

1. 客户端在每个 tick bundle 后确认最高连续 `ack_tick`。
2. 服务端只保留 `[ack_tick+1, current_tick]` 的有界环形窗口，并设最大 tick 数和最大字节数。
3. 重连携带 battle id、side、connection epoch、last ack；服务端拒绝旧 epoch。
4. 超出窗口时不尝试把全历史塞入发送队列：返回不可恢复状态并按明确规则判定/中止对局。
5. 重放完成前实时帧进入同一有序流，禁止重放与实时广播交错乱序。

## 4. 反作弊与结算不变量

- hash 对账按预定 tick cadence 执行；缺报、超前、冲突均有上限和明确处分。
- 双方结果冲突时必须 fail closed：进入 `DISPUTED`，不得采用“最后上报者”结果。
- 结算必须绑定 battle id、双方 account id、权威输入摘要、配置版本、build/protocol 版本和最终 hash 证据。
- `SaveMatch` 使用有 deadline 的上下文；失败进入可观测重试/补偿队列，不能用无界 `context.Background()` 静默悬挂。
- 同一 battle id 结算幂等，唯一约束防止重复奖励或重复调分。

## 5. 单活与扩容门禁

近期只允许一个可接收新 WS/匹配的 Gateway 实例。滚动发布使用“新实例启动并 ready → 旧实例停止接新会话 → 排空 → 退出”的串行切换，不能并行双活分流。

只有满足下列全部条件后才能讨论多活：房间目录/重连路由可跨实例发现；关键房间状态可恢复或迁移；匹配创建具分布式原子性；负载均衡具会话路由；故障演练证明单实例死亡可在目标 RTO/RPO 内恢复。

## 6. 最低指标

`gateway_connections`、`gateway_rooms`、`match_waiters`、`send_queue_fill_ratio`、`slow_consumer_disconnects_total`、`reconnect_replay_ticks`、`reconnect_failures_total{reason}`、`future_tick_entries`、`hash_mismatch_total`、`disputed_matches_total`、`drain_phase`。
