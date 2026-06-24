module github.com/jchensh/godot-clash-pusher/server

go 1.25.0

// V4-S0b: 仅声明模块路径，无外部依赖。
// 后续按需添加：
//   - github.com/coder/websocket           (S3, gateway WS)
//   - github.com/jackc/pgx/v5              (S2, PostgreSQL driver)
//   - github.com/redis/go-redis/v9         (S4, Redis client)
//   - google.golang.org/protobuf            (S0e, proto runtime)
//   - github.com/golang-jwt/jwt/v5         (S1, JWT)

require (
	github.com/golang-jwt/jwt/v5 v5.3.1
	github.com/gorilla/websocket v1.5.3
	github.com/jackc/pgx/v5 v5.10.0
	google.golang.org/protobuf v1.36.11
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/sync v0.17.0 // indirect
	golang.org/x/text v0.29.0 // indirect
)
