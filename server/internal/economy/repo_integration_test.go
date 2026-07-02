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

	for _, tbl := range []string{"pve_battles", "economy_stages", "economy_cards", "economy_state"} {
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

var starterDeck = []string{"knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"}

// pveBattleFor 建一个能过层1校验的 PVE 会话（KAN-78）：PveStart → 倒拨 started_at 绕过
// 限速（测试不真等墙钟）→ 喂一条玩家出兵。返回 (battle_id, 满足任意星目标的摘要)。
func pveBattleFor(t *testing.T, repo *Repo, ctx context.Context, acc int64, stageID string, cfg *Config) (int64, PveSummary) {
	t.Helper()
	bid, err := repo.PveStart(ctx, acc, stageID, starterDeck, cfg)
	if err != nil {
		t.Fatalf("pve start %s: %v", stageID, err)
	}
	if _, err := repo.db.Pool.Exec(ctx,
		`UPDATE pve_battles SET started_at = NOW() - INTERVAL '5 minutes' WHERE id=$1`, bid); err != nil {
		t.Fatalf("backdate battle: %v", err)
	}
	if err := repo.PveReport(ctx, acc, bid,
		[]PveCmd{{Tick: 30, Phase: 0, Side: 1, Card: "knight", X: 4500, Y: 17000}}, nil, cfg); err != nil {
		t.Fatalf("pve report: %v", err)
	}
	// 60s 战斗 + 王塔满血：满足任何 king_hp_pct / time_under 星目标。
	return bid, PveSummary{DurationTicks: 600, DeployCount: 1, KingHpPermille: 1000}
}

// mustClear = pveBattleFor + StageClear（老测试的"直接报通关"语义，加上合法会话）。
func mustClear(t *testing.T, repo *Repo, ctx context.Context, acc int64, stageID string, stars int, cfg *Config) (State, error) {
	t.Helper()
	bid, sum := pveBattleFor(t, repo, ctx, acc, stageID, cfg)
	return repo.StageClear(ctx, acc, stageID, stars, bid, sum, cfg)
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

	// 配置驱动（S8c 后 stages.json 由 build_stages.py 生成 100 关，勿钉魔数）：从 cfg 读 1_1/1_2 奖励。
	// 金币/宝石/星级确定可断；碎片受 shard_drop 概率掉落（StageClear 首通/重复都 roll）→ 用 >= 容差。
	s11, _ := cfg.Stage("stage_1_1")
	s12, _ := cfg.Stage("stage_1_2")
	fc1Gold, fc1Gems := int64(s11.FirstClear.Gold), int64(s11.FirstClear.Gems)
	rep1Gold := int64(s11.Repeat.Gold)
	fc2Gold := int64(s12.FirstClear.Gold)

	// —— 首通 stage_1_1（2 星）：发首通奖励 + 记进度。
	st, err := mustClear(t, repo, ctx, acc, "stage_1_1", 2, cfg)
	if err != nil {
		t.Fatalf("first clear 1_1: %v", err)
	}
	if st.Gold != fc1Gold || st.Gems != fc1Gems {
		t.Fatalf("after first 1_1 gold=%d gems=%d (want %d/%d)", st.Gold, st.Gems, fc1Gold, fc1Gems)
	}
	s, _ := stageOf(st, "stage_1_1")
	if !s.Cleared || s.Stars != 2 {
		t.Fatalf("stage_1_1 cleared=%v stars=%d", s.Cleared, s.Stars)
	}
	if st.HighestCleared != "stage_1_1" {
		t.Fatalf("highest=%q (want stage_1_1)", st.HighestCleared)
	}

	// —— 重复 stage_1_1（3 星）：发重复奖励；stars 取 max(2,3)=3；金币 = 首通 + 重复。
	st, err = mustClear(t, repo, ctx, acc, "stage_1_1", 3, cfg)
	if err != nil {
		t.Fatalf("repeat 1_1: %v", err)
	}
	if st.Gold != fc1Gold+rep1Gold {
		t.Fatalf("after repeat 1_1 gold=%d (want %d)", st.Gold, fc1Gold+rep1Gold)
	}
	s, _ = stageOf(st, "stage_1_1")
	if s.Stars != 3 {
		t.Fatalf("stage_1_1 stars should be max(2,3)=3, got %d", s.Stars)
	}

	// —— stars 不回退：再以 1 星重复 → stars 仍 3。
	st, _ = mustClear(t, repo, ctx, acc, "stage_1_1", 1, cfg)
	s, _ = stageOf(st, "stage_1_1")
	if s.Stars != 3 {
		t.Fatalf("stars regressed to %d (want 3)", s.Stars)
	}

	// —— 0/超上限/未知关：在 battle 会话校验之前就拒 → 传 0 会话即可测。
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 0, 0, PveSummary{}, cfg); !errors.Is(err, ErrInvalidStars) {
		t.Fatalf("0 stars want ErrInvalidStars, got %v", err)
	}
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 4, 0, PveSummary{}, cfg); !errors.Is(err, ErrTooManyStars) {
		t.Fatalf("4 stars want ErrTooManyStars, got %v", err)
	}
	if _, err := repo.StageClear(ctx, acc, "nope_stage", 1, 0, PveSummary{}, cfg); !errors.Is(err, ErrUnknownStage) {
		t.Fatalf("unknown stage want ErrUnknownStage, got %v", err)
	}

	// —— 首通 stage_1_2（1_1 已通 → 解锁）：金币 += first_clear.gold；碎片 ≥ before + 首通固定发放量。
	goldBefore := st.Gold
	var skelBefore int64
	if c, ok := cardOf(st, "skeletons"); ok {
		skelBefore = int64(c.Shards)
	}
	st, err = mustClear(t, repo, ctx, acc, "stage_1_2", 1, cfg)
	if err != nil {
		t.Fatalf("first clear 1_2: %v", err)
	}
	if st.Gold != goldBefore+fc2Gold {
		t.Fatalf("after first 1_2 gold=%d (want %d)", st.Gold, goldBefore+fc2Gold)
	}
	wantMinSkel := skelBefore + int64(s12.FirstClear.Shards["skeletons"])
	if c, _ := cardOf(st, "skeletons"); int64(c.Shards) < wantMinSkel {
		t.Fatalf("skeletons shards=%d (want >= %d, 首通固定 + 可能掉落)", c.Shards, wantMinSkel)
	}
	if st.HighestCleared != "stage_1_2" {
		t.Fatalf("highest=%q (want stage_1_2)", st.HighestCleared)
	}
}

