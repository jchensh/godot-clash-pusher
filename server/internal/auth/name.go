package auth

// KAN-109（2026-07-15）：username 裸登录（开发/测试阶段）。
//
// 身份复用 accounts 的 (provider, external_id) 复合唯一键：provider='name'、
// external_id=username —— 无需新增表结构，username 全服唯一由既有约束保证。
// username 与游戏内昵称合一：注册时 profiles.nickname = username。
//
// 端点为 JSON 请求 + protobuf LoginResp 响应（GM 端点同款先例，免双端 proto 重生成）：
//   POST /v5/auth/check-name  {"username"} → 200 JSON {valid, registered, reason}
//   POST /v5/auth/register    {"username","avatar_card_id"} → pb LoginResp(is_new=true) | 409 已占用
//   POST /v5/auth/login-name  {"username"} → pb LoginResp(is_new=false) | 404 未注册
//
// ⚠️ 安全边界（用户 2026-07-15 拍板）：无凭证 = 任何人可凭 username 顶号，仅限
// 开发/测试环境；E2 公网安全阶段必须补凭证（密码/设备绑定），届时本文件收编进正式协议。
// V4-S1 的 device_id 匿名登录（/v4/auth/login）保持挂载不动——正式上线"新设备直进
// 引导"的体验仍有意义，客户端侧暂时注释停用。

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbauth "github.com/jchensh/godot-clash-pusher/server/internal/pb/auth"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
)

var (
	// ErrUsernameInvalid marks names failing the width/charset rule.
	ErrUsernameInvalid = errors.New("username invalid")
	// ErrUsernameTaken marks register attempts on an existing name.
	ErrUsernameTaken = errors.New("username taken")
	// ErrUsernameNotFound marks login attempts on an unregistered name.
	ErrUsernameNotFound = errors.New("username not found")
)

// validateUsername mirrors profile.validateNickname（KAN-71 宽度规则）：宽字符
// （CJK/全角/emoji）计 1 全格、窄字符（ASCII/Latin）计 0.5，上限 10 全格；拒空与
// 控制字符。两处必须同口径（username 即昵称），tests 有跨包一致性用例把关。
func validateUsername(raw string) (string, error) {
	n := strings.TrimSpace(raw)
	if n == "" {
		return "", fmt.Errorf("%w: empty", ErrUsernameInvalid)
	}
	half := 0
	for _, r := range n {
		if r < 0x20 || r == 0x7f {
			return "", fmt.Errorf("%w: control char", ErrUsernameInvalid)
		}
		if r <= 0xFF {
			half += 1
		} else {
			half += 2
		}
	}
	if half > 20 {
		return "", fmt.Errorf("%w: too long (max 10 full-width)", ErrUsernameInvalid)
	}
	return n, nil
}

