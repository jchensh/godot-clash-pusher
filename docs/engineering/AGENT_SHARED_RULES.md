# 智能体共享工程规则

本文件是 Claude Code、Codex 及其他仓库智能体的共享规则真相源。根级 `AGENTS.md` 与 `CLAUDE.md` 可保留工具专属说明，但不得覆盖本文件；二者的 `AGENT-SHARED` 镜像块必须逐字一致，由 `tools/check_docs.py` 和 CI 校验。

## 真相源优先级

1. 用户当前明确指令。
2. `PLAN_GRAND.md` 与当前阶段 `PLAN_V5.md` 的产品/架构决策。
3. `HISTORY.md` 与 Jira KAN 的实时进度、验收和变更记录。
4. 本文件与根级智能体手册的操作纪律。
5. 归档 PLAN/HISTORY 只用于历史查证，不得反向覆盖当前决策。

出现冲突必须停下并指出冲突，不得自行选一个“看起来合理”的版本继续。

## 共同施工纪律

- 一步一确认；每次只完成已批准步骤，报告差异和验证后等待用户确认。
- 开工前 Jira 进入 `In Progress`；完成且测试通过后仍保持未完成状态，只有用户明确同意提交时才转 `Done`。
- 每步更新 `HISTORY.md`，但历史记录只追加，不改写旧决定；新决定明确写“取代/收紧”旧决定。
- 用户说“提交”后才 commit，并按仓库约定 push；禁止擅自 commit/push、force push、跳过 hook。
- 只改任务范围内文件，保留工作树既有改动和未跟踪资源。
- 会占用 Godot、Docker、端口、数据库或外部环境前，先检测占用；如由另一个 agent/worktree 使用，取得用户许可后再操作。

## 在线工程边界

- Prod 强制登录、持久连接，断线只读/重连，不自动降级为可写离线模式。
- 账号、经济、养成、进度、服务器时钟和在线配置由服务端权威；客户端缓存非权威。
- 长期 JWT 禁止进入 URL；Gateway 目标为短时单次 WS ticket + 首帧认证、Origin allowlist。
- Prod 制品和路由表不得包含 GM；GM 仅允许 Staging 隔离环境。此规则是 E0 对 V5-S9“Prod 常开 GM”历史决定的安全收紧，运行时代码须在后续步骤落实。
- Gateway 状态外置前只允许单 active 实例；多副本必须先满足状态/重连/匹配一致性门禁。
- Staging/Prod 发布必须通过 `docs/deployment/PRODUCTION_GATES.md`；目标契约不能写成当前已实现事实。

## 共享文档维护

- 当前进度只在 `HISTORY.md` 与 Jira 维护；根级智能体手册只保留短摘要和链接，避免复制长时间线。
- 新增架构决定用 ADR；部署操作用 runbook；上线条件用 gate checklist。
- 文档纪律（2026-07-12 起）：单文档目标 ≤300 行，超限先拆分/归档再追加；版本线或子步收官后，其 HISTORY 详细段随该步搬入 `docs/HISTORY_*_DETAILED.md` 归档、已收官 PLAN 移入 `docs/`；新专题开新文件并在 `docs/README.md` 文档地图登记一行，不往既有长文件追加异质内容。
- 修改 `AGENT-SHARED` 镜像块时必须同时修改 `AGENTS.md` 与 `CLAUDE.md`，并运行 `python tools/check_docs.py`。