// 进度连续防跳关：1_1 未通就打 1_2 → 拒绝（ErrStageLocked）。KAN-78 起开战报到
// （PveStart）与结算（StageClear）双闸口同口径。新号独立验证。
func TestRepo_StageClear_RejectsSkip(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)

	// 跳关在开战报到就被拒 → 拿不到 battle_id。
	if _, err := repo.PveStart(ctx, acc, "stage_1_2", starterDeck, cfg); !errors.Is(err, ErrStageLocked) {
		t.Fatalf("pve_start skip want ErrStageLocked, got %v", err)
	}
	// 就算伪造 battle_id 直接报 StageClear 也过不了（先撞线性解锁）。
	if _, err := repo.StageClear(ctx, acc, "stage_1_2", 1, 999999, PveSummary{}, cfg); !errors.Is(err, ErrStageLocked) {
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

	// 通了 1_1 后再打 1_2 → 允许。
	if _, err := mustClear(t, repo, ctx, acc, "stage_1_1", 1, cfg); err != nil {
		t.Fatalf("clear 1_1: %v", err)
	}
	if _, err := mustClear(t, repo, ctx, acc, "stage_1_2", 1, cfg); err != nil {
		t.Fatalf("clear 1_2 after 1_1: %v", err)
	}
}

// KAN-78 层1 DB 侧拒绝矩阵：秒推 / battle 重复消费（防重放）/ 无出兵 / 未解锁卡 /
// 已消费局继续 report / 错关结算。
func TestRepo_PveGuards(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)

	okSum := PveSummary{DurationTicks: 600, DeployCount: 1, KingHpPermille: 1000}

	// —— 秒推：刚 PveStart（不倒拨）就报通关 → 墙钟 < 15s 拒。
	bid, err := repo.PveStart(ctx, acc, "stage_1_1", starterDeck, cfg)
	if err != nil {
		t.Fatalf("pve start: %v", err)
	}
	if err := repo.PveReport(ctx, acc, bid,
		[]PveCmd{{Tick: 30, Phase: 0, Side: 1, Card: "knight", X: 4500, Y: 17000}}, nil, cfg); err != nil {
		t.Fatalf("report: %v", err)
	}
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 1, bid, okSum, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("instant clear want ErrPveBattleInvalid, got %v", err)
	}

	// —— 无出兵：倒拨后但服务器没收到任何玩家指令的另一局 → 拒。
	bid2, _ := repo.PveStart(ctx, acc, "stage_1_1", starterDeck, cfg)
	repo.db.Pool.Exec(ctx, `UPDATE pve_battles SET started_at = NOW() - INTERVAL '5 minutes' WHERE id=$1`, bid2)
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 1, bid2, okSum, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("no-deploy clear want ErrPveBattleInvalid, got %v", err)
	}

	// —— 合法通关（复用秒推那局：把它倒拨）→ 过；同一 battle_id 再报 → 已消费拒（防重放）。
	repo.db.Pool.Exec(ctx, `UPDATE pve_battles SET started_at = NOW() - INTERVAL '5 minutes' WHERE id=$1`, bid)
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 1, bid, okSum, cfg); err != nil {
		t.Fatalf("legit clear: %v", err)
	}
	if _, err := repo.StageClear(ctx, acc, "stage_1_1", 1, bid, okSum, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("replayed battle_id want ErrPveBattleInvalid, got %v", err)
	}
	// 已消费局继续 report → 拒。
	if err := repo.PveReport(ctx, acc, bid,
		[]PveCmd{{Tick: 99, Phase: 0, Side: 1, Card: "zap", X: 1000, Y: 1000}}, nil, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("report after consume want ErrPveBattleInvalid, got %v", err)
	}

	// —— 错关结算：battle 是 1_1 的、拿去报 1_2（1_1 已通 → 线性解锁过，但关不匹配）→ 拒。
	bid3, sum3 := pveBattleFor(t, repo, ctx, acc, "stage_1_1", cfg)
	if _, err := repo.StageClear(ctx, acc, "stage_1_2", 1, bid3, sum3, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("wrong-stage battle want ErrPveBattleInvalid, got %v", err)
	}

	// —— 未解锁卡进卡组：golem（legendary 锁定）→ PveStart 拒。
	badDeck := []string{"golem", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"}
	if _, err := repo.PveStart(ctx, acc, "stage_1_1", badDeck, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("locked-card deck want ErrPveBattleInvalid, got %v", err)
	}

	// —— 别人的 battle：新账号拿 acc 的 battle_id 报 → 拒。
	var acc2 int64
	repo.db.Pool.QueryRow(ctx,
		`INSERT INTO accounts (provider, external_id) VALUES ('device', 'econ-test-2')
		 ON CONFLICT (provider, external_id) DO UPDATE SET last_login_at = NOW() RETURNING id`).Scan(&acc2)
	repo.Get(ctx, acc2, cfg)
	bid4, sum4 := pveBattleFor(t, repo, ctx, acc, "stage_1_1", cfg)
	if _, err := repo.StageClear(ctx, acc2, "stage_1_1", 1, bid4, sum4, cfg); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("foreign battle want ErrPveBattleInvalid, got %v", err)
	}
}

