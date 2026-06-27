package battle

// Integration test for the ELO + trophy persistence path. Requires a real
// Postgres via INTEGRATION_DB_URL (default `go test` skips it). Run with -p 1
// alongside other packages (shared DB):
//
//   INTEGRATION_DB_URL=postgres://app:dev@localhost:5432/gcp?sslmode=disable \
//       go test -p 1 ./internal/battle/...

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

func TestSaveMatch_AppliesEloAndTrophies(t *testing.T) {
	dsn := os.Getenv("INTEGRATION_DB_URL")
	if dsn == "" {
		t.Skip("INTEGRATION_DB_URL not set; skipping integration test")
	}
	ctx := context.Background()
	db, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	for _, tbl := range []string{"matches", "decks", "profiles", "accounts"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("cleanup %s: %v", tbl, err)
		}
	}
	a := seedAccount(t, db, ctx, "elo-a") // both start at rating 1200, trophies 0
	b := seedAccount(t, db, ctx, "elo-b")

	now := time.Now()
	if err := NewPGPersister(db).SaveMatch(ctx, MatchResult{
		P1Account: a, P2Account: b, WinnerAccount: a, Reason: "KING_DESTROYED",
		StartedAt: now, EndedAt: now, P1Delta: 30, P2Delta: -30,
	}); err != nil {
		t.Fatalf("SaveMatch: %v", err)
	}

	// Winner: rating 1216 (+16), trophies 30. Loser: rating 1184 (-16), trophies 0 (floored from -30).
	if r, tr := readProfile(t, db, ctx, a); r != 1216 || tr != 30 {
		t.Errorf("winner rating=%d trophies=%d, want 1216/30", r, tr)
	}
	if r, tr := readProfile(t, db, ctx, b); r != 1184 || tr != 0 {
		t.Errorf("loser rating=%d trophies=%d, want 1184/0", r, tr)
	}

	var rd1, rd2 int
	if err := db.Pool.QueryRow(ctx,
		`SELECT p1_rating_delta, p2_rating_delta FROM matches WHERE p1_account_id=$1`, a).Scan(&rd1, &rd2); err != nil {
		t.Fatalf("read match row: %v", err)
	}
	if rd1 != 16 || rd2 != -16 {
		t.Errorf("match rating deltas=%d/%d, want 16/-16", rd1, rd2)
	}
}

func seedAccount(t *testing.T, db *store.DB, ctx context.Context, ext string) int64 {
	t.Helper()
	var id int64
	if err := db.Pool.QueryRow(ctx,
		`INSERT INTO accounts (provider, external_id) VALUES ('device', $1) RETURNING id`, ext).Scan(&id); err != nil {
		t.Fatalf("seed account: %v", err)
	}
	if _, err := db.Pool.Exec(ctx,
		`INSERT INTO profiles (account_id, nickname) VALUES ($1, $2)`, id, "P-"+ext); err != nil {
		t.Fatalf("seed profile: %v", err)
	}
	return id
}

func readProfile(t *testing.T, db *store.DB, ctx context.Context, id int64) (int, int) {
	t.Helper()
	var r, trophies int
	if err := db.Pool.QueryRow(ctx,
		`SELECT rating, trophies FROM profiles WHERE account_id=$1`, id).Scan(&r, &trophies); err != nil {
		t.Fatalf("read profile: %v", err)
	}
	return r, trophies
}
