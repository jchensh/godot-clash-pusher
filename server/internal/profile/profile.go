// Package profile persists player profiles and their card decks (V4-S2 cloud save).
//
// The repo returns plain domain structs (not protobuf types) so it stays
// independent of the wire format; the HTTP handler maps to/from pb. Writes to a
// deck bump the profile's optimistic-lock version — a stale expected_version
// means the client lost the race and must re-fetch (server wins).
package profile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// deckSize is the fixed number of cards in every deck (shared with V3 cards.json).
const deckSize = 8

// Sentinel errors so the handler can map to the right HTTP status / ErrorCode.
var (
	ErrProfileNotFound = errors.New("profile not found")
	ErrVersionMismatch = errors.New("profile version mismatch") // optimistic lock lost
	ErrDeckInvalid     = errors.New("deck invalid")             // failed validateDeck
)

// Profile mirrors a row of the profiles table (UpdatedAt as unix seconds).
type Profile struct {
	AccountID       int64
	Nickname        string
	AvatarID        int32
	Level           int32
	Exp             int32
	Trophies        int32
	CurrentSeasonID int32
	Version         int32
	UpdatedAt       int64
}

// Deck mirrors a row of the decks table.
type Deck struct {
	ID       int64
	Slot     int32
	CardIDs  []string
	IsActive bool
}

// Repo reads/writes profiles + decks over a shared pgxpool.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo wraps a pgxpool reused across requests.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

const selectProfileCols = `
	account_id, nickname, avatar_id, level, exp, trophies,
	COALESCE(current_season_id, 0), version,
	EXTRACT(EPOCH FROM updated_at)::bigint`

func scanProfile(row pgx.Row, p *Profile) error {
	return row.Scan(&p.AccountID, &p.Nickname, &p.AvatarID, &p.Level,
		&p.Exp, &p.Trophies, &p.CurrentSeasonID, &p.Version, &p.UpdatedAt)
}

// Get returns the profile plus all decks (slot-ordered) for an account.
// A missing profile row is ErrProfileNotFound (shouldn't happen post-S1, where
// FindOrCreateByDevice seeds one, but callers handle it explicitly).
func (r *Repo) Get(ctx context.Context, accountID int64) (*Profile, []Deck, error) {
	var p Profile
	err := scanProfile(r.pool.QueryRow(ctx,
		`SELECT `+selectProfileCols+` FROM profiles WHERE account_id = $1`, accountID), &p)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, ErrProfileNotFound
	}
	if err != nil {
		return nil, nil, fmt.Errorf("select profile: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT id, slot, card_ids, is_active FROM decks WHERE account_id = $1 ORDER BY slot`, accountID)
	if err != nil {
		return nil, nil, fmt.Errorf("query decks: %w", err)
	}
	defer rows.Close()

	var decks []Deck
	for rows.Next() {
		var d Deck
		var raw []byte
		if err := rows.Scan(&d.ID, &d.Slot, &raw, &d.IsActive); err != nil {
			return nil, nil, fmt.Errorf("scan deck: %w", err)
		}
		if err := json.Unmarshal(raw, &d.CardIDs); err != nil {
			return nil, nil, fmt.Errorf("unmarshal card_ids: %w", err)
		}
		decks = append(decks, d)
	}
	if err := rows.Err(); err != nil {
		return nil, nil, fmt.Errorf("iterate decks: %w", err)
	}
	return &p, decks, nil
}

// UpdateDeck upserts the deck in `slot` under optimistic locking: it bumps the
// profile version only if the stored version still equals expectedVersion,
// otherwise returns ErrVersionMismatch. When setActive is true the slot becomes
// the account's sole active deck (every other slot is demoted). The whole thing
// runs in one transaction and returns the post-write profile (new version).
func (r *Repo) UpdateDeck(ctx context.Context, accountID int64, slot int32, cardIDs []string, setActive bool, expectedVersion int32) (*Profile, error) {
	if err := validateDeck(slot, cardIDs); err != nil {
		return nil, err
	}
	cardJSON, err := json.Marshal(cardIDs)
	if err != nil {
		return nil, fmt.Errorf("marshal card_ids: %w", err)
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// CAS the version forward. No matching row means the version didn't match
	// (the profile itself always exists for a logged-in account post-S1).
	var p Profile
	err = scanProfile(tx.QueryRow(ctx, `
		UPDATE profiles SET version = version + 1, updated_at = NOW()
		WHERE account_id = $1 AND version = $2
		RETURNING `+selectProfileCols, accountID, expectedVersion), &p)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrVersionMismatch
	}
	if err != nil {
		return nil, fmt.Errorf("cas profile version: %w", err)
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO decks (account_id, slot, card_ids, is_active)
		VALUES ($1, $2, $3::jsonb, $4)
		ON CONFLICT (account_id, slot)
		DO UPDATE SET card_ids = EXCLUDED.card_ids, is_active = EXCLUDED.is_active
	`, accountID, slot, string(cardJSON), setActive); err != nil {
		return nil, fmt.Errorf("upsert deck: %w", err)
	}

	if setActive {
		if _, err := tx.Exec(ctx, `
			UPDATE decks SET is_active = FALSE
			WHERE account_id = $1 AND slot <> $2
		`, accountID, slot); err != nil {
			return nil, fmt.Errorf("demote other decks: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}
	return &p, nil
}

// validateDeck enforces the structural rules a deck must satisfy. Per V4-S2
// decision 2 it does NOT check card-id existence — the server owns no card
// config; the client (which holds cards.json) guarantees that.
func validateDeck(slot int32, cardIDs []string) error {
	if slot < 1 || slot > 3 {
		return fmt.Errorf("%w: slot must be 1..3, got %d", ErrDeckInvalid, slot)
	}
	if len(cardIDs) != deckSize {
		return fmt.Errorf("%w: deck must have %d cards, got %d", ErrDeckInvalid, deckSize, len(cardIDs))
	}
	seen := make(map[string]struct{}, deckSize)
	for _, id := range cardIDs {
		if id == "" {
			return fmt.Errorf("%w: empty card_id", ErrDeckInvalid)
		}
		if _, dup := seen[id]; dup {
			return fmt.Errorf("%w: duplicate card_id %q", ErrDeckInvalid, id)
		}
		seen[id] = struct{}{}
	}
	return nil
}