// N6 挂机领取：服务器时钟结算。新号播种 last_collect=now（注册即计时）；
// 把 last_collect 倒拨模拟过去时间 → CollectIdle 按服务器时间累计/封顶/发金币/刷新基准。
func TestRepo_CollectIdle(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()

	// ① 新号 Get → 播种。idle_last_collect_ts 应≈now（注册即计时，非 0）。
	st, err := repo.Get(ctx, acc, cfg)
	if err != nil {
		t.Fatal(err)
	}
	if st.IdleLastCollect <= 0 {
		t.Fatalf("seeded idle_last_collect=%d (want >0, 注册即计时)", st.IdleLastCollect)
	}

	// ② 新号未通关（highest 空）→ chapter 0 → rate 0。倒拨 10h 后领取仍是 0。
	repo.db.Pool.Exec(ctx,
		`UPDATE economy_state SET idle_last_collect_ts = $2 WHERE account_id=$1`,
		acc, st.IdleLastCollect-36000) // -10h
	st, err = repo.CollectIdle(ctx, acc, cfg)
	if err != nil {
		t.Fatalf("collect (no progress): %v", err)
	}
	if st.Gold != 0 {
		t.Fatalf("no-progress collect gold=%d (want 0)", st.Gold)
	}

	// ③ 通关到 chapter 1（stage_1_2）→ rate 50/h。倒拨 2h → +100。
	mustClear(t, repo, ctx, acc, "stage_1_1", 1, cfg)
	mustClear(t, repo, ctx, acc, "stage_1_2", 1, cfg) // highest=stage_1_2 (chapter 1)
	repo.db.Pool.Exec(ctx,
		`UPDATE economy_state SET idle_last_collect_ts = $2 WHERE account_id=$1`,
		acc, st.IdleLastCollect-7200) // -2h
	st, _ = repo.Get(ctx, acc, cfg)
	prevGold := st.Gold
	lastBefore := st.IdleLastCollect
	st, err = repo.CollectIdle(ctx, acc, cfg)
	if err != nil {
		t.Fatalf("collect chapter1 2h: %v", err)
	}
	if st.Gold != prevGold+100 {
		t.Fatalf("chapter1 2h gold=%d (want %d)", st.Gold, prevGold+100)
	}
	if st.IdleLastCollect <= lastBefore {
		t.Fatalf("last_collect not advanced: %d <= %d", st.IdleLastCollect, lastBefore)
	}

	// ④ 封顶：倒拨 100h（cap 8h）→ chapter1 rate 50 × 8 = 400。
	repo.db.Pool.Exec(ctx,
		`UPDATE economy_state SET idle_last_collect_ts = $2 WHERE account_id=$1`,
		acc, st.IdleLastCollect-3600*100) // -100h
	prevGold = st.Gold
	st, _ = repo.CollectIdle(ctx, acc, cfg)
	if st.Gold != prevGold+400 {
		t.Fatalf("100h capped gold=%d (want %d)", st.Gold, prevGold+400)
	}

	// ⑤ 连续领取：刚领完立即再领 → elapsed≈0 → +0（无重复领）。
	prevGold = st.Gold
	st, _ = repo.CollectIdle(ctx, acc, cfg)
	if st.Gold != prevGold {
		t.Fatalf("immediate re-collect gold=%d (want %d, no double collect)", st.Gold, prevGold)
	}
}

