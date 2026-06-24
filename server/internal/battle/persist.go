package battle

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

// MatchResult is the persisted outcome of one battle. WinnerAccount == 0 means a draw.
type MatchResult struct {
	P1Account     int64
	P2Account     int64
	WinnerAccount int64
	Reason        string
	StartedAt     time.Time
	EndedAt       time.Time
	P1Delta       int32
	P2Delta       int32
}

// Persister stores a finished match. Injected so the room core is testable
// without a database (tests use a fake; production uses PGPersister).
type Persister interface {
	SaveMatch(ctx context.Context, m MatchResult) error
}

// PGPersister writes the matches row and bumps both players' trophies in one tx.
type PGPersister struct {
	db *store.DB
}

func NewPGPersister(db *store.DB) *PGPersister {
	return &PGPersister{db: db}
}

func (p *PGPersister) SaveMatch(ctx context.Context, m MatchResult) error {
	tx, err := p.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var winner any
	if m.WinnerAccount != 0 {
		winner = m.WinnerAccount
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO matches (p1_account_id, p2_account_id, winner_account_id, reason,
		                     started_at, ended_at, p1_trophies_delta, p2_trophies_delta)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, m.P1Account, m.P2Account, winner, m.Reason, m.StartedAt, m.EndedAt, m.P1Delta, m.P2Delta); err != nil {
		return fmt.Errorf("insert match: %w", err)
	}

	// Trophies floored at 0 so a loss streak can't drive a profile negative.
	if err := bumpTrophies(ctx, tx, m.P1Account, m.P1Delta); err != nil {
		return err
	}
	if err := bumpTrophies(ctx, tx, m.P2Account, m.P2Delta); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func bumpTrophies(ctx context.Context, tx pgx.Tx, accountID int64, delta int32) error {
	if _, err := tx.Exec(ctx, `
		UPDATE profiles SET trophies = GREATEST(trophies + $2, 0), updated_at = NOW()
		WHERE account_id = $1
	`, accountID, delta); err != nil {
		return fmt.Errorf("bump trophies acc=%d: %w", accountID, err)
	}
	return nil
}
