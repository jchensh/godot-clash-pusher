package auth

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Account is the persisted row from the accounts table, returned by lookup
// / create operations. Created==true on the first call for a given device.
type Account struct {
	ID         int64
	Provider   string
	ExternalID string
	BanStatus  int16
	Created    bool
}

// AccountRepo persists accounts + their default profile rows.
// V4-S1 only needs FindOrCreateByDevice; later steps add Get/Update.
type AccountRepo struct {
	pool *pgxpool.Pool
}

// NewAccountRepo wraps a pgxpool reused across requests.
func NewAccountRepo(pool *pgxpool.Pool) *AccountRepo {
	return &AccountRepo{pool: pool}
}

// FindOrCreateByDevice returns the account matching (provider="device",
// external_id=deviceID), creating it (plus a default profile row) on first
// call. The whole operation runs in a single transaction so partial state
// never escapes on error. last_login_at is bumped on both paths.
func (r *AccountRepo) FindOrCreateByDevice(ctx context.Context, deviceID string) (*Account, error) {
	if deviceID == "" {
		return nil, errors.New("deviceID must not be empty")
	}
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var acc Account

	// Optimistic INSERT first; ON CONFLICT DO NOTHING means an existing row
	// silently leaves the table unchanged and RETURNING yields no rows.
	row := tx.QueryRow(ctx, `
		INSERT INTO accounts (provider, external_id, last_login_at)
		VALUES ('device', $1, NOW())
		ON CONFLICT (provider, external_id) DO NOTHING
		RETURNING id, provider, external_id, ban_status
	`, deviceID)
	err = row.Scan(&acc.ID, &acc.Provider, &acc.ExternalID, &acc.BanStatus)
	switch {
	case err == nil:
		acc.Created = true
	case errors.Is(err, pgx.ErrNoRows):
		// Row already existed; fetch it and bump last_login_at in one statement.
		row = tx.QueryRow(ctx, `
			UPDATE accounts SET last_login_at = NOW()
			WHERE provider = 'device' AND external_id = $1
			RETURNING id, provider, external_id, ban_status
		`, deviceID)
		if err := row.Scan(&acc.ID, &acc.Provider, &acc.ExternalID, &acc.BanStatus); err != nil {
			return nil, fmt.Errorf("select existing account: %w", err)
		}
	default:
		return nil, fmt.Errorf("insert account: %w", err)
	}

	if acc.Created {
		// First time we've seen this device — seed a default profile so the
		// client always has something to read on its next /profile/get call.
		if _, err := tx.Exec(ctx, `
			INSERT INTO profiles (account_id, nickname)
			VALUES ($1, $2)
		`, acc.ID, defaultNickname(acc.ID)); err != nil {
			return nil, fmt.Errorf("insert profile: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}
	return &acc, nil
}

// defaultNickname is the placeholder shown until the player picks one.
// V4-S2 adds a profile update endpoint.
func defaultNickname(id int64) string {
	return fmt.Sprintf("Player%d", id)
}
