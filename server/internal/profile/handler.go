package profile

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbprofile "github.com/jchensh/godot-clash-pusher/server/internal/pb/profile"
)

// Handler serves /v4/profile/*. Every route is auth-gated so an account only
// ever reads or writes its own profile (account id comes from the token, never
// the request body).
type Handler struct {
	Repo *Repo
}

// NewHandler wires the profile repo.
func NewHandler(repo *Repo) *Handler {
	return &Handler{Repo: repo}
}

// Mount registers the profile routes, each wrapped by the auth middleware.
func (h *Handler) Mount(mux *http.ServeMux, mw *auth.Middleware) {
	mux.HandleFunc("POST /v4/profile/get", mw.Require(h.handleGet))
	mux.HandleFunc("POST /v4/profile/deck-update", mw.Require(h.handleDeckUpdate))
	mux.HandleFunc("POST /v4/profile/update", mw.Require(h.handleUpdate))               // V5-S9 改昵称/头像
	mux.HandleFunc("POST /v4/profile/tutorial-done", mw.Require(h.handleTutorialDone)) // V5-S9 标记引导完成
}

func (h *Handler) handleGet(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_PROFILE_GET_REQ)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	p, decks, err := h.Repo.Get(ctx, accountID)
	if err != nil {
		if errors.Is(err, ErrProfileNotFound) {
			httpx.WriteError(w, http.StatusNotFound, pbcommon.ErrorCode_ERR_NOT_FOUND, "profile not found", pbcommon.MsgId_PROFILE_GET_REQ)
			return
		}
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_PROFILE_GET_REQ)
		return
	}

	httpx.WriteProto(w, http.StatusOK, &pbprofile.ProfileGetResp{
		Profile: toPbProfile(p),
		Decks:   toPbDecks(decks),
		// Empty unlocked_card_ids = all cards unlocked (V4-S2 decision 1). The
		// client owns cards.json and treats empty as "everything available";
		// real differentiation lands with IAP/progression in V4-S10.
		UnlockedCardIds: nil,
	})
}

func (h *Handler) handleDeckUpdate(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_DECK_UPDATE_REQ)
		return
	}

	var req pbprofile.DeckUpdateReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_DECK_UPDATE_REQ)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	p, err := h.Repo.UpdateDeck(ctx, accountID, req.Slot, req.CardIds, req.SetActive, req.ExpectedVersion)
	if err != nil {
		switch {
		case errors.Is(err, ErrDeckInvalid):
			httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_PROFILE_DECK_INVALID, err.Error(), pbcommon.MsgId_DECK_UPDATE_REQ)
		case errors.Is(err, ErrVersionMismatch):
			// 409: the client's expected_version was stale; it must re-fetch
			// and retry (server version wins — V4-S2 conflict rule).
			httpx.WriteError(w, http.StatusConflict, pbcommon.ErrorCode_ERR_PROFILE_VERSION_MISMATCH, "version mismatch; re-fetch profile", pbcommon.MsgId_DECK_UPDATE_REQ)
		default:
			httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_DECK_UPDATE_REQ)
		}
		return
	}

	httpx.WriteProto(w, http.StatusOK, &pbprofile.DeckUpdateResp{
		Ok:         true,
		NewVersion: p.Version,
		Profile:    toPbProfile(p),
	})
}

// handleUpdate sets nickname + avatar (V5-S9 创号/改身份). account from token, not body.
func (h *Handler) handleUpdate(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_PROFILE_UPDATE_REQ)
		return
	}
	var req pbprofile.ProfileUpdateReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_PROFILE_UPDATE_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	p, err := h.Repo.UpdateIdentity(ctx, accountID, req.Nickname, req.AvatarCardId)
	if err != nil {
		switch {
		case errors.Is(err, ErrNicknameInvalid):
			httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_PROFILE_UPDATE_REQ)
		case errors.Is(err, ErrProfileNotFound):
			httpx.WriteError(w, http.StatusNotFound, pbcommon.ErrorCode_ERR_NOT_FOUND, "profile not found", pbcommon.MsgId_PROFILE_UPDATE_REQ)
		default:
			httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_PROFILE_UPDATE_REQ)
		}
		return
	}
	httpx.WriteProto(w, http.StatusOK, &pbprofile.ProfileUpdateResp{Profile: toPbProfile(p)})
}

// handleTutorialDone marks the new-player tutorial complete (V5-S9). Empty req body.
func (h *Handler) handleTutorialDone(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_PROFILE_TUTORIAL_DONE_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	p, err := h.Repo.SetTutorialDone(ctx, accountID)
	if err != nil {
		if errors.Is(err, ErrProfileNotFound) {
			httpx.WriteError(w, http.StatusNotFound, pbcommon.ErrorCode_ERR_NOT_FOUND, "profile not found", pbcommon.MsgId_PROFILE_TUTORIAL_DONE_REQ)
			return
		}
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_PROFILE_TUTORIAL_DONE_REQ)
		return
	}
	httpx.WriteProto(w, http.StatusOK, &pbprofile.ProfileUpdateResp{Profile: toPbProfile(p)})
}

func toPbProfile(p *Profile) *pbprofile.Profile {
	return &pbprofile.Profile{
		AccountId:       p.AccountID,
		Nickname:        p.Nickname,
		AvatarId:        p.AvatarID,
		Level:           p.Level,
		Exp:             p.Exp,
		Trophies:        p.Trophies,
		CurrentSeasonId: p.CurrentSeasonID,
		Version:         p.Version,
		UpdatedAt:       p.UpdatedAt,
		AvatarCardId:    p.AvatarCardID,
		TutorialDone:    p.TutorialDone,
	}
}

func toPbDecks(decks []Deck) []*pbprofile.DeckMsg {
	out := make([]*pbprofile.DeckMsg, 0, len(decks))
	for _, d := range decks {
		out = append(out, &pbprofile.DeckMsg{
			Id:       d.ID,
			Slot:     d.Slot,
			CardIds:  d.CardIDs,
			IsActive: d.IsActive,
		})
	}
	return out
}
