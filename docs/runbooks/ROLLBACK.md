# 发布回滚 Runbook

状态：E0 基线。

## 1. 原则

- 回滚的是不可变镜像 digest 与 config bundle，不在运行容器内改文件。
- 数据库采用 expand/contract；发布窗口内旧、新服务都能读写 expand 后 schema。破坏性 contract 只能在旧版本退出且观察期结束后执行。
- Gateway 状态尚未外置，因此回滚必须使用单活排空切换，不能直接把旧/新副本同时接流量。

## 2. 触发

认证失败率、WS 建连/断线、争议结算、经济不变量、PVE verifier backlog、5xx/延迟或资源使用超过发布阈值；发现 token/GM/数据越权立即停止发布并按安全事件处理。

## 3. 步骤

1. 冻结继续发布和 migration，记录 incident/request id、当前 digest/config/migration。
2. 若是配置问题，阻止新开战，恢复上一 bundle；进行中战斗继续使用其绑定版本。
3. 若是服务问题，部署上一 digest 并验证 `/livez`、`/readyz`、版本和最小烟测。
4. 新实例 ready 后，按 `GATEWAY_DRAIN.md` 排空故障 Gateway，再切流。
5. 验证登录、ticket/WSS、配置、经济读写、最小 PVE/PVP；核对重复/缺失结算。
6. 保留故障制品与日志，更新 Jira/事件时间线。没有证据不得“修复性清库”。

## 4. 数据库例外

禁止自动 down migration。只有经过备份恢复演练、确认无新格式数据且得到明确审批时，才执行数据回退。否则保持 expand schema，回滚应用并后续修复。
