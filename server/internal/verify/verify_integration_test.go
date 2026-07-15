package verify

// Integration（真 PG + fake runner）：VerifyOne 的取队/写回/shadow 标记全链。
// INTEGRATION_DB_URL=postgres://app:dev@localhost:5432/gcp?sslmode=disable go test -p 1 ./internal/verify/...

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

func setupVerifyDB(t *testing.T) (*store.DB, int64) {
	t.Helper()
	dsn := os.Getenv("INTEGRATION_DB_URL")
	if dsn == "" {
		t.Skip("set INTEGRATION_DB_URL to run verify integration tests")
	}
	ctx := context.Background()
	db, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Pool.Exec(ctx, `DELETE FROM pve_battles`); err != nil {
		t.Fatalf("clean pve_battles: %v", err)
	}
	var acc int64
	if err := db.Pool.QueryRow(ctx,
		`INSERT INTO accounts (provider, external_id) VALUES ('device', 'verify-test')
		 ON CONFLICT (provider, external_id) DO UPDATE SET last_login_at = NOW(), ban_status = 0 RETURNING id`).
		Scan(&acc); err != nil {
		t.Fatalf("seed account: %v", err)
	}
	return db, acc
}

// seedBattle 造一条已消费待验证的局。
func seedBattle(t *testing.T, db *store.DB, acc int64) int64 {
	t.Helper()
	sum, _ := json.Marshal(map[string]int{"duration_ticks": 978, "deploy_count": 45, "king_hp_permille": 154})
	var id int64
	if err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO pve_battles (account_id, stage_id, deck, progress, cmds, hashes, consumed_at, claimed_stars, claimed_summary)
		VALUES ($1, 'stage_1_1', '["knight"]', '{}', '[{"t":30,"ph":0,"s":1,"c":"knight","x":4500,"y":17000}]',
		        '[{"t":10,"h":"aa"}]', NOW(), 1, $2)
		RETURNING id`, acc, sum).Scan(&id); err != nil {
		t.Fatalf("seed battle: %v", err)
	}
	return id
}

func fakeRunner(v Verdict, err error) Runner {
	return func(_ context.Context, _ []byte) (Verdict, error) { return v, err }
}

func banStatus(t *testing.T, db *store.DB, acc int64) int {
	t.Helper()
	var b int
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT ban_status FROM accounts WHERE id=$1`, acc).Scan(&b); err != nil {
		t.Fatal(err)
	}
	return b
}

func battleStatus(t *testing.T, db *store.DB, id int64) (int16, string) {
	t.Helper()
	var s int16
	var note string
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT verify_status, verify_note FROM pve_battles WHERE id=$1`, id).Scan(&s, &note); err != nil {
		t.Fatal(err)
	}
	return s, note
}

func TestVerifyOne_PassMismatchSkipEmpty(t *testing.T) {
	db, acc := setupVerifyDB(t)
	ctx := context.Background()

	// —— PASS：重放全等 + 摘要复算一致 → status=1、不动 ban。
	id1 := seedBattle(t, db, acc)
	w := NewWorker(db, fakeRunner(Verdict{Status: "pass", Win: true, Ticks: 978, KingHpPermille: 154}, nil), 1.0, func() float64 { return 0 })
	did, err := w.VerifyOne(ctx)
	if err != nil || !did {
		t.Fatalf("verify pass: did=%v err=%v", did, err)
	}
	if s, note := battleStatus(t, db, id1); s != StatusPass {
		t.Fatalf("want PASS got %d (%s)", s, note)
	}
	if banStatus(t, db, acc) != 0 {
		t.Fatal("pass must not shadow-flag")
	}

	// —— MISMATCH：重放分叉 → status=2 + 账号 shadow 标记（ban_status=1）。
	id2 := seedBattle(t, db, acc)
	w = NewWorker(db, fakeRunner(Verdict{Status: "mismatch", Reason: "hash mismatch at tick 90"}, nil), 1.0, func() float64 { return 0 })
	if did, err = w.VerifyOne(ctx); err != nil || !did {
		t.Fatalf("verify mismatch: did=%v err=%v", did, err)
	}
	if s, _ := battleStatus(t, db, id2); s != StatusMismatch {
		t.Fatalf("want MISMATCH got %d", s)
	}
	if banStatus(t, db, acc) != 1 {
		t.Fatal("mismatch should shadow-flag the account")
	}

	// —— 抽样跳过：sampleRate=0.5、randf 恒 0.9 ≥ rate → status=4、runner 不该被调。
	id3 := seedBattle(t, db, acc)
	called := false
	w = NewWorker(db, func(_ context.Context, _ []byte) (Verdict, error) {
		called = true
		return Verdict{Status: "pass", Win: true}, nil
	}, 0.5, func() float64 { return 0.9 })
	if did, err = w.VerifyOne(ctx); err != nil || !did {
		t.Fatalf("verify skip: did=%v err=%v", did, err)
	}
	if called {
		t.Fatal("sampled-out battle must not run the replayer")
	}
	if s, _ := battleStatus(t, db, id3); s != StatusSkipped {
		t.Fatalf("want SKIPPED got %d", s)
	}

	// —— 队列空：did=false。
	if did, err = w.VerifyOne(ctx); err != nil || did {
		t.Fatalf("empty queue: did=%v err=%v", did, err)
	}
}
