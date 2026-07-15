# 配置权威与版本契约

状态：E0 目标契约。服务端是在线运行时配置权威；仓库 JSON/XLSX 是发布输入，不是已登录客户端的最终权威。

## 1. 配置分层

| 层 | 内容 | 权威性 |
|---|---|---|
| 源文件 | `config/*.json`；部分由 XLSX 镜像生成 | 构建/发布输入 |
| 服务端 bundle | 经校验、签名/摘要、带版本的不可变包 | 在线会话权威 |
| 客户端内存 | 当前会话已验证 bundle | 展示与 lockstep 计算输入 |
| 客户端磁盘薄缓存 | 最近一次完整 bundle | 仅加速启动，未确认前不可开业务 |

## 2. 版本身份

- `config_version` 必须由规范化 bundle 字节的 SHA-256 得出，不接受人工可变别名作为唯一身份。
- bundle 元数据至少包含 schema version、config version、created at、minimum client build、protocol version 和适用环境。
- 客户端上报其缓存版本；服务端只返回 `up_to_date` 或完整权威包。差量更新在有实际带宽证据前不做。
- API、Gateway、verifier 必须暴露当前 config/build/protocol 版本；三者不一致时 `/readyz` 失败。

## 3. 应用规则

- bundle 必须先完整解析、schema 校验、交叉引用校验和摘要校验，再一次性替换内存快照；失败保留旧快照并禁止进入在线 ready。
- 正在进行的战斗固定使用开战时版本；发布新配置不得热切换已开局计算输入。
- battle/PVE 记录必须保存 config version；verifier 必须按该版本复算，不得默认使用“当前最新”。
- 服务端拒绝未知或已撤销版本的新开战；旧版本宽限由发布策略显式配置。
- 客户端本地 `ConfigLoader.load_all()` 只能用于 bootstrap、离线训练或加载待服务器确认的缓存；不能绕过会话配置 gate。

## 4. 发布与回滚

1. CI 生成 bundle 并运行 JSON↔XLSX、schema、引用和摘要检查。
2. Staging 同一制品完成客户端/API/Gateway/verifier 契约测试。
3. Prod 先发布可兼容旧客户端的服务端，再灰度客户端；不允许破坏性 schema 原地覆盖。
4. 回滚恢复上一不可变 bundle 和兼容服务制品；数据库迁移必须遵守 expand/contract。
5. 每次发布保留 bundle、摘要、来源 commit、审批人和回滚目标。

## 5. 门禁

- 客户端未收到并应用权威 bundle 时，匹配、开战和经济写入口不可用。
- 配置包大小、解析时长、失败次数和版本分布可观测。
- 单测覆盖损坏包、摘要不符、schema 不兼容、旧版本重连、战斗中版本切换和回滚。
