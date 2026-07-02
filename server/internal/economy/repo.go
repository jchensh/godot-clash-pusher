package economy

import (
	"context"
	"errors"
	"math"
	"math/rand"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

// Settlement rejection reasons (mapped to error codes in the handler).
var (
	ErrInsufficient = errors.New("insufficient gold/shards")
	ErrAtCap        = errors.New("at level/rank cap")
	ErrLocked       = errors.New("card locked or not unlockable")
	ErrUnknownCard  = errors.New("unknown card")

	// N5 通关发奖拒绝原因（0星/超上限/未知关 → ERR_INVALID_ARG；跳关 → ERR_ECONOMY_STAGE_LOCKED）。
	ErrInvalidStars = errors.New("stars must be >= 1")
	ErrTooManyStars = errors.New("stars exceed stage star cap")
	ErrUnknownStage = errors.New("unknown stage")
	ErrStageLocked  = errors.New("stage not unlocked: previous stage not cleared")
)

type CardRow struct {
	CardID   string
	Level    int
	Rank     int
	Shards   int
	Unlocked bool
}

type StageRow struct {
	StageID string
	Stars   int
	Cleared bool
}

type State struct {
	Gold            int64
	Gems            int64
	IdleLastCollect int64
	HighestCleared  string
	Cards           []CardRow
	Stages          []StageRow
}

type Repo struct {
	db *store.DB
}

func NewRepo(db *store.DB) *Repo { return &Repo{db: db} }

// Get returns the account's economy state, lazily seeding a fresh account from cfg
// (all cards level1/rank1/shards0, starter cards unlocked — mirrors PlayerData.init_new).
func (r *Repo) Get(ctx context.Context, accountID int64, cfg *Config) (State, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return State{}, err
	}
	defer tx.Rollback(ctx)
	if err := ensureSeeded(ctx, tx, accountID, cfg); err != nil {
		return State{}, err
	}
	st, err := readState(ctx, tx, accountID)
	if err != nil {
		return State{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return State{}, err
	}
	return st, nil
}

// Upgrade spends gold to level a card up (capped by its rank's level cap).
func (r *Repo) Upgrade(ctx context.Context, accountID int64, cardID string, cfg *Config) (State, error) {
	return r.settle(ctx, accountID, cardID, cfg, func(card *cardLock, state *stateLock) error {
		rarity, ok := cfg.Rarity(cardID)
		if !ok {
			return ErrUnknownCard
		}
		if !card.unlocked {
			return ErrLocked
		}
		if card.level >= cfg.LevelCap(card.rank) {
			return ErrAtCap
		}
		cost, ok := cfg.UpgradeCost(rarity, card.level)
		if !ok {
			return ErrUnknownCard
		}
		if state.gold < int64(cost) {
			return ErrInsufficient
		}
		state.gold -= int64(cost)
		card.level++
		return nil
	})
}

// RankUp spends shards+gold to rank a card up (raises its level cap; skill unlocks are client-side).
func (r *Repo) RankUp(ctx context.Context, accountID int64, cardID string, cfg *Config) (State, error) {
	return r.settle(ctx, accountID, cardID, cfg, func(card *cardLock, state *stateLock) error {
		rarity, ok := cfg.Rarity(cardID)
		if !ok {
			return ErrUnknownCard
		}
		if !card.unlocked {
			return ErrLocked
		}
		if card.rank >= cfg.MaxRank() {
			return ErrAtCap
		}
		cost, ok := cfg.RankUpCost(rarity, card.rank)
		if !ok {
			return ErrUnknownCard
		}
		if card.shards < cost.Shards || state.gold < int64(cost.Gold) {
			return ErrInsufficient
		}
		card.shards -= cost.Shards
		state.gold -= int64(cost.Gold)
		card.rank++
		return nil
	})
}

// Unlock spends shards to unlock a locked card (collect N shards → playable).
func (r *Repo) Unlock(ctx context.Context, accountID int64, cardID string, cfg *Config) (State, error) {
	return r.settle(ctx, accountID, cardID, cfg, func(card *cardLock, state *stateLock) error {
		rarity, ok := cfg.Rarity(cardID)
		if !ok {
			return ErrUnknownCard
		}
		if card.unlocked {
			return ErrLocked
		}
		need, ok := cfg.UnlockCost(rarity)
		if !ok {
			return ErrLocked
		}
		if card.shards < need {
			return ErrInsufficient
		}
		card.shards -= need
		card.unlocked = true
		return nil
	})
}

// StageClear settles a stage-clear report (V5-N5)：客户端上报 (stageID, stars)，
// 服务器 sanity 校验（关存在 / stars≥1 / stars≤starCap / 线性解锁防跳关）+ 发首通/重复
// 奖励（含 shard_drop 概率掉落）+ 记进度（stars 取 max、cleared=true、刷 highest_cleared）。
// 返回新状态。校验/发奖全服务器权威（镜像 player_data.grant_stage_reward + stage_progress）。
// KAN-78 起必须带 battleID + summary（PveStart 发的会话）：同事务消费该会话
// （限速/时长一致/实收出兵/星数与摘要自洽，见 consumePveBattle），一局只能结算一次。
func (r *Repo) StageClear(ctx context.Context, accountID int64, stageID string, stars int, battleID int64, sum PveSummary, cfg *Config) (State, error) {
	stage, ok := cfg.Stage(stageID)
	if !ok {
		return State{}, ErrUnknownStage
	}
	if stars < 1 {
		return State{}, ErrInvalidStars
	}
	if stars > cfg.StarCap(stageID) {
		return State{}, ErrTooManyStars
	}
	// 线性解锁：第一关恒可；其余要求前一关已 cleared。
	if prev, hasPrev := cfg.PrevStage(stageID); hasPrev {
		cleared, err := r.isStageCleared(ctx, accountID, prev)
		if err != nil {
			return State{}, err
		}
		if !cleared {
			return State{}, ErrStageLocked
		}
	}

	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return State{}, err
	}
	defer tx.Rollback(ctx)
	if err := ensureSeeded(ctx, tx, accountID, cfg); err != nil {
		return State{}, err
	}

	// KAN-78 防作弊：校验并消费 PVE 战斗会话（同事务锁行 → 防并发双花/重放）。
	if err := consumePveBattle(ctx, tx, accountID, battleID, stageID, stars, sum, stage, cfg, time.Now()); err != nil {
		return State{}, err
	}

	// 锁住 stage 行 + state 行（FOR UPDATE）。
	var prevStars int
	var alreadyCleared bool
	err = tx.QueryRow(ctx,
		`SELECT stars, cleared FROM economy_stages WHERE account_id=$1 AND stage_id=$2 FOR UPDATE`,
		accountID, stageID).Scan(&prevStars, &alreadyCleared)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return State{}, err
	}
	if errors.Is(err, pgx.ErrNoRows) {
		prevStars, alreadyCleared = 0, false
	}

	var gold, gems int64
	if err := tx.QueryRow(ctx,
		`SELECT gold, gems FROM economy_state WHERE account_id=$1 FOR UPDATE`, accountID).
		Scan(&gold, &gems); err != nil {
		return State{}, err
	}

	// 发奖：首通(未通) = first_clear；重复(已通) = repeat。两者都叠加 shard_drop 概率掉落。
	reward := stage.Repeat
	if !alreadyCleared {
		reward = stage.FirstClear
	}
	gold += int64(reward.Gold)
	gems += int64(reward.Gems)
	// 固定碎片（first_clear/repeat 的 shards:{card:n}）——镜像 player_data.grant_reward._add_shards。
	for cid, n := range reward.Shards {
		if n <= 0 {
			continue
		}
		if _, err := tx.Exec(ctx,
			`UPDATE economy_cards SET shards=shards+$3 WHERE account_id=$1 AND card_id=$2`,
			accountID, cid, n); err != nil {
			return State{}, err
		}
	}

	// 写/更新 stage 进度（stars 取 max、cleared=true）。
	newStars := prevStars
	if stars > newStars {
		newStars = stars
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO economy_stages (account_id, stage_id, stars, cleared) VALUES ($1,$2,$3,TRUE)
		 ON CONFLICT (account_id, stage_id) DO UPDATE SET stars=EXCLUDED.stars, cleared=TRUE`,
		accountID, stageID, newStars); err != nil {
		return State{}, err
	}

	// 刷 highest_cleared：在新 cleared 集合里按有序序列取最后一个 cleared。
	highest, err := computeHighestCleared(ctx, tx, accountID, cfg)
	if err != nil {
		return State{}, err
	}

	// shard_drop 概率掉落 + 更新对应卡碎片（首通/重复都掉）。
	for cid, drop := range stage.ShardDrop {
		if drop.Amount <= 0 || rng().Float64() >= drop.Chance {
			continue
		}
		if _, err := tx.Exec(ctx,
			`UPDATE economy_cards SET shards=shards+$3 WHERE account_id=$1 AND card_id=$2`,
			accountID, cid, drop.Amount); err != nil {
			return State{}, err
		}
	}

	if _, err := tx.Exec(ctx,
		`UPDATE economy_state SET gold=$2, gems=$3, highest_cleared=$4, updated_at=NOW() WHERE account_id=$1`,
		accountID, gold, gems, highest); err != nil {
		return State{}, err
	}

	st, err := readState(ctx, tx, accountID)
	if err != nil {
		return State{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return State{}, err
	}
	return st, nil
}

// isStageCleared reads (without lock) whether a stage is already cleared.
func (r *Repo) isStageCleared(ctx context.Context, accountID int64, stageID string) (bool, error) {
	var cleared bool
	err := r.db.Pool.QueryRow(ctx,
		`SELECT cleared FROM economy_stages WHERE account_id=$1 AND stage_id=$2`,
		accountID, stageID).Scan(&cleared)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return cleared, err
}

// CollectIdle settles an offline-gold collection (V5-N6)：now 全用服务器时间
// （time.Now().Unix()，改本地时钟无效）。按 (now − last_collect) 算累计金币
// （rate=GoldPerHourPerChapter×highest_chapter，封顶 CapHours）→ 发到 gold + last_collect=now。
// 返回新状态（镜像 player_data.collect_idle；产率章节驱动、数值走 economy.json 配置）。
func (r *Repo) CollectIdle(ctx context.Context, accountID int64, cfg *Config) (State, error) {
	now := time.Now().Unix()
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return State{}, err
	}
	defer tx.Rollback(ctx)
	if err := ensureSeeded(ctx, tx, accountID, cfg); err != nil {
		return State{}, err
	}

	var gold, lastCollect int64
	var highest string
	if err := tx.QueryRow(ctx,
		`SELECT gold, idle_last_collect_ts, highest_cleared FROM economy_state WHERE account_id=$1 FOR UPDATE`,
		accountID).Scan(&gold, &lastCollect, &highest); err != nil {
		return State{}, err
	}

	pending := idlePending(now, lastCollect, highest, cfg)
	if pending > 0 {
		gold += int64(pending)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE economy_state SET gold=$2, idle_last_collect_ts=$3, updated_at=NOW() WHERE account_id=$1`,
		accountID, gold, now); err != nil {
		return State{}, err
	}

	st, err := readState(ctx, tx, accountID)
	if err != nil {
		return State{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return State{}, err
	}
	return st, nil
}

