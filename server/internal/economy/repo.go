package economy

import (
	"context"
	"errors"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

// Settlement rejection reasons (mapped to error codes in the handler).
var (
	ErrInsufficient = errors.New("insufficient gold/shards")
	ErrAtCap        = errors.New("at level/rank cap")
	ErrLocked       = errors.New("card locked or not unlockable")
	ErrUnknownCard  = errors.New("unknown card")
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

// ensureSeeded creates the economy_state row + per-card rows for a fresh account.
func ensureSeeded(ctx context.Context, tx pgx.Tx, accountID int64, cfg *Config) error {
	var exists bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM economy_state WHERE account_id=$1)`, accountID).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return nil
	}
	if _, err := tx.Exec(ctx, `INSERT INTO economy_state (account_id) VALUES ($1)`, accountID); err != nil {
		return err
	}
	ids := make([]string, 0, len(cfg.Cards))
	for id := range cfg.Cards {
		ids = append(ids, id)
	}
	sort.Strings(ids) // 确定性播种顺序
	for _, id := range ids {
		if _, err := tx.Exec(ctx,
			`INSERT INTO economy_cards (account_id, card_id, unlocked) VALUES ($1, $2, $3)`,
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
