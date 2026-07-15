# ADR-0002：服务端配置包为在线权威

- 状态：Accepted（沿用决策 48，由 E0 工程化）

## 决策

仓库 JSON/XLSX 是构建输入；在线客户端只有在登录会话收到并验证服务端 bundle 后，才可进入业务 ready。客户端磁盘缓存永远非权威，服务端、客户端和 verifier 必须以 config version 绑定一次战斗。

## 后果

- 客户端不得以直接加载仓库/包内 JSON 作为在线主流程最终配置。
- 配置发布必须生成不可变版本并支持旧版本宽限及回滚。
- verifier 必须能取得对局绑定版本，不能只复算当前最新配置。

详细契约见 `docs/architecture/CONFIG_AUTHORITY.md`。
