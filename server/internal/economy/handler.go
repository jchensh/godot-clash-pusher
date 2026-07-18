package economy

import (
	"context"
	"errors"
	"fmt"
	"log"
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
	// TowerBonus（K4，DESIGN_KINGDOM）：开战时查王国城防 → 我方塔 (hp_pct, dmg_pct)。
	// 由 main.go 注入 kingdom 实现（避免 economy↔kingdom 循环依赖）；nil = 无加成（0,0）。
	TowerBonus func(ctx context.Context, accountID int64) (int, int, error)
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
	mux.HandleFunc("POST /v5/economy/collect-idle", mw.Require(h.collectIdle))
	// KAN-78/79 PVE 防作弊：开战报到 + 战斗中指令流/哈希批量上报。
	mux.HandleFunc("POST /v5/pve/start", mw.Require(h.pveStart))
	mux.HandleFunc("POST /v5/pve/report", mw.Require(h.pveReport))
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
	h.action(w, r, "upgrade", h.repo.Upgrade, pbcommon.MsgId_ECONOMY_UPGRADE_REQ)
}
func (h *Handler) rankUp(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, "rank_up", h.repo.RankUp, pbcommon.MsgId_ECONOMY_RANK_UP_REQ)
}
func (h *Handler) unlock(w http.ResponseWriter, r *http.Request) {
	h.action(w, r, "unlock", h.repo.Unlock, pbcommon.MsgId_ECONOMY_UNLOCK_REQ)
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
	sum := PveSummary{}
	if s := req.GetSummary(); s != nil {
		sum = PveSummary{
			DurationTicks:  int(s.GetDurationTicks()),
			DeployCount:    int(s.GetDeployCount()),
			KingHpPermille: int(s.GetKingHpPermille()),
		}
	}
	st, err := h.repo.StageClear(ctx, accountID, req.GetStageId(), int(req.GetStars()), req.GetBattleId(), sum, h.cfg)
	if err != nil {
		code, status := mapErr(err)
		log.Printf("economy: acct=%d stage_clear stage=%q stars=%d battle=%d rejected: %v", accountID, req.GetStageId(), req.GetStars(), req.GetBattleId(), err)
		httpx.WriteError(w, status, code, err.Error(), pbcommon.MsgId_ECONOMY_STAGE_CLEAR_REQ)
		return
	}
	log.Printf("economy: acct=%d stage_clear stage=%q stars=%d battle=%d ok -> gold=%d highest=%q", accountID, req.GetStageId(), req.GetStars(), req.GetBattleId(), st.Gold, st.HighestCleared)
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

// pveStart (KAN-78)：开战报到。服务器时钟记 started_at + 从 economy_cards 读 deck 的
// level/rank 权威快照 → 回 battle_id。校验：关存在/线性解锁/卡组 8 张全 unlocked。
func (h *Handler) pveStart(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_PVE_START_REQ)
		return
	}
	var req pbeconomy.PveStartReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_PVE_START_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	hpPct, dmgPct := 0, 0
	if h.TowerBonus != nil {
		var tbErr error
		hpPct, dmgPct, tbErr = h.TowerBonus(ctx, accountID)
		if tbErr != nil {
			// 城防查询失败按 0 加成放行（不阻断开战），但记日志观察。
			log.Printf("economy: acct=%d pve_start tower bonus lookup failed: %v", accountID, tbErr)
			hpPct, dmgPct = 0, 0
		}
	}
	battleID, err := h.repo.PveStart(ctx, accountID, req.GetStageId(), req.GetDeck(), h.cfg, hpPct, dmgPct)
	if err != nil {
		code, status := mapErr(err)
		log.Printf("economy: acct=%d pve_start stage=%q rejected: %v", accountID, req.GetStageId(), err)
		httpx.WriteError(w, status, code, err.Error(), pbcommon.MsgId_PVE_START_REQ)
		return
	}
	log.Printf("economy: acct=%d pve_start stage=%q -> battle=%d towers=+%d%%hp/+%d%%dmg",
		accountID, req.GetStageId(), battleID, hpPct, dmgPct)
	httpx.WriteProto(w, http.StatusOK, &pbeconomy.PveStartResp{
		BattleId: battleID, TowerHpPct: int32(hpPct), TowerDmgPct: int32(dmgPct)})
}

