// Command migrate applies all pending up-direction SQL migrations.
//
// V4-S1: real implementation.
//
// Environment:
//   DB_URL          postgres://user:pass@host:port/db?sslmode=disable  (required)
//   MIGRATIONS_DIR  directory holding NNNN_*.up.sql files
//                   default: /app/migrations  (matches Dockerfile COPY target)
//
// Exit codes:
//   0  all pending migrations applied (or none pending)
//   1  any failure (missing env, db unreachable, sql error, ...)
package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("migrate boot [%s build %s]", version.V4Stage, version.Build)

	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		log.Fatal("migrate: DB_URL env var is required")
	}
	dir := os.Getenv("MIGRATIONS_DIR")
	if dir == "" {
		dir = "/app/migrations"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	db, err := store.Open(ctx, dsn)
	if err != nil {
		log.Fatalf("migrate: open db: %v", err)
	}
	defer db.Close()

	if err := db.Ping(ctx); err != nil {
		log.Fatalf("migrate: ping db: %v", err)
	}

	n, err := store.Apply(ctx, db, os.DirFS(dir), ".")
	if err != nil {
		log.Fatalf("migrate: apply: %v", err)
	}
	log.Printf("migrate: applied %d migration(s) from %s", n, dir)
}