// idlePending computes offline gold since lastCollect (mirrors player_data.idle_pending).
// 章节驱动产率 + 封顶 CapHours；lastCollect<=0 → 0（防御，播种已设 now 故不应出现）。
func idlePending(now, lastCollect int64, highestCleared string, cfg *Config) int {
	if lastCollect <= 0 {
		return 0
	}
	chapter := cfg.HighestChapter(highestCleared)
	rate := cfg.IdleRatePerHour(chapter)
	if rate <= 0 {
		return 0
	}
	elapsed := now - lastCollect
	if elapsed < 0 {
		elapsed = 0
	}
	capH := cfg.IdleCapHours()
	hours := float64(elapsed) / 3600.0
	if capH > 0 && hours > float64(capH) {
		hours = float64(capH)
	}
	return int(math.Floor(float64(rate) * hours))
}

// computeHighestCleared returns the last cleared stage_id in the ordered sequence.
func computeHighestCleared(ctx context.Context, tx pgx.Tx, accountID int64, cfg *Config) (string, error) {
	ordered := cfg.OrderedStageIDs()
	if len(ordered) == 0 {
		return "", nil
	}
	rows, err := tx.Query(ctx,
		`SELECT stage_id FROM economy_stages WHERE account_id=$1 AND cleared=TRUE`, accountID)
	if err != nil {
		return "", err
	}
	cleared := map[string]bool{}
	for rows.Next() {
		var sid string
		if err := rows.Scan(&sid); err != nil {
			rows.Close()
			return "", err
		}
		cleared[sid] = true
	}
	rows.Close()
	highest := ""
	for _, sid := range ordered {
		if cleared[sid] {
			highest = sid
		}
	}
	return highest, nil
}