// NameExists reports whether a name-provider account exists (server-authoritative
// "老玩家判定"——客户端本地有没有数据不再作数).
func (r *AccountRepo) NameExists(ctx context.Context, username string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM accounts WHERE provider = 'name' AND external_id = $1)
	`, username).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("name exists: %w", err)
	}
	return exists, nil
}

// FindByName returns the account for an existing username, bumping
// last_login_at. ErrUsernameNotFound when no such account.
func (r *AccountRepo) FindByName(ctx context.Context, username string) (*Account, error) {
	var acc Account
	row := r.pool.QueryRow(ctx, `
		UPDATE accounts SET last_login_at = NOW()
		WHERE provider = 'name' AND external_id = $1
		RETURNING id, provider, external_id, ban_status
	`, username)
	err := row.Scan(&acc.ID, &acc.Provider, &acc.ExternalID, &acc.BanStatus)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUsernameNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("find by name: %w", err)
	}
	return &acc, nil
}

// CreateByName registers a new username account plus its profile row
// (nickname = username, avatar picked at register). ErrUsernameTaken on conflict.
func (r *AccountRepo) CreateByName(ctx context.Context, username, avatarCardID string) (*Account, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var acc Account
	row := tx.QueryRow(ctx, `
		INSERT INTO accounts (provider, external_id, last_login_at)
		VALUES ('name', $1, NOW())
		ON CONFLICT (provider, external_id) DO NOTHING
		RETURNING id, provider, external_id, ban_status
	`, username)
	err = row.Scan(&acc.ID, &acc.Provider, &acc.ExternalID, &acc.BanStatus)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUsernameTaken
	}
	if err != nil {
		return nil, fmt.Errorf("insert name account: %w", err)
	}
	acc.Created = true

	if _, err := tx.Exec(ctx, `
		INSERT INTO profiles (account_id, nickname, avatar_card_id)
		VALUES ($1, $2, $3)
	`, acc.ID, username, avatarCardID); err != nil {
		return nil, fmt.Errorf("insert profile: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}
	return &acc, nil
}

// ---------------- HTTP handlers ----------------

type nameReq struct {
	Username     string `json:"username"`
	AvatarCardID string `json:"avatar_card_id"`
}

func readNameReq(r *http.Request) (*nameReq, error) {
	var req nameReq
	dec := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 4096))
	if err := dec.Decode(&req); err != nil {
		return nil, fmt.Errorf("decode json: %w", err)
	}
	return &req, nil
}

// MountName registers the /v5/auth/* username routes (unauthenticated —
// they bootstrap the token, same as the device login pair).
func (h *Handler) MountName(mux *http.ServeMux) {
	mux.HandleFunc("POST /v5/auth/check-name", h.handleCheckName)
	mux.HandleFunc("POST /v5/auth/register", h.handleRegisterName)
	mux.HandleFunc("POST /v5/auth/login-name", h.handleLoginName)
}

func (h *Handler) handleCheckName(w http.ResponseWriter, r *http.Request) {
	req, err := readNameReq(r)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	out := map[string]any{"valid": false, "registered": false, "reason": ""}
	name, verr := validateUsername(req.Username)
	if verr != nil {
		out["reason"] = verr.Error()
		writeJSON(w, out)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	exists, err := h.Repo.NameExists(ctx, name)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	out["valid"] = true
	out["registered"] = exists
	writeJSON(w, out)
}

func (h *Handler) handleRegisterName(w http.ResponseWriter, r *http.Request) {
	req, err := readNameReq(r)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	name, verr := validateUsername(req.Username)
	if verr != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, verr.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if strings.TrimSpace(req.AvatarCardID) == "" {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "avatar_card_id required", pbcommon.MsgId_LOGIN_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	acc, err := h.Repo.CreateByName(ctx, name, strings.TrimSpace(req.AvatarCardID))
	if errors.Is(err, ErrUsernameTaken) {
		httpx.WriteError(w, http.StatusConflict, pbcommon.ErrorCode_ERR_INVALID_ARG, "username taken", pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	h.writeLoginResp(w, acc.ID, true)
}

func (h *Handler) handleLoginName(w http.ResponseWriter, r *http.Request) {
	req, err := readNameReq(r)
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	name := strings.TrimSpace(req.Username)
	if name == "" {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "username required", pbcommon.MsgId_LOGIN_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	acc, err := h.Repo.FindByName(ctx, name)
	if errors.Is(err, ErrUsernameNotFound) {
		httpx.WriteError(w, http.StatusNotFound, pbcommon.ErrorCode_ERR_NOT_FOUND, "username not registered", pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	if acc.BanStatus >= 2 {
		httpx.WriteError(w, http.StatusForbidden, pbcommon.ErrorCode_ERR_AUTH_BANNED, "account banned", pbcommon.MsgId_LOGIN_REQ)
		return
	}
	h.writeLoginResp(w, acc.ID, false)
}

// writeLoginResp issues the access/refresh pair and writes the shared pb
// LoginResp（与 /v4/auth/login 同构，客户端解析代码复用）。
func (h *Handler) writeLoginResp(w http.ResponseWriter, accountID int64, isNew bool) {
	now := h.Now()
	access, err := h.Issuer.SignAccess(accountID, now)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign access: "+err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	refresh, err := h.Issuer.SignRefresh(accountID, now)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, "sign refresh: "+err.Error(), pbcommon.MsgId_LOGIN_REQ)
		return
	}
	httpx.WriteProto(w, http.StatusOK, &pbauth.LoginResp{
		Token:        access,
		RefreshToken: refresh,
		IsNew:        isNew,
	})
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(v)
}
