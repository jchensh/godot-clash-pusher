// Package auth handles V4 authentication: device-id anonymous login
// and JWT (HS256) access / refresh tokens.
//
// The secret is provided by the caller (cmd/api reads JWT_SECRET env at
// boot and panics if it's missing — see PLAN_V4 §3 decision 46).
//
// V4-S1 only covers the device-id flow; SMS / email / Apple / Google
// providers land in V4-S11 (compliance phase).
package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	// Token kinds. Access tokens authorize every request; refresh tokens are
	// only used to obtain a new access token. Separating the two means a
	// stolen access token can't be exchanged for an infinite refresh chain.
	KindAccess  = "access"
	KindRefresh = "refresh"

	defaultAccessTTL  = 30 * 24 * time.Hour // 30 days
	defaultRefreshTTL = 90 * 24 * time.Hour // 90 days
)

// Claims is what we embed in every V4 JWT. AccountID is the only payload
// that matters for routing; Kind disambiguates access vs refresh.
type Claims struct {
	AccountID int64  `json:"aid"`
	Kind      string `json:"kind"`
	jwt.RegisteredClaims
}

// Issuer mints and verifies JWTs with a single HS256 secret.
// Instantiate once at boot, reuse across requests.
type Issuer struct {
	secret     []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
}

// NewIssuer requires a non-empty secret. Defaults: access TTL 30d, refresh 90d.
// Tests can override the TTLs via SetTTLs.
func NewIssuer(secret []byte) (*Issuer, error) {
	if len(secret) == 0 {
		return nil, errors.New("jwt secret must not be empty")
	}
	return &Issuer{
		secret:     secret,
		accessTTL:  defaultAccessTTL,
		refreshTTL: defaultRefreshTTL,
	}, nil
}

// SetTTLs overrides default token lifetimes. Mostly for tests.
func (iss *Issuer) SetTTLs(access, refresh time.Duration) {
	iss.accessTTL = access
	iss.refreshTTL = refresh
}

// SignAccess returns a signed access JWT for the given account id.
// `now` is taken as the issued-at clock to make tests deterministic.
func (iss *Issuer) SignAccess(accountID int64, now time.Time) (string, error) {
	return iss.sign(accountID, KindAccess, now, iss.accessTTL)
}

// SignRefresh returns a signed refresh JWT for the given account id.
func (iss *Issuer) SignRefresh(accountID int64, now time.Time) (string, error) {
	return iss.sign(accountID, KindRefresh, now, iss.refreshTTL)
}

func (iss *Issuer) sign(accountID int64, kind string, now time.Time, ttl time.Duration) (string, error) {
	c := Claims{
		AccountID: accountID,
		Kind:      kind,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(iss.secret)
}

// Verify parses, signature-checks, expiry-checks the token, and returns
// the claims. If expectKind is non-empty, also rejects mismatched kinds.
// Pass expectKind="" from middleware that just wants "is it a valid token".
func (iss *Issuer) Verify(token, expectKind string) (*Claims, error) {
	var c Claims
	t, err := jwt.ParseWithClaims(token, &c, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return iss.secret, nil
	})
	if err != nil {
		return nil, fmt.Errorf("parse: %w", err)
	}
	if !t.Valid {
		return nil, errors.New("invalid token")
	}
	if expectKind != "" && c.Kind != expectKind {
		return nil, fmt.Errorf("expected kind %q, got %q", expectKind, c.Kind)
	}
	return &c, nil
}