// rng returns a package-level random source (非 lockstep 路径，无需确定性——
// shard_drop 是服务端权威的产出概率，客户端只收结果)。
var globalRand = rand.New(rand.NewSource(time.Now().UnixNano()))

func rng() *rand.Rand { return globalRand }

type cardLock struct {
	level, rank, shards int
	unlocked            bool
}
type stateLock struct {
	gold, gems int64
}

// settle locks the card + state rows, runs the validation/mutation, writes back, returns new state.
func (r *Repo) settle(ctx context.Context, accountID int64, cardID string, cfg *Config, mutate func(*cardLock, *stateLock) error) (State, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return State{}, err
	}
	defer tx.Rollback(ctx)
	if err := ensureSeeded(ctx, tx, accountID, cfg); err != nil {
		return State{}, err
	}

	var card cardLock
	err = tx.QueryRow(ctx,
		`SELECT level, rank, shards, unlocked FROM economy_cards WHERE account_id=$1 AND card_id=$2 FOR UPDATE`,
		accountID, cardID).Scan(&card.level, &card.rank, &card.shards, &card.unlocked)
	if errors.Is(err, pgx.ErrNoRows) {
		return State{}, ErrUnknownCard
	}
	if err != nil {
		return State{}, err
	}

	var state stateLock
	if err := tx.QueryRow(ctx,
		`SELECT gold, gems FROM economy_state WHERE account_id=$1 FOR UPDATE`, accountID).
		Scan(&state.gold, &state.gems); err != nil {
		return State{}, err
	}

	if err := mutate(&card, &state); err != nil {
		return State{}, err
	}

	if _, err := tx.Exec(ctx,
		`UPDATE economy_cards SET level=$3, rank=$4, shards=$5, unlocked=$6 WHERE account_id=$1 AND card_id=$2`,
		accountID, cardID, card.level, card.rank, card.shards, card.unlocked); err != nil {
		return State{}, err
	}
	if _, err := tx.Exec(ctx,
		`UPDATE economy_state SET gold=$2, gems=$3, updated_at=NOW() WHERE account_id=$1`,
		accountID, state.gold, state.gems); err != nil {
		return State{}, err
	}

	st, err := readState(ctx, tx, accountID)
	if err != nil {
		return State{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return State{}, err
	}
	return st, nil
}

