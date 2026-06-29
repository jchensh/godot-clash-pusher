package economy

// GM / 开发作弊工具（V5）：直接改本账号的服务器经济数据库（加货币/碎片、解锁、满养成、
// 推进关卡进度、重置）。**仅开发用**——服务器侧由 GM_ENABLED 环境变量门控（默认关，prod 不开）；
// 仍走会话鉴权（mw.Require），只能改"自己账号"，无法影响他人。请求 JSON、响应复用 EconomyState proto。

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
)

// GMOps 是一次 GM 应用的全部操作（JSON 请求体；缺省字段=不操作）。
type GMOps struct {
	AddGold             int            `json:"add_gold"`
	AddGems             int            `json:"add_gems"`
	AddShardsAll        int            `json:"add_shards_all"`        // 给每张卡都加 N 碎片
	AddShards           map[string]int `json:"add_shards"`            // 指定卡加碎片
	UnlockAll           bool           `json:"unlock_all"`            // 解锁全部卡
	MaxAllCards         bool           `json:"max_all_cards"`         // 全卡满级满阶 + 解锁
	ClearThroughChapter int            `json:"clear_through_chapter"` // 通关到第 N 章（含）：该范围内全部 stage 标 cleared+满星
	Reset               bool           `json:"reset"`                 // 重置账号经济（清空 → 重新播种新档）
}

// GMApply 在一个事务里应用全部 GM 操作，返回新状态。镜像不走正常校验（作弊）。
func (r *Repo) GMApply(ctx context.Context, accountID int64, ops GMOps, cfg *Config) (State, error) {
	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return State{}, err
	}
	defer tx.Rollback(ctx)

	// reset：先清空本账号经济三表，再走正常播种（fresh 新档）。
	if ops.Reset {
		for _, tbl := range []string{"economy_stages", "economy_cards", "economy_state"} {
			if _, err := tx.Exec(ctx, "DELETE FROM "+tbl+" WHERE account_id=$1", accountID); err != nil {
				return State{}, err
			}
		}
	}
	if err := ensureSeeded(ctx, tx, accountID, cfg); err != nil {
		return State{}, err
	}

	// 钱包：加金币/宝石。
	if ops.AddGold != 0 || ops.AddGems != 0 {
		if _, err := tx.Exec(ctx,
			`UPDATE economy_state SET gold=gold+$2, gems=gems+$3, updated_at=NOW() WHERE account_id=$1`,
			accountID, ops.AddGold, ops.AddGems); err != nil {
			return State{}, err
		}
	}

	// 碎片：全卡加。
	if ops.AddShardsAll != 0 {
		if _, err := tx.Exec(ctx,
			`UPDATE economy_cards SET shards=GREATEST(0, shards+$2) WHERE account_id=$1`,
			accountID, ops.AddShardsAll); err != nil {
			return State{}, err
		}
	}
	// 碎片：指定卡加。
	for cid, n := range ops.AddShards {
		if n == 0 {
			continue
		}
		if _, err := tx.Exec(ctx,
			`UPDATE economy_cards SET shards=GREATEST(0, shards+$3) WHERE account_id=$1 AND card_id=$2`,
			accountID, cid, n); err != nil {
			return State{}, err
		}
	}

	// 满养成：全卡满级满阶（顺带解锁，否则满阶卡不可用）。
	if ops.MaxAllCards {
		maxRank := cfg.MaxRank()
		maxLevel := cfg.LevelCap(maxRank)
		if _, err := tx.Exec(ctx,
			`UPDATE economy_cards SET level=$2, rank=$3, unlocked=TRUE WHERE account_id=$1`,
			accountID, maxLevel, maxRank); err != nil {
			return State{}, err
		}
	}

	// 解锁全部卡。
	if ops.UnlockAll {
		if _, err := tx.Exec(ctx,
			`UPDATE economy_cards SET unlocked=TRUE WHERE account_id=$1`, accountID); err != nil {
			return State{}, err
		}
	}

	// 关卡进度：通关到第 N 章（含）——该范围内每个 stage 标 cleared + 满星，再刷 highest_cleared。
	if ops.ClearThroughChapter > 0 {
		for _, sid := range cfg.OrderedStageIDs() {
			st, ok := cfg.Stage(sid)
			if !ok || st.Chapter > ops.ClearThroughChapter {
				continue
			}
			if _, err := tx.Exec(ctx,
				`INSERT INTO economy_stages (account_id, stage_id, stars, cleared) VALUES ($1,$2,$3,TRUE)
				 ON CONFLICT (account_id, stage_id) DO UPDATE SET stars=GREATEST(economy_stages.stars, EXCLUDED.stars), cleared=TRUE`,
				accountID, sid, cfg.StarCap(sid)); err != nil {
				return State{}, err
			}
		}
		highest, err := computeHighestCleared(ctx, tx, accountID, cfg)
		if err != nil {
			return State{}, err
		}
		if _, err := tx.Exec(ctx,
			`UPDATE economy_state SET highest_cleared=$2, updated_at=NOW() WHERE account_id=$1`,
			accountID, highest); err != nil {
			return State{}, err
		}
	}

	st, err := readState(ctx, tx, accountID)
	if err != nil {
		return State{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return State{}, err
	}
	return st, nil
}

// GMHandler 暴露 /v5/gm/*（仅 GM_ENABLED 时由 api main 挂载）。
type GMHandler struct {
	repo *Repo
	cfg  *Config
}

func NewGMHandler(repo *Repo, cfg *Config) *GMHandler {
	return &GMHandler{repo: repo, cfg: cfg}
}

func (h *GMHandler) Mount(mux *http.ServeMux, mw *auth.Middleware) {
	mux.HandleFunc("POST /v5/gm/apply", mw.Require(h.apply))
}

// apply：读 JSON 操作 → GMApply → 返回新 EconomyState（proto，复用客户端解码）。
func (h *GMHandler) apply(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_MSG_UNKNOWN)
		return
	}
	var ops GMOps
	if err := json.NewDecoder(r.Body).Decode(&ops); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_MSG_UNKNOWN)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := h.repo.GMApply(ctx, accountID, ops, h.cfg)
	if err != nil {
		log.Printf("GM: acct=%d apply rejected: %v", accountID, err)
		httpx.WriteError(w, http.StatusInternalServerError, pbcommon.ErrorCode_ERR_INTERNAL, err.Error(), pbcommon.MsgId_MSG_UNKNOWN)
		return
	}
	log.Printf("GM: acct=%d apply %+v -> gold=%d gems=%d highest=%q", accountID, ops, st.Gold, st.Gems, st.HighestCleared)
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}
