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

func stageOf(st State, id string) (StageRow, bool) {
	for _, s := range st.Stages {
		if s.StageID == id {
			return s, true
		}
	}
	return StageRow{}, false
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

// N5 通关发奖：首通/重复奖励、stars 取 max、highest 更新、进度连续防跳关、
// 0星/超上限/未知关拒绝（detail 说明原因）。
func TestRepo_StageClear(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg) // seed（gold=0）

	// 真实 config 奖励：stage_1_1 first{300g,5gem}/repeat{30g}；
	// stage_1_2 first{320g,0gem,skeletons:3}/repeat{32g}。两关 starCap=3（stars 配 3 条 goal）。

	// —— 首通 stage_1_1（2 星）：发首通奖励 +300g/+5gem + 记进度。
	st, err := repo.StageClear(ctx, acc, "stage_1_1", 2, cfg)
	if err != nil {
		t.Fatalf("first clear 1_1: %v", err)
	}
	if st.Gold != 300 || st.Gems != 5 {
		t.Fatalf("after first 1_1 gold=%d gems=%d (want 300/5)", st.Gold, st.Gems)
	}
	s, _ := stageOf(st, "stage_1_1")
	if !s.Cleared || s.Stars != 2 {
		t.Fatalf("stage_1_1 cleared=%v stars=%d", s.Cleared, s.Stars)
	}
	if st.HighestCleared != "stage_1_1" {
		t.Fatalf("highest=%q (want stage_1_1)", st.HighestCleared)
	}

	// —— 重复 stage_1_1（3 星）：发重复奖励 +30g；stars 取 max(2,3)=3；gold=300+30=330。
	st, err = repo.StageClear(ctx, acc, "stage_1_1", 3, cfg)
	if err != nil {
		t.Fatalf("repeat 1_1: %v", err)
	}
	if st.Gold != 330 {
		t.Fatalf("after repeat 1_1 gold=%d (want 330)", st.Gold)
	}
	s, _ = stageOf(st, "stage_1_1")
	if s.Stars != 3 {
		t.Fatalf("stage_1_1 stars should be max(2,3)=3, got %d", s.Stars)
	}

	// —— stars 不回退：再以 1 星重复 → stars 仍 3。
	st, _ = repo.StageClear(ctx, acc, "stage_1_1", 1, cfg)
	s, _ = stageOf(st, "stage_1_1")
	if s.Stars != 3 {
		t.Fatalf("stars regressed to %d (want 3)", s.Stars)
	}

	// —— 0 星 → 拒绝（ERR_INVALID_ARG / ErrInvalidStars）。
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 0, cfg); !errors.Is(err, ErrInvalidStars) {
		t.Fatalf("0 stars want ErrInvalidStars, got %v", err)
	}

	// —— 超上限（4 星 > starCap 3）→ 拒绝（ErrTooManyStars）。
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 4, cfg); !errors.Is(err, ErrTooManyStars) {
		t.Fatalf("4 stars want ErrTooManyStars, got %v", err)
	}

	// —— 未知关 → 拒绝（ErrUnknownStage）。
	if _, err := repo.StageClear(ctx, acc, "nope_stage", 1, cfg); !errors.Is(err, ErrUnknownStage) {
		t.Fatalf("unknown stage want ErrUnknownStage, got %v", err)
	}

	// —— 首通 stage_1_2（1_1 已通 → 解锁）：发首通 +320g + skeletons:3 碎片。
	goldBefore := st.Gold
	st, err = repo.StageClear(ctx, acc, "stage_1_2", 1, cfg)
	if err != nil {
		t.Fatalf("first clear 1_2: %v", err)
	}
	if st.Gold != goldBefore+320 {
		t.Fatalf("after first 1_2 gold=%d (want %d)", st.Gold, goldBefore+320)
	}
	if c, _ := cardOf(st, "skeletons"); c.Shards != 3 {
		t.Fatalf("skeletons shards=%d (want 3)", c.Shards)
	}
	if st.HighestCleared != "stage_1_2" {
		t.Fatalf("highest=%q (want stage_1_2)", st.HighestCleared)
	}
}

// 进度连续防跳关：1_1 未通就报 1_2 → 拒绝（ErrStageLocked）。新号独立验证。
func TestRepo_StageClear_RejectsSkip(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)

	// 直接报 1_2（1_1 没通）→ 拒。
	if _, err := repo.StageClear(ctx, acc, "stage_1_2", 1, cfg); !errors.Is(err, ErrStageLocked) {
		t.Fatalf("skip want ErrStageLocked, got %v", err)
	}
	// 状态未变：无 stage 记录、gold 仍 0。
	st, _ := repo.Get(ctx, acc, cfg)
	if st.Gold != 0 {
		t.Fatalf("rejected clear leaked gold=%d", st.Gold)
	}
	if _, ok := stageOf(st, "stage_1_2"); ok {
		t.Fatal("rejected clear should not create stage row")
	}

	// 通了 1_1 后再报 1_2 → 允许。
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 1, cfg); err != nil {
		t.Fatalf("clear 1_1: %v", err)
	}
	if _, err := repo.StageClear(ctx, acc, "stage_1_2", 1, cfg); err != nil {
		t.Fatalf("clear 1_2 after 1_1: %v", err)
	}
}

// shard_drop 概率掉落：stage_1_2 skeletons 30% 掉 1。重复刷很多次应至少掉过一次。
func TestRepo_StageClear_ShardDrop(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)

	// 先打通 1_1 + 1_2（首通已发 skeletons:3）。
	repo.StageClear(ctx, acc, "stage_1_1", 3, cfg)
	repo.StageClear(ctx, acc, "stage_1_2", 3, cfg)

	// 重复刷 1_2 共 200 次：30% 掉落 → 累计 shards 远超首通的 3。
	for i := 0; i < 200; i++ {
		repo.StageClear(ctx, acc, "stage_1_2", 1, cfg)
	}
	st, _ := repo.Get(ctx, acc, cfg)
	c, _ := cardOf(st, "skeletons")
	// 200 次 30% ≈ 期望 60，远 > 首通 3；放宽下界确保掉落确有发生。
	if c.Shards < 20 {
		t.Fatalf("skeletons shards after 200 repeats=%d (drop not firing?)", c.Shards)
	}
}