// ensureSeeded creates the economy_state row for a fresh account, and (idempotently)
// backfills per-card rows for ALL config cards. 新卡上线后，已有账号也会在此补进缺失卡
// （ON CONFLICT DO NOTHING：不动已有卡的 level/rank/shards/unlocked；新卡按 Starter 决定解锁）。
func ensureSeeded(ctx context.Context, tx pgx.Tx, accountID int64, cfg *Config) error {
	var exists bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM economy_state WHERE account_id=$1)`, accountID).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		if _, err := tx.Exec(ctx,
			`INSERT INTO economy_state (account_id, idle_last_collect_ts) VALUES ($1, $2)`,
			accountID, time.Now().Unix()); err != nil {
			return err
		}
	}
	ids := make([]string, 0, len(cfg.Cards))
	for id := range cfg.Cards {
		ids = append(ids, id)
	}
	sort.Strings(ids) // 确定性播种/补种顺序
	for _, id := range ids {
		if _, err := tx.Exec(ctx,
			`INSERT INTO economy_cards (account_id, card_id, unlocked) VALUES ($1, $2, $3)
			 ON CONFLICT (account_id, card_id) DO NOTHING`,
			accountID, id, cfg.Cards[id].Starter); err != nil {
			return err
		}
	}
	return nil
}

func readState(ctx context.Context, tx pgx.Tx, accountID int64) (State, error) {
	var st State
	if err := tx.QueryRow(ctx,
		`SELECT gold, gems, idle_last_collect_ts, highest_cleared FROM economy_state WHERE account_id=$1`, accountID).
		Scan(&st.Gold, &st.Gems, &st.IdleLastCollect, &st.HighestCleared); err != nil {
		return State{}, err
	}
	crows, err := tx.Query(ctx,
		`SELECT card_id, level, rank, shards, unlocked FROM economy_cards WHERE account_id=$1 ORDER BY card_id`, accountID)
	if err != nil {
		return State{}, err
	}
	for crows.Next() {
		var c CardRow
		if err := crows.Scan(&c.CardID, &c.Level, &c.Rank, &c.Shards, &c.Unlocked); err != nil {
			crows.Close()
			return State{}, err
		}
		st.Cards = append(st.Cards, c)
	}
	crows.Close()
	srows, err := tx.Query(ctx,
		`SELECT stage_id, stars, cleared FROM economy_stages WHERE account_id=$1 ORDER BY stage_id`, accountID)
	if err != nil {
		return State{}, err
	}
	defer srows.Close()
	for srows.Next() {
		var s StageRow
		if err := srows.Scan(&s.StageID, &s.Stars, &s.Cleared); err != nil {
			return State{}, err
		}
		st.Stages = append(st.Stages, s)
	}
	return st, nil
}
