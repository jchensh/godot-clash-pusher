package kingdom

// 集成测试（需真 PG；镜像 economy 的做法：设 INTEGRATION_DB_URL 跑、缺则 skip）。
// 需先 migrate 到 0009（kingdom_state / kingdom_buildings）。

import (
	"context"
	"errors"
	"os"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

func setupKingdomRepo(t *testing.T) (*Repo, *Config, *economy.Config, int64, *store.DB) {
	t.Helper()
	dsn := os.Getenv("INTEGRATION_DB_URL")
	if dsn == "" {
		t.Skip("set INTEGRATION_DB_URL to run kingdom integration tests")
	}
	ctx := context.Background()
	db, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })

	for _, tbl := range []string{"kingdom_buildings", "kingdom_state", "economy_state"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("clean %s: %v", tbl, err)
		}
	}
	var accountID int64
	if err := db.Pool.QueryRow(ctx,
		`INSERT INTO accounts (provider, external_id) VALUES ('device', 'kingdom-test')
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
		t.Fatalf("parse kingdom config: %v", err)
	}
	econCfg, err := economy.ParseConfig(b)
	if err != nil {
		t.Fatalf("parse economy config: %v", err)
	}
	return NewRepo(db), cfg, econCfg, accountID, db
}

// 端到端：播种（初始建筑/资源）→ 升级农田（扣资源+计时）→ 加速（扣宝石完级）→ Get 状态一致。
func TestRepo_SeedUpgradeSpeedup(t *testing.T) {
	repo, cfg, econCfg, accountID, db := setupKingdomRepo(t)
	ctx := context.Background()

	st, err := repo.Get(ctx, accountID, cfg, econCfg)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if st.Resources["food"] != cfg.Rules.Initial.Resources["food"] {
		t.Fatalf("seed food want %d, got %d", cfg.Rules.Initial.Resources["food"], st.Resources["food"])
	}
	lvl := map[string]int{}
	for _, b := range st.Buildings {
		lvl[b.Building] = b.Level
	}
	if lvl["keep"] != 1 || lvl["farm"] != 1 || lvl["wall"] != 0 {
		t.Fatalf("seed levels wrong: %v", lvl)
	}

	// 升级农田 Lv1→2：farm lv2 成本按真实配置扣。
	row, _ := cfg.LevelRow("farm", 2)
	if _, err := db.Pool.Exec(ctx,
		`UPDATE kingdom_state SET resources = $2 WHERE account_id=$1`,
		accountID, []byte(`{"food": 999999, "wood": 999999}`)); err != nil {
		t.Fatal(err)
	}
	st, err = repo.Upgrade(ctx, accountID, "farm", cfg, econCfg)
	if err != nil {
		t.Fatalf("upgrade farm: %v", err)
	}
	if st.Resources["wood"] != 999999-row.Cost["wood"] {
		t.Fatalf("wood not deducted: %d", st.Resources["wood"])
	}
	var endTs int64
	for _, b := range st.Buildings {
		if b.Building == "farm" {
			endTs = b.UpgradeEndTs
		}
	}
	if endTs <= st.Now {
		t.Fatalf("farm must be under construction, end=%d now=%d", endTs, st.Now)
	}

	// 加速：无宝石先拒；发宝石后完级。
	if _, err := repo.Speedup(ctx, accountID, "farm", cfg, econCfg); !errors.Is(err, ErrInsufficient) {
		t.Fatalf("speedup without gems want ErrInsufficient, got %v", err)
	}
	// 被拒的 Speedup 整事务回滚（economy_state 种子行也没落）→ 必须 upsert 不能裸 UPDATE。
	if _, err := db.Pool.Exec(ctx,
		`INSERT INTO economy_state (account_id, gems, idle_last_collect_ts) VALUES ($1, 100000, 0)
		 ON CONFLICT (account_id) DO UPDATE SET gems = 100000`, accountID); err != nil {
		t.Fatal(err)
	}
	st, err = repo.Speedup(ctx, accountID, "farm", cfg, econCfg)
	if err != nil {
		t.Fatalf("speedup: %v", err)
	}
	for _, b := range st.Buildings {
		if b.Building == "farm" && (b.Level != 2 || b.UpgradeEndTs != 0) {
			t.Fatalf("farm after speedup want lv2 idle, got lv%d end=%d", b.Level, b.UpgradeEndTs)
		}
	}
}

// 王城门禁：非王城建筑等级 ≤ 王城等级×cap_mult；王城升级需章节进度。
func TestRepo_Gates(t *testing.T) {
	repo, cfg, econCfg, accountID, db := setupKingdomRepo(t)
	ctx := context.Background()
	if _, err := repo.Get(ctx, accountID, cfg, econCfg); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Pool.Exec(ctx,
		`UPDATE kingdom_state SET resources = $2 WHERE account_id=$1`,
		accountID, []byte(`{"food": 99999999, "wood": 99999999}`)); err != nil {
		t.Fatal(err)
	}
	// keep=1, cap_mult=2 → farm 最高 2：升到 2（计时→加速完级）后第三次升必被王城门拦。
	if _, err := repo.Upgrade(ctx, accountID, "farm", cfg, econCfg); err != nil {
		t.Fatalf("farm →2 start: %v", err)
	}
	if _, err := db.Pool.Exec(ctx,
		`INSERT INTO economy_state (account_id, gems, idle_last_collect_ts) VALUES ($1, 1000000, 0)
		 ON CONFLICT (account_id) DO UPDATE SET gems = 1000000`, accountID); err != nil {
		t.Fatal(err)
	}
	if _, err := repo.Speedup(ctx, accountID, "farm", cfg, econCfg); err != nil {
		t.Fatalf("farm →2 speedup: %v", err)
	}
	if _, err := repo.Upgrade(ctx, accountID, "farm", cfg, econCfg); !errors.Is(err, ErrKeepGate) {
		t.Fatalf("farm →3 want ErrKeepGate, got %v", err)
	}
	// 王城 Lv1→2 需通关第 1 章（真实配置 chapter_req=1）：无进度必拒。
	if _, err := repo.Upgrade(ctx, accountID, "keep", cfg, econCfg); !errors.Is(err, ErrChapterLocked) {
		t.Fatalf("keep →2 without chapter want ErrChapterLocked, got %v", err)
	}
}

// 收取：产出入仓（仓库封顶）+ 铸币坊金币进主钱包 + last_collect 重置。
func TestRepo_Collect(t *testing.T) {
	repo, cfg, econCfg, accountID, db := setupKingdomRepo(t)
	ctx := context.Background()
	if _, err := repo.Get(ctx, accountID, cfg, econCfg); err != nil {
		t.Fatal(err)
	}
	// 把 last_collect 拨回 2 小时前（改 DB = 模拟时间流逝；服务器时钟本身不可伪造）。
	if _, err := db.Pool.Exec(ctx,
		`UPDATE kingdom_state SET last_collect_ts = last_collect_ts - 7200 WHERE account_id=$1`,
		accountID); err != nil {
		t.Fatal(err)
	}
	st, err := repo.Get(ctx, accountID, cfg, econCfg)
	if err != nil {
		t.Fatal(err)
	}
	if st.Pending["food"] <= 0 {
		t.Fatalf("2h farm pending must be >0, got %v", st.Pending)
	}
	before := st.Resources["food"]
	pending := st.Pending["food"]
	st, err = repo.Collect(ctx, accountID, cfg, econCfg)
	if err != nil {
		t.Fatalf("collect: %v", err)
	}
	if st.Resources["food"] != before+pending {
		t.Fatalf("collect food want %d, got %d", before+pending, st.Resources["food"])
	}
	if len(st.Pending) != 0 || st.PendingGold != 0 {
		t.Fatalf("pending must reset after collect, got %v gold=%d", st.Pending, st.PendingGold)
	}
}
