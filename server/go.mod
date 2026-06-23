module github.com/jchensh/godot-clash-pusher/server

go 1.23

// V4-S0b: 仅声明模块路径，无外部依赖。
// 后续按需添加：
//   - github.com/coder/websocket           (S3, gateway WS)
//   - github.com/jackc/pgx/v5              (S2, PostgreSQL driver)
//   - github.com/redis/go-redis/v9         (S4, Redis client)
//   - google.golang.org/protobuf            (S0e, proto runtime)
//   - github.com/golang-jwt/jwt/v5         (S1, JWT)

require google.golang.org/protobuf v1.36.11
