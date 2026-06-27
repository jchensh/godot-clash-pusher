package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
)

// ctxKey is an unexported context-key type so no other package can collide
// with (or read) the account id we stash on the request context.
type ctxKey int

const accountIDKey ctxKey = 0

// Middleware verifies the Bearer access token on protected routes and injects
// the authenticated account id into the request context. Built once at boot
// and reused; V4-S2 uses it for profile, V4-S3+ for battle/match.
type Middleware struct {
	Issuer *Issuer
}

// NewMiddleware wraps a shared Issuer.
func NewMiddleware(iss *Issuer) *Middleware {
	return &Middleware{Issuer: iss}
}

// Require wraps next, rejecting any request without a valid, unexpired access
// token (401). On success the account id is available via AccountIDFromContext.
func (m *Middleware) Require(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r)
		if !ok {
			httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_AUTH_INVALID_TOKEN, "missing bearer token", pbcommon.MsgId_MSG_UNKNOWN)
			return
		}
		claims, err := m.Issuer.Verify(token, KindAccess)
		if err != nil {
			// Expired tokens get their own code so the client knows to refresh
			// (rather than force a full re-login).
			code := pbcommon.ErrorCode_ERR_AUTH_INVALID_TOKEN
			if errors.Is(err, jwt.ErrTokenExpired) {
				code = pbcommon.ErrorCode_ERR_AUTH_EXPIRED
			}
			httpx.WriteError(w, http.StatusUnauthorized, code, err.Error(), pbcommon.MsgId_MSG_UNKNOWN)
			return
		}
		ctx := context.WithValue(r.Context(), accountIDKey, claims.AccountID)
		next(w, r.WithContext(ctx))
	}
}

// AccountIDFromContext returns the account id stamped by Require. ok is false
// if the request didn't pass through the middleware (defensive — shouldn't
// happen on a protected route).
func AccountIDFromContext(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(accountIDKey).(int64)
	return id, ok
}

// bearerToken pulls the token out of an "Authorization: Bearer <token>" header.
func bearerToken(r *http.Request) (string, bool) {
	const prefix = "Bearer "
	h := r.Header.Get("Authorization")
	if len(h) <= len(prefix) || !strings.EqualFold(h[:len(prefix)], prefix) {
		return "", false
	}
	return h[len(prefix):], true
}
