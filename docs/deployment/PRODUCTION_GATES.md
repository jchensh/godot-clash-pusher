# Production 上线门禁

状态：E0 门禁清单。任何 P0/P1 未通过均不得发布；“已有代码”不等于“已通过门禁”。

## P0 安全与权限

- [ ] 全链 HTTPS/WSS；生产包无 localhost、`http://`、`ws://`。
- [ ] access JWT 不进入 URL；WS ticket 30 秒内、单次、首帧认证。
- [ ] Gateway Origin 精确 allowlist；受信代理链正确。
- [ ] refresh rotation/jti/重用检测/撤销已集成测试。
- [ ] Prod 制品与路由表不存在 `/v5/gm/*`；探测为 404，而非仅 UI 隐藏或 env 默认关闭。
- [ ] JWT/DB/Redis/监控密钥来自 secret manager，各环境隔离且完成轮换演练。
- [ ] API/WS/登录/refresh/匹配/经济动作均有限流、大小和并发上限。

## P0 状态正确性与资源边界

- [ ] 单活 Gateway 由部署策略强制；副本数、路由和 PDB/更新策略不会短暂双活。
- [ ] send queue 溢出不静默丢权威帧；慢消费者行为有测试。
- [ ] 重连按 ACK 有界重放；历史、未来 tick、hash、房间和映射均有上限/TTL。
- [ ] 双方结果冲突 fail closed；结算绑定 battle/config/build/protocol/hash 证据且幂等。
- [ ] DB/Redis/外部 verifier 调用均有 deadline；无长事务包裹外部进程。
- [ ] PVE verifier 使用服务端生成/验证的完整权威输入，并能按对局配置版本复算。

## P0 生命周期与数据

- [ ] API/Gateway/verifier 实现区分 `/livez`、`/readyz`；依赖失败与 drain 语义正确。
- [ ] Gateway SIGTERM 排空在 Staging 压测下通过，且退出码/超时/未完成房间可追踪。
- [ ] migration 独立 job、expand/contract、备份恢复和回滚演练通过。
- [ ] 客户端断线进入只读/重连，不产生本地权威结果或补写队列。

## P1 可观测与交付

- [ ] 结构化日志含 request/battle/account pseudonym/config/build；不含 token、ticket、设备原值。
- [ ] RED/USE、业务不变量、队列/连接/房间/重连/争议结算指标和 SLO 告警就绪。
- [ ] CI 覆盖 Go test/vet/race、GDScript lint/单测、配置/文档校验、镜像/secret/依赖扫描。
- [ ] Staging 与 Prod 使用同一不可变制品，仅环境配置不同；镜像 digest 可追溯到 commit。
- [ ] Runbook owner、值班入口、回滚权限和事件分级已确认。

## 当前已知阻断（E0 时点）

以下为需要后续 E1+ 消除的现状，不在 E0 伪装为已完成：

- `server/cmd/gateway/main.go` 仍从 query 读取 access token 且 `CheckOrigin` 全放行。
- `server/cmd/api/main.go` 当前在所有部署挂载 GM；必须由后续实现撤销此前决定。
- 服务端当前只有 `/healthz`，尚未实现 readiness/drain 状态机。
- Gateway 房间/重连状态为进程内且存在无界/静默丢帧风险，只允许单活且仍需资源边界改造。
- `net/session_conn.gd` 尚未成为生产主流程的唯一持久会话/配置 gate。
- 仓库缺 Prod/Staging IaC 和 Caddy 配置；本地 compose 对外暴露端口且含开发默认值。

## 放行记录

每次发布在 Jira/变更记录中附：制品 digest、config version、migration version、门禁证据链接、已知例外、审批人、回滚目标和演练时间。