// pveReport (KAN-79)：战斗中周期批量追加指令流/哈希。服务器按到达时间记批次（时序真实性）。
func (h *Handler) pveReport(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_PVE_REPORT_REQ)
		return
	}
	var req pbeconomy.PveReportReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_PVE_REPORT_REQ)
		return
	}
	cmds := make([]PveCmd, 0, len(req.GetCmds()))
	for _, c := range req.GetCmds() {
		cmds = append(cmds, PveCmd{
			Tick: int(c.GetTick()), Phase: int(c.GetPhase()), Side: int(c.GetSide()),
			Card: c.GetCardId(), X: int(c.GetXMilli()), Y: int(c.GetYMilli()),
		})
	}
	hashes := make([]PveHashRec, 0, len(req.GetHashes()))
	for _, hr := range req.GetHashes() {
		hashes = append(hashes, PveHashRec{Tick: int(hr.GetTick()), Hash: fmt.Sprintf("%x", hr.GetHash())})
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	if err := h.repo.PveReport(ctx, accountID, req.GetBattleId(), cmds, hashes, h.cfg); err != nil {
		code, status := mapErr(err)
		log.Printf("economy: acct=%d pve_report battle=%d rejected: %v", accountID, req.GetBattleId(), err)
		httpx.WriteError(w, status, code, err.Error(), pbcommon.MsgId_PVE_REPORT_REQ)
		return
	}
	httpx.WriteProto(w, http.StatusOK, &pbeconomy.PveReportResp{Ok: true})
}

// collectIdle (V5-N6)：挂机领取。无业务入参（CollectIdleReq 空），now 全服务器定
// （改本地时钟无效）。服务器按 (now − last_collect) 算累计金币 → 发到 gold + 刷新基准。
func (h *Handler) collectIdle(w http.ResponseWriter, r *http.Request) {
	accountID, ok := auth.AccountIDFromContext(r.Context())
	if !ok {
		httpx.WriteError(w, http.StatusUnauthorized, pbcommon.ErrorCode_ERR_UNAUTHORIZED, "no account in context", pbcommon.MsgId_ECONOMY_COLLECT_IDLE_REQ)
		return
	}
	var req pbeconomy.CollectIdleReq
	if err := httpx.ReadProto(r, &req); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, pbcommon.ErrorCode_ERR_INVALID_ARG, err.Error(), pbcommon.MsgId_ECONOMY_COLLECT_IDLE_REQ)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	st, err := h.repo.CollectIdle(ctx, accountID, h.cfg)
	if err != nil {
		code, status := mapErr(err)
		log.Printf("economy: acct=%d collect_idle rejected: %v", accountID, err)
		httpx.WriteError(w, status, code, err.Error(), pbcommon.MsgId_ECONOMY_COLLECT_IDLE_REQ)
		return
	}
	log.Printf("economy: acct=%d collect_idle ok -> gold=%d", accountID, st.Gold)
	httpx.WriteProto(w, http.StatusOK, toProto(st))
}

type actionFn func(context.Context, int64, string, *Config) (State, error)

func (h *Handler) action(w http.ResponseWriter, r *http.Request, name string, fn actionFn, reqMsg pbcommon.MsgId) {
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
		log.Printf("economy: acct=%d %s card=%q rejected: %v", accountID, name, req.GetCardId(), err)
		httpx.WriteError(w, status, code, err.Error(), reqMsg)
		return
	}
	log.Printf("economy: acct=%d %s card=%q ok -> gold=%d", accountID, name, req.GetCardId(), st.Gold)
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
	case errors.Is(err, ErrPveBattleInvalid):
		return pbcommon.ErrorCode_ERR_PVE_BATTLE_INVALID, http.StatusConflict
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
