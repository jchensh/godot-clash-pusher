package auth

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbauth "github.com/jchensh/godot-clash-pusher/server/internal/pb/auth"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
)

// Handler is the HTTP entry point for /v4/auth/* routes.
//
// V4-S1 only handles login and refresh; profile read/write lives in its own
// handler package (internal/profile) as of V4-S2.
type Handler struct {
	Repo   *AccountRepo
	Issuer *Issuer
	Now    func() time.Time // overridable in tests for deterministic exp claims
}

// NewHandler wires up dependencies. Now defaults to time.Now.
func NewHandler(repo *AccountRepo, iss *Issuer) *Handler {
	return &Handler{Repo: repo, Issuer: iss, Now: time.Now}
}

// Mount registers /v4/auth/login and /v4/auth/refresh on the given mux.
// Uses Go 1.22+ method+pattern routing (POST /path); requires Go 1.22+.
// These two routes are intentionally unauthenticated — they bootstrap the token.
func (h *Handler) Mount(mux *http.ServeMux) {
	mux.HandleFunc("POST /v4/auth/login", h.handleLogin)
	mux.HandleFunc("POST /v4/auth/refresh", h.handleRefresh)
}

func (h *Handler) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req pbauth.LoginReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if req.DeviceId == "" {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "device_id required", pbcommon.MsgId_LOGIN_REQ)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	acc, err := h.Repo.FindOrCreateByDevice(ctx, req.DeviceId)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if acc.BanStatus >= 2 {
		httpx.WriteError(w, http.StatusForbidden, pbcommon.ErrorCode_ERR_AUTH_BANNED, "account banned", pbcommon.MsgId_LOGIN_REQ)
		return
	}

	now := h.Now()
	access, err := h.Issuer.SignAccess(acc.ID, now)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign access: "+err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	refresh, err := h.Issuer.SignRefresh(acc.ID, now)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign refresh: "+err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}

	httpx.WriteProto(w, http.StatusOK, &pbauth.LoginResp{
		Token:        access,
		RefreshToken: refresh,
		// Profile is populated by V4-S2's profile endpoints; login stays lean.
	})
}

func (h *Handler) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req pbauth.RefreshReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_REFRESH_REQ)
		return
	}
	if req.RefreshToken == "" {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "refresh_token required", pbcommon.MsgId_REFRESH_REQ)
		return
	}
	c, err := h.Issuer.Verify(req.RefreshToken, KindRefresh)
	if err != nil {
		// Distinguish expired from outright invalid so the client can prompt
		// the user to log in again rather than retry.
		if errors.Is(err, context.DeadlineExceeded) {
			httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_AUTH_EXPIRED, err.Error(), pbcommon.MsgId_REFRESH_REQ)
		} else {
			httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_AUTH_INVALID_TOKEN, err.Error(), pbcommon.MsgId_REFRESH_REQ)
		}
		return
	}

	now := h.Now()
	access, err := h.Issuer.SignAccess(c.AccountID, now)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign access: "+err.Error(), pbcommon.MsgId_REFRESH_REQ)
		return
	}
	refresh, err := h.Issuer.SignRefresh(c.AccountID, now)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign refresh: "+err.Error(), pbcommon.MsgId_REFRESH_REQ)
		return
	}

	httpx.WriteProto(w, http.StatusOK, &pbauth.RefreshResp{
		Token:        access,
		RefreshToken: refresh,
	})
}
