// Package store provides persistence-layer helpers around PostgreSQL (and Redis
// in V4-S4+). It is intentionally thin — higher-level packages (auth, profile,
// ...) compose SQL inline rather than going through a heavy ORM.
package store

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// DB wraps a pgxpool.Pool. Higher layers depend on this concrete type so they
// can use pgxpool.Begin / QueryRow / Exec directly; we don't hide the driver
// behind a database/sql shim.
type DB struct {
	Pool *pgxpool.Pool
}

// Open establishes a pgxpool from a libpq-style DSN, e.g.
//
//	postgres://app:dev@postgres:5432/gcp?sslmode=disable
//
// The caller owns the returned *DB and must call Close.
func Open(ctx context.Context, dsn string) (*DB, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("pgxpool.New: %w", err)
	}
	return &DB{Pool: pool}, nil
}

// Close releases the underlying connection pool. Safe to call on nil.
func (db *DB) Close() {
	if db == nil || db.Pool == nil {
		return
	}
	db.Pool.Close()
}

// Ping verifies the pool can reach PostgreSQL.
func (db *DB) Ping(ctx context.Context) error {
	if db == nil || db.Pool == nil {
		return fmt.Errorf("nil DB")
	}
	return db.Pool.Ping(ctx)
}
