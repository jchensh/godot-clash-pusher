package store

import (
	"context"
	"fmt"
	"io/fs"
	"path"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Migrations live under server/migrations/ as paired up/down SQL files:
//
//	0001_init.up.sql      0001_init.down.sql
//	0002_accounts.up.sql  0002_accounts.down.sql
//	...
//
// Only the .up.sql side participates in forward Apply; .down.sql files are
// here for documentation + manual rollback (the runner does not auto-rollback).
//
// Version numbers are 4-digit zero-padded ints; runner applies migrations in
// ascending order, in their own transactions, and records each as a row in
// schema_migrations(version, applied_at) inside the same transaction.

var migrationFilenameRe = regexp.MustCompile(`^(\d{4})_(.+)\.up\.sql$`)

// Migration is a single up-direction SQL migration parsed from disk/embed.
type Migration struct {
	Version int
	Name    string
	SQL     string
}

// ParseMigrationFilename parses "0002_accounts.up.sql" into (2, "accounts", true).
// Any name that doesn't match the strict NNNN_label.up.sql pattern returns ok=false.
func ParseMigrationFilename(name string) (version int, label string, ok bool) {
	m := migrationFilenameRe.FindStringSubmatch(name)
	if len(m) != 3 {
		return 0, "", false
	}
	v, err := strconv.Atoi(m[1])
	if err != nil {
		return 0, "", false
	}
	return v, m[2], true
}

// ReadMigrations scans fsys at dir for *.up.sql files and returns them sorted
// ascending by version. Files that don't match the pattern (e.g. .down.sql,
// README) are silently skipped. Duplicate version numbers return an error.
func ReadMigrations(fsys fs.FS, dir string) ([]Migration, error) {
	entries, err := fs.ReadDir(fsys, dir)
	if err != nil {
		return nil, fmt.Errorf("read dir %q: %w", dir, err)
	}
	seen := make(map[int]string)
	var migs []Migration
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		v, name, ok := ParseMigrationFilename(e.Name())
		if !ok {
			continue
		}
		if prev, dup := seen[v]; dup {
			return nil, fmt.Errorf("duplicate migration version %d: %q and %q", v, prev, e.Name())
		}
		seen[v] = e.Name()
		body, err := fs.ReadFile(fsys, path.Join(dir, e.Name()))
		if err != nil {
			return nil, fmt.Errorf("read %q: %w", e.Name(), err)
		}
		migs = append(migs, Migration{
			Version: v,
			Name:    name,
			SQL:     strings.TrimSpace(string(body)),
		})
	}
	sort.Slice(migs, func(i, j int) bool { return migs[i].Version < migs[j].Version })
	return migs, nil
}

const schemaMigrationsTableDDL = `
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);`

// Apply runs every migration whose version is strictly greater than the highest
// version recorded in schema_migrations. Each migration runs in its own
// transaction; if one fails the transaction rolls back and Apply returns the
// number of migrations that committed before the failure. The schema_migrations
// table itself is created here (CREATE TABLE IF NOT EXISTS), so individual
// migration files must NOT manage it.
func Apply(ctx context.Context, db *DB, fsys fs.FS, dir string) (int, error) {
	if _, err := db.Pool.Exec(ctx, schemaMigrationsTableDDL); err != nil {
		return 0, fmt.Errorf("ensure schema_migrations: %w", err)
	}
	var current int
	if err := db.Pool.QueryRow(ctx, `SELECT COALESCE(MAX(version), 0) FROM schema_migrations`).Scan(&current); err != nil {
		return 0, fmt.Errorf("read current version: %w", err)
	}
	migs, err := ReadMigrations(fsys, dir)
	if err != nil {
		return 0, err
	}
	applied := 0
	for _, m := range migs {
		if m.Version <= current {
			continue
		}
		if err := applyOne(ctx, db, m); err != nil {
			return applied, fmt.Errorf("apply %04d_%s: %w", m.Version, m.Name, err)
		}
		applied++
	}
	return applied, nil
}

func applyOne(ctx context.Context, db *DB, m Migration) error {
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, m.SQL); err != nil {
		return fmt.Errorf("exec sql: %w", err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO schema_migrations (version) VALUES ($1)`, m.Version); err != nil {
		return fmt.Errorf("insert version row: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit: %w", err)
	}
	return nil
}
