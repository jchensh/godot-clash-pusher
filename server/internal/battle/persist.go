package battle

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/rating"
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

	// Read + lock both ratings, then apply ELO (hidden matchmaking rating).
	// Trophies (visible) move by the flat delta the room already computed.
	r1, err := lockRating(ctx, tx, m.P1Account)
	if err != nil {
		return err
	}
	r2, err := lockRating(ctx, tx, m.P2Account)
	if err != nil {
		return err
	}
	scoreP1 := 0.5
	switch m.WinnerAccount {
	case m.P1Account:
		scoreP1 = 1
	case m.P2Account:
		scoreP1 = 0
	}
	nr1, nr2 := rating.Update(r1, r2, scoreP1)
	rd1, rd2 := int32(nr1-r1), int32(nr2-r2)
	log.Printf("persist: acc=%d mmr %d->%d trophy%+d | acc=%d mmr %d->%d trophy%+d", m.P1Account, r1, nr1, m.P1Delta, m.P2Account, r2, nr2, m.P2Delta)

	var winner any
	if m.WinnerAccount != 0 {
		winner = m.WinnerAccount
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO matches (p1_account_id, p2_account_id, winner_account_id, reason,
		                     started_at, ended_at, p1_trophies_delta, p2_trophies_delta,
		                     p1_rating_delta, p2_rating_delta)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, m.P1Account, m.P2Account, winner, m.Reason, m.StartedAt, m.EndedAt,
		m.P1Delta, m.P2Delta, rd1, rd2); err != nil {
		return fmt.Errorf("insert match: %w", err)
	}

	if err := bumpProfile(ctx, tx, m.P1Account, m.P1Delta, nr1); err != nil {
		return err
	}
	if err := bumpProfile(ctx, tx, m.P2Account, m.P2Delta, nr2); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// lockRating reads a profile's current matchmaking rating, locking the row so a
// concurrent match for the same account can't clobber the ELO update.
func lockRating(ctx context.Context, tx pgx.Tx, accountID int64) (int, error) {
	var r int
	if err := tx.QueryRow(ctx,
		`SELECT rating FROM profiles WHERE account_id = $1 FOR UPDATE`, accountID).Scan(&r); err != nil {
		return 0, fmt.Errorf("read rating acc=%d: %w", accountID, err)
	}
	return r, nil
}

// bumpProfile applies the trophy delta (visible, floored at 0) and sets the new
// ELO rating (hidden) in one update.
func bumpProfile(ctx context.Context, tx pgx.Tx, accountID int64, trophyDelta int32, newRating int) error {
	if _, err := tx.Exec(ctx, `
		UPDATE profiles SET trophies = GREATEST(trophies + $2, 0), rating = $3, updated_at = NOW()
		WHERE account_id = $1
	`, accountID, trophyDelta, newRating); err != nil {
		return fmt.Errorf("bump profile acc=%d: %w", accountID, err)
	}
	return nil
}
