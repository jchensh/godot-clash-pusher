package auth

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	pbauth "github.com/jchensh/godot-clash-pusher/server/internal/pb/auth"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"google.golang.org/protobuf/proto"
)

// Handler is the HTTP entry point for /v4/auth/* routes.
//
// V4-S1 only handles login and refresh; profile read/write moves to its own
// handler package in V4-S2.
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
func (h *Handler) Mount(mux *http.ServeMux) {
	mux.HandleFunc("POST /v4/auth/login", h.handleLogin)
	mux.HandleFunc("POST /v4/auth/refresh", h.handleRefresh)
}

// ContentTypeProtobuf is the wire format for the V4 HTTP API.
// Kept identical to the WS frame payload in V4-S3 so codecs are shared.
const ContentTypeProtobuf = "application/x-protobuf"

// maxBodyBytes caps the request body for auth endpoints (16 KiB plenty for
// a few JWT-sized strings; prevents accidental DoS through giant payloads).
const maxBodyBytes = 16 * 1024

func readProto(r *http.Request, m proto.Message) error {
	body, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, maxBodyBytes))
	if err != nil {
		return fmt.Errorf("read body: %w", err)
	}
	return proto.Unmarshal(body, m)
}

func writeProto(w http.ResponseWriter, status int, m proto.Message) {
	body, err := proto.Marshal(m)
	if err != nil {
		http.Error(w, "marshal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", ContentTypeProtobuf)
	w.WriteHeader(status)
	_, _ = w.Write(body)
}

func writeError(w http.ResponseWriter, status int, code pbcommon.ErrorCode, detail string, inReplyTo pbcommon.MsgId) {
	writeProto(w, status, &pbcommon.ErrorResp{
		Code:      code,
		Detail:    detail,
		InReplyTo: inReplyTo,
	})
}

func (h *Handler) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req pbauth.LoginReq
	if err := readProto(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if req.DeviceId == "" {
		writeError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "device_id required", pbcommon.MsgId_LOGIN_REQ)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	acc, err := h.Repo.FindOrCreateByDevice(ctx, req.DeviceId)
	if err != nil {
		writeError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if acc.BanStatus >= 2 {
		writeError(w, http.StatusForbidden, pbcommon.ErrorCode_ERR_AUTH_BANNED, "account banned", pbcommon.MsgId_LOGIN_REQ)
		return
	}

	now := h.Now()
	access, err := h.Issuer.SignAccess(acc.ID, now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign access: "+err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	refresh, err := h.Issuer.SignRefresh(acc.ID, now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign refresh: "+err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}

	writeProto(w, http.StatusOK, &pbauth.LoginResp{
		Token:        access,
		RefreshToken: refresh,
		// Profile is populated by V4-S2; in S1 the client tolerates nil.
	})
}

func (h *Handler) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req pbauth.RefreshReq
	if err := readProto(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_REFRESH_REQ)
		return
	}
	if req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "refresh_token required", pbcommon.MsgId_REFRESH_REQ)
		return
	}
	c, err := h.Issuer.Verify(req.RefreshToken, KindRefresh)
	if err != nil {
		// Distinguish expired from outright invalid so the client can prompt
		// the user to log in again rather than retry.
		if errors.Is(err, context.DeadlineExceeded) {
			writeError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_AUTH_EXPIRED, err.Error(), pbcommon.MsgId_REFRESH_REQ)
		} else {
			writeError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_AUTH_INVALID_TOKEN, err.Error(), pbcommon.MsgId_REFRESH_REQ)
		}
		return
	}

	now := h.Now()
	access, err := h.Issuer.SignAccess(c.AccountID, now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign access: "+err.Error(), pbcommon.MsgId_REFRESH_REQ)
		return
	}
	refresh, err := h.Issuer.SignRefresh(c.AccountID, now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign refresh: "+err.Error(), pbcommon.MsgId_REFRESH_REQ)
		return
	}

	writeProto(w, http.StatusOK, &pbauth.RefreshResp{
		Token:        access,
		RefreshToken: refresh,
	})
}
