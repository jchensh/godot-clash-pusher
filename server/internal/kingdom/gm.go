package kingdom

// GM / 开发作弊工具（王国侧，镜像 economy/gm.go 口径）：直接改本账号的王国 DB。
// 与 economy GM 同一纪律：无门控始终开放、走会话鉴权只能改自己、请求 JSON、响应 KingdomState proto。

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
)

// GMOps 是一次王国 GM 应用的全部操作（缺省字段=不操作）。
type GMOps struct {
	AddResources map[string]int64 `json:"add_resources"` // {"food":N,"wood":N} 直加（作弊镜像不走仓库封顶）
	FinishBuilds bool             `json:"finish_builds"` // 所有施工立即完级（加速类总开关）
	Reset        bool             `json:"reset"`         // 清空王国两表 → 重新播种新档
}

// GMApply 应用王国 GM 操作并返回新快照。
func (r *Repo) GMApply(ctx context.Context, accountID int64, ops GMOps, cfg *Config, econCfg *economy.Config) (State, error) {
	if ops.Reset {
		// 先独立事务清两表，随后 mutate 的 ensureSeeded 重新播种（与 economy reset 同思路）。
		tx, err := r.db.Pool.Begin(ctx)
		if err != nil {
			return State{}, err
		}
		for _, tbl := range []string{"kingdom_buildings", "kingdom_state"} {
			if _, err := tx.Exec(ctx, "DELETE FROM "+tbl+" WHERE account_id=$1", accountID); err != nil {
				tx.Rollback(ctx)
				return State{}, err
			}
		}
		if err := tx.Commit(ctx); err != nil {
			return State{}, err
		}
	}
	return r.mutate(ctx, accountID, cfg, econCfg, func(_ context.Context, _ pgx.Tx, s *txState) error {
		for res, amt := range ops.AddResources {
			s.resources[res] += amt
			s.stateDirty = true
		}
		if ops.FinishBuilds {
			for name, br := range s.rows {
				if br.UpgradeEndTs > s.now {
					br.Level++
					br.UpgradeEndTs = 0
					s.rows[name] = br
					s.dirty[name] = true
				}
			}
		}
		return nil
	})
}

// GMHandler serves POST /v5/kingdom/gm（JSON in / KingdomState proto out）。
type GMHandler struct {
	repo    *Repo
	cfg     *Config
	econCfg *economy.Config
}

func NewGMHandler(repo *Repo, cfg *Config, econCfg *economy.Config) *GMHandler {
	return &GMHandler{repo: repo, cfg: cfg, econCfg: econCfg}
}

func (h *GMHandler) Mount(mux *http.ServeMux, mw *auth.Middleware) {
	mux.HandleFunc("POST /v5/kingdom/gm", mw.Require(h.apply))
}

func (h *GMHandler) apply(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_KINGDOM_STATE_REQ)
		return
	}
	var ops GMOps
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16*1024)).Decode(&ops); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, "bad json body", pbcommon.MsgId_KINGDOM_STATE_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := h.repo.GMApply(ctx, accountID, ops, h.cfg, h.econCfg)
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_KINGDOM_STATE_REQ)
		return
	}
	log.Printf("kingdom GM account=%d ops=%+v ok", accountID, ops)
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}
