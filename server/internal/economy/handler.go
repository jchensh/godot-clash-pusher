package economy

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbeconomy "github.com/jchensh/godot-clash-pusher/server/internal/pb/economy"
)

// Handler serves /v5/economy/*. 决策 48：账号只读写自己的经济状态（account id 取自令牌，
// 不信 body）；成本/上限/解锁门槛全在服务器用服务器侧配置算。
type Handler struct {
	repo *Repo
	cfg  *Config
}

func NewHandler(repo *Repo, cfg *Config) *Handler {
	return &Handler{repo: repo, cfg: cfg}
}

func (h *Handler) Mount(mux *http.ServeMux, mw *auth.Middleware) {
	mux.HandleFunc("GET /v5/economy/state", mw.Require(h.getState))
	mux.HandleFunc("POST /v5/economy/upgrade", mw.Require(h.upgrade))
	mux.HandleFunc("POST /v5/economy/rank-up", mw.Require(h.rankUp))
	mux.HandleFunc("POST /v5/economy/unlock", mw.Require(h.unlock))
	mux.HandleFunc("POST /v5/economy/stage-clear", mw.Require(h.stageClear))
}

func (h *Handler) getState(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_ECONOMY_STATE_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := h.repo.Get(ctx, accountID, h.cfg)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_ECONOMY_STATE_REQ)
		return
	}
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

func (h *Handler) upgrade(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, h.repo.Upgrade, pbcommon.MsgId_ECONOMY_UPGRADE_REQ)
}
func (h *Handler) rankUp(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, h.repo.RankUp, pbcommon.MsgId_ECONOMY_RANK_UP_REQ)
}
func (h *Handler) unlock(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, h.repo.Unlock, pbcommon.MsgId_ECONOMY_UNLOCK_REQ)
}

// stageClear (V5-N5)：客户端上报 (stage_id, stars)，服务器 sanity 校验 + 发奖 + 记进度。
// 与 upgrade/rank-up/unlock 不同（带 stars，不是单 card_id），单独处理。
func (h *Handler) stageClear(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_ECONOMY_STAGE_CLEAR_REQ)
		return
	}
	var req pbeconomy.StageClearReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_ECONOMY_STAGE_CLEAR_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := h.repo.StageClear(ctx, accountID, req.GetStageId(), int(req.GetStars()), h.cfg)
	if err != nil {
		code, status := mapErr(err)
		httpx.WriteError(w, status, code, err.Error(), pbcommon.MsgId_ECONOMY_STAGE_CLEAR_REQ)
		return
	}
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

type actionFn func(context.Context, int64, string, *Config) (State, error)

func (h *Handler) action(w http.ResponseWriter, r *http.Request, fn actionFn, reqMsg pbcommon.MsgId) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", reqMsg)
		return
	}
	var req pbeconomy.EconomyActionReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), reqMsg)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := fn(ctx, accountID, req.GetCardId(), h.cfg)
	if err != nil {
		code, status := mapErr(err)
		httpx.WriteError(w, status, code, err.Error(), reqMsg)
		return
	}
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

func mapErr(err error) (pbcommon.ErrorCode, int) {
	switch {
	case errors.Is(err, ErrInsufficient):
		return pbcommon.ErrorCode_ERR_ECONOMY_INSUFFICIENT, http.StatusConflict
	case errors.Is(err, ErrAtCap):
		return pbcommon.ErrorCode_ERR_ECONOMY_AT_CAP, http.StatusConflict
	case errors.Is(err, ErrLocked):
		return pbcommon.ErrorCode_ERR_ECONOMY_LOCKED, http.StatusConflict
	case errors.Is(err, ErrStageLocked):
		return pbcommon.ErrorCode_ERR_ECONOMY_STAGE_LOCKED, http.StatusConflict
	case errors.Is(err, ErrUnknownCard),
		errors.Is(err, ErrInvalidStars),
		errors.Is(err, ErrTooManyStars),
		errors.Is(err, ErrUnknownStage):
		return pbcommon.ErrorCode_ERR_INVALID_ARG, http.StatusBadRequest
	default:
		return pbcommon.ErrorCode_ERR_INTERNAL, http.StatusInternalServerError
	}
}

func toProto(st State) *pbeconomy.EconomyState {
	out := &pbeconomy.EconomyState{
		Gold:              st.Gold,
		Gems:              st.Gems,
		IdleLastCollectTs: st.IdleLastCollect,
		HighestCleared:    st.HighestCleared,
	}
	for _, c := range st.Cards {
		out.Cards = append(out.Cards, &pbeconomy.CardState{
			CardId: c.CardID, Level: int32(c.Level), Rank: int32(c.Rank), Shards: int32(c.Shards), Unlocked: c.Unlocked,
		})
	}
	for _, s := range st.Stages {
		out.Stages = append(out.Stages, &pbeconomy.StageState{
			StageId: s.StageID, Stars: int32(s.Stars), Cleared: s.Cleared,
		})
	}
	return out
}
