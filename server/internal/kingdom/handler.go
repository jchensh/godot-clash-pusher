package kingdom

import (
	"context"
	"errors"
	"log"
	"net/http"
	"sort"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbkingdom "github.com/jchensh/godot-clash-pusher/server/internal/pb/kingdom"
)

// Handler serves /v5/kingdom/*（K1，DESIGN_KINGDOM.md）。账号只读写自己的王国
// （account id 取自令牌，不信 body）；成本/上限/计时/产出全在服务器用服务器侧配置算。
type Handler struct {
	repo    *Repo
	cfg     *Config
	econCfg *economy.Config
}

func NewHandler(repo *Repo, cfg *Config, econCfg *economy.Config) *Handler {
	return &Handler{repo: repo, cfg: cfg, econCfg: econCfg}
}

func (h *Handler) Mount(mux *http.ServeMux, mw *auth.Middleware) {
	mux.HandleFunc("GET /v5/kingdom/state", mw.Require(h.getState))
	mux.HandleFunc("POST /v5/kingdom/upgrade", mw.Require(h.upgrade))
	mux.HandleFunc("POST /v5/kingdom/collect", mw.Require(h.collect))
	mux.HandleFunc("POST /v5/kingdom/speedup", mw.Require(h.speedup))
}

func (h *Handler) getState(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_KINGDOM_STATE_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := h.repo.Get(ctx, accountID, h.cfg, h.econCfg)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_KINGDOM_STATE_REQ)
		return
	}
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

func (h *Handler) upgrade(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, "upgrade", pbcommon.MsgId_KINGDOM_UPGRADE_REQ,
		func(ctx context.Context, accountID int64, building string) (State, error) {
			return h.repo.Upgrade(ctx, accountID, building, h.cfg, h.econCfg)
		})
}

func (h *Handler) collect(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, "collect", pbcommon.MsgId_KINGDOM_COLLECT_REQ,
		func(ctx context.Context, accountID int64, _ string) (State, error) {
			return h.repo.Collect(ctx, accountID, h.cfg, h.econCfg)
		})
}

func (h *Handler) speedup(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, "speedup", pbcommon.MsgId_KINGDOM_SPEEDUP_REQ,
		func(ctx context.Context, accountID int64, building string) (State, error) {
			return h.repo.Speedup(ctx, accountID, building, h.cfg, h.econCfg)
		})
}

func (h *Handler) action(w http.ResponseWriter, r *http.Request, op string, msgID pbcommon.MsgId,
	fn func(context.Context, int64, string) (State, error)) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", msgID)
		return
	}
	var req pbkingdom.KingdomActionReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "bad request body", msgID)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := fn(ctx, accountID, req.GetBuilding())
	if err != nil {
		status, code := classify(err)
		log.Printf("kingdom %s account=%d building=%q rejected: %v", op, accountID, req.GetBuilding(), err)
		httpx.WriteError(w, status, code, err.Error(), msgID)
		return
	}
	log.Printf("kingdom %s account=%d building=%q ok", op, accountID, req.GetBuilding())
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

// classify maps settlement rejections to HTTP/pb codes（复用 economy 错误码族——
// 语义同族：资源不足/达上限/门槛未满足；避免为王国单开码段，客户端处理归一）。
func classify(err error) (int, pbcommon.ErrorCode) {
	switch {
	case errors.Is(err, ErrInsufficient):
		return http.StatusConflict, pbcommon.ErrorCode_ERR_ECONOMY_INSUFFICIENT
	case errors.Is(err, ErrAtCap):
		return http.StatusConflict, pbcommon.ErrorCode_ERR_ECONOMY_AT_CAP
	case errors.Is(err, ErrKeepGate), errors.Is(err, ErrChapterLocked):
		return http.StatusConflict, pbcommon.ErrorCode_ERR_ECONOMY_LOCKED
	case errors.Is(err, ErrBuilderBusy), errors.Is(err, ErrNotUpgrading), errors.Is(err, ErrUnknownBuilding):
		return http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG
	default:
		return http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL
	}
}

func toProto(st State) *pbkingdom.KingdomState {
	out := &pbkingdom.KingdomState{
		ServerNowTs: st.Now,
		PendingGold: st.PendingGold,
	}
	for _, k := range sortedKeys(st.Resources) {
		out.Resources = append(out.Resources, &pbkingdom.ResourceAmount{Resource: k, Amount: st.Resources[k]})
	}
	for _, b := range st.Buildings {
		out.Buildings = append(out.Buildings, &pbkingdom.KingdomBuilding{
			Building:     b.Building,
			Level:        int32(b.Level),
			UpgradeEndTs: b.UpgradeEndTs,
		})
	}
	for _, k := range sortedKeys(st.Pending) {
		out.Pending = append(out.Pending, &pbkingdom.ResourceAmount{Resource: k, Amount: st.Pending[k]})
	}
	return out
}

func sortedKeys(m map[string]int64) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