// 改本地时钟无效验证：CollectIdle 用 time.Now()，客户端改 last_collect 入参无影响
// （CollectIdle 无入参）；服务器只信自己存的 last_collect + 自己的 now。
func TestRepo_CollectIdle_ServerAuthoritative(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)
	mustClear(t, repo, ctx, acc, "stage_1_1", 1, cfg)
	mustClear(t, repo, ctx, acc, "stage_1_2", 1, cfg)

	// 倒拨 3h，领取应 +150（chapter1 50/h × 3）。
	repo.db.Pool.Exec(ctx, `UPDATE economy_state SET idle_last_collect_ts = (SELECT EXTRACT(EPOCH FROM NOW())::bigint - 10800) WHERE account_id=$1`, acc)
	st, _ := repo.Get(ctx, acc, cfg)
	prevGold := st.Gold
	st, _ = repo.CollectIdle(ctx, acc, cfg)
	if st.Gold <= prevGold {
		t.Fatalf("server-authoritative collect should add gold: %d -> %d", prevGold, st.Gold)
	}
}

// shard_drop 概率掉落：stage_1_2 skeletons 30% 掉 1。重复刷很多次应至少掉过一次。
func TestRepo_StageClear_ShardDrop(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg)

	// 先打通 1_1 + 1_2（首通已发 skeletons:3）。
	mustClear(t, repo, ctx, acc, "stage_1_1", 3, cfg)
	mustClear(t, repo, ctx, acc, "stage_1_2", 3, cfg)

	// 重复刷 1_2 共 200 次：30% 掉落 → 累计 shards 远超首通的 3。
	// （每次都要新会话——battle 一次性消费本身就是防重放；顺带覆盖高频建会话路径。）
	for i := 0; i < 200; i++ {
		mustClear(t, repo, ctx, acc, "stage_1_2", 1, cfg)
	}
	st, _ := repo.Get(ctx, acc, cfg)
	c, _ := cardOf(st, "skeletons")
	// 200 次 30% ≈ 期望 60，远 > 首通 3；放宽下界确保掉落确有发生。
	if c.Shards < 20 {
		t.Fatalf("skeletons shards after 200 repeats=%d (drop not firing?)", c.Shards)
	}
}
