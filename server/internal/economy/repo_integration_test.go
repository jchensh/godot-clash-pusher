package economy

// 集成测试（需真 PG，跨包共享库时与 auth/profile 用 `-p 1` 串行）。
// 设 INTEGRATION_DB_URL 跑；缺则 skip。需先 migrate（0006 economy 表）。

import (
	"context"
	"errors"
	"os"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

func setupRepo(t *testing.T) (*Repo, *Config, int64) {
	t.Helper()
	dsn := os.Getenv("INTEGRATION_DB_URL")
	if dsn == "" {
		t.Skip("set INTEGRATION_DB_URL to run economy integration tests")
	}
	ctx := context.Background()
	db, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })

	for _, tbl := range []string{"economy_stages", "economy_cards", "economy_state"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("clean %s: %v", tbl, err)
		}
	}
	var accountID int64
	if err := db.Pool.QueryRow(ctx,
		`INSERT INTO accounts (provider, external_id) VALUES ('device', 'econ-test')
		 ON CONFLICT (provider, external_id) DO UPDATE SET last_login_at = NOW() RETURNING id`).
		Scan(&accountID); err != nil {
		t.Fatalf("create test account: %v", err)
	}
	b, err := gameconfig.Load("../../../config")
	if err != nil {
		t.Skipf("no real config: %v", err)
	}
	cfg, err := ParseConfig(b)
	if err != nil {
		t.Fatal(err)
	}
	return NewRepo(db), cfg, accountID
}

func cardOf(st State, id string) (CardRow, bool) {
	for _, c := range st.Cards {
		if c.CardID == id {
			return c, true
		}
	}
	return CardRow{}, false
}

func TestRepo_SeedAndUpgrade(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()

	st, err := repo.Get(ctx, acc, cfg) // lazy seed
	if err != nil {
		t.Fatal(err)
	}
	if len(st.Cards) != 16 {
		t.Fatalf("seeded cards=%d (want 16)", len(st.Cards))
	}
	if st.Gold != 0 {
		t.Fatalf("fresh gold=%d", st.Gold)
	}
	unlocked := 0
	for _, c := range st.Cards {
		if c.Unlocked {
			unlocked++
		}
	}
	if unlocked != 8 {
		t.Fatalf("starter unlocked=%d (want 8)", unlocked)
	}

	// no gold → insufficient
	if _, err := repo.Upgrade(ctx, acc, "knight", cfg); !errors.Is(err, ErrInsufficient) {
		t.Fatalf("want ErrInsufficient, got %v", err)
	}
	// give gold → upgrade knight (common L1 cost 80)
	repo.db.Pool.Exec(ctx, "UPDATE economy_state SET gold=10000 WHERE account_id=$1", acc)
	st, err = repo.Upgrade(ctx, acc, "knight", cfg)
	if err != nil {
		t.Fatal(err)
	}
	if st.Gold != 10000-80 {
		t.Fatalf("gold after upgrade=%d (want 9920)", st.Gold)
	}
	if c, _ := cardOf(st, "knight"); c.Level != 2 {
		t.Fatalf("knight level=%d (want 2)", c.Level)
	}
}

func TestRepo_RankUpUnlockCaps(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)
	repo.db.Pool.Exec(ctx, "UPDATE economy_state SET gold=1000000 WHERE account_id=$1", acc)

	// knight at rank1 level4 (cap) → upgrade rejected
	repo.db.Pool.Exec(ctx, "UPDATE economy_cards SET level=4 WHERE account_id=$1 AND card_id='knight'", acc)
	if _, err := repo.Upgrade(ctx, acc, "knight", cfg); !errors.Is(err, ErrAtCap) {
		t.Fatalf("want ErrAtCap, got %v", err)
	}
	// rank up without shards → insufficient
	if _, err := repo.RankUp(ctx, acc, "knight", cfg); !errors.Is(err, ErrInsufficient) {
		t.Fatalf("want ErrInsufficient, got %v", err)
	}
	// give shards → rank up (common r1→2 = {20, 2000})
	repo.db.Pool.Exec(ctx, "UPDATE economy_cards SET shards=100 WHERE account_id=$1 AND card_id='knight'", acc)
	st, err := repo.RankUp(ctx, acc, "knight", cfg)
	if err != nil {
		t.Fatal(err)
	}
	if c, _ := cardOf(st, "knight"); c.Rank != 2 || c.Shards != 80 {
		t.Fatalf("knight after rankup rank=%d shards=%d", c.Rank, c.Shards)
	}
	// now upgrade allowed (rank2 cap 7)
	if _, err := repo.Upgrade(ctx, acc, "knight", cfg); err != nil {
		t.Fatalf("upgrade after rankup: %v", err)
	}

	// unlock golem (legendary, 120 shards): insufficient then ok
	if _, err := repo.Unlock(ctx, acc, "golem", cfg); !errors.Is(err, ErrInsufficient) {
		t.Fatalf("want ErrInsufficient, got %v", err)
	}
	repo.db.Pool.Exec(ctx, "UPDATE economy_cards SET shards=120 WHERE account_id=$1 AND card_id='golem'", acc)
	st, err = repo.Unlock(ctx, acc, "golem", cfg)
	if err != nil {
		t.Fatal(err)
	}
	if c, _ := cardOf(st, "golem"); !c.Unlocked || c.Shards != 0 {
		t.Fatalf("golem after unlock unlocked=%v shards=%d", c.Unlocked, c.Shards)
	}

	// unknown card → ErrUnknownCard
	if _, err := repo.Upgrade(ctx, acc, "nonexistent", cfg); !errors.Is(err, ErrUnknownCard) {
		t.Fatalf("want ErrUnknownCard, got %v", err)
	}
}
