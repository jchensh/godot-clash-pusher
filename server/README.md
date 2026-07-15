# server — V4 Go 服务端

V4 联网升级的服务端代码。**当前阶段 = V4-S0b 脚手架**（4 个 cmd 占位 + 1 个 internal 示范包），实际逻辑从 V4-S1（匿名登录）起逐步加。

权威规划见 [PLAN_V4.md](../docs/PLAN_V4.md)；目录结构参考 §9。

## 目录结构

```
server/
├── cmd/
│   ├── gateway/          # WS 接入主进程（V4-S3 起）
│   ├── api/              # HTTP API：登录/档案/匹配/榜（V4-S1 起）
│   ├── battle/           # 战斗 room 主进程（V4-S3 起；前期可合并进 gateway）
│   └── migrate/          # DB migrations runner（V4-S1 起）
├── internal/
│   ├── version/          # 跨 cmd 共享的版本常量（已有）
│   ├── auth/             # JWT / refresh / device login（V4-S1 起）
│   ├── profile/          # 玩家档案 CRUD（V4-S2 起）
│   ├── matchmaking/      # Redis ZSET 队列（V4-S4 起）
│   ├── battle/           # room / lockstep / 哈希仲裁（V4-S3 起）
│   ├── leaderboard/      # ZSET 读写（V4-S5 起）
│   ├── season/           # cycle / 软重置（V4-S5 起）
│   ├── store/            # PG / Redis 客户端封装（V4-S1 起）
│   └── pb/               # protoc 生成产物（V4-S0e 起；入 git，便于新人 clone 即编译）
├── migrations/           # SQL up/down（V4-S1 起）
├── Dockerfile            # 服务端镜像（V4-S0c 加）
├── docker-compose.yml    # 仓库根级，含 pg+redis+server（V4-S0c 加）
├── Makefile              # 根级 gen-proto/test/up/down/migrate（V4-S0d 加）
├── go.mod
└── README.md
```

每个 `internal/*` 子包按需在对应 V4-Sx 步骤新增；不预先建空目录（守"不过度设计"）。

## 本地开发

前置：Go 1.23+、protoc、Docker Desktop（运行容器化 pg+redis 时）、make。Windows winget 一键装见 [docs/ENVIRONMENT.md](../docs/ENVIRONMENT.md)。

```bash
# 编译全部 cmd（V4-S0b 起可用）
go build ./...

# 跑全部单测
go test ./...

# 生成 protobuf 代码（V4-S0e 起可用）
make gen-proto

# 起 pg + redis + server 三容器（V4-S0e 起可用）
make up
```

V4-S0b 期 4 个 cmd 都是占位，只打印一行 boot log 后退出；不监听端口、不连数据库。
