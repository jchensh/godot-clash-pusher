package economy

// KAN-78/79 PVE 防作弊：战斗会话（开战报到 → 指令流/哈希批量追加 → StageClear 消费校验）。
// 原则：服务器时钟是唯一时间权威（started_at / 批次到达时间），客户端声称的一切
// （stars/摘要/指令流）只作为「待校验的主张」，与服务器记录交叉核对。

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/jackc/pgx/v5"
)

// ErrPveBattleInvalid → ERR_PVE_BATTLE_INVALID(504)。所有 PVE 会话类拒绝共用一个错误码，
// 细分原因进日志/wrap 信息（给开发看，不给作弊者精确探针）。
var ErrPveBattleInvalid = errors.New("pve battle invalid")

// PveCmd / PveHashRec / PveSummary 是 pve_battles JSONB 列的内部形状（与 proto 对应，
// 字段名刻意压短——指令流一局几十~几百条）。
type PveCmd struct {
	Tick  int    `json:"t"`
	Phase int    `json:"ph"` // 0=gap（tick 间隙，玩家）/ 1=in（tick 内，AI）
	Side  int    `json:"s"`  // 1=player / 2=opponent(AI)
	Card  string `json:"c"`
	X     int    `json:"x"` // tile × 1000
	Y     int    `json:"y"`
}

type PveHashRec struct {
	Tick int    `json:"t"`
	Hash string `json:"h"` // sha256 hex
}

type PveSummary struct {
	DurationTicks  int `json:"duration_ticks"`
	DeployCount    int `json:"deploy_count"`
	KingHpPermille int `json:"king_hp_permille"`
}

// PveStart 开战报到：校验关卡存在 + 线性解锁（防跳关开局）+ 卡组 8 张全 unlocked
// （堵未解锁卡进战斗），从 economy_cards 读 level/rank 权威快照存档（层2 重放用——
// 客户端改本地缓存的养成 → 与快照重放的 hash 对不上 → 现形），回 battle_id。
// K4：towerHpPct/towerDmgPct 由 handler 从王国城防查得，写进 progress JSON 的
// "_towers" 保留键（复用现有列零 migration）→ 验证器 progress 透传 → pve_replay 同源注入。
func (r *Repo) PveStart(ctx context.Context, accountID int64, stageID string, deck []string, cfg *Config, towerHpPct, towerDmgPct int) (int64, error) {
	if _, ok := cfg.Stage(stageID); !ok {
		return 0, ErrUnknownStage
	}
	if len(deck) != 8 {
		return 0, fmt.Errorf("%w: deck must have 8 cards, got %d", ErrPveBattleInvalid, len(deck))
	}
	seen := map[string]bool{}
	for _, c := range deck {
		if seen[c] {
			return 0, fmt.Errorf("%w: duplicate card %s in deck", ErrPveBattleInvalid, c)
		}
		seen[c] = true
	}
	// 线性解锁：与 StageClear 同口径（第一关恒可，其余要求前一关 cleared）。
	if prev, hasPrev := cfg.PrevStage(stageID); hasPrev {
		cleared, err := r.isStageCleared(ctx, accountID, prev)
		if err != nil {
			return 0, err
		}
		if !cleared {
			return 0, ErrStageLocked
		}
	}

	tx, err := r.db.Pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)
	if err := ensureSeeded(ctx, tx, accountID, cfg); err != nil {
		return 0, err
	}

	// 卡组 8 张全部必须有行且 unlocked；顺带读 level/rank 组权威快照。
	rows, err := tx.Query(ctx,
		`SELECT card_id, level, rank, unlocked FROM economy_cards WHERE account_id=$1 AND card_id=ANY($2)`,
		accountID, deck)
	if err != nil {
		return 0, err
	}
	type lr struct{ Level, Rank int }
	progress := map[string]lr{}
	for rows.Next() {
		var cid string
		var lv, rk int
		var unlocked bool
		if err := rows.Scan(&cid, &lv, &rk, &unlocked); err != nil {
			rows.Close()
			return 0, err
		}
		if !unlocked {
			rows.Close()
			return 0, fmt.Errorf("%w: card %s locked", ErrPveBattleInvalid, cid)
		}
		progress[cid] = lr{Level: lv, Rank: rk}
	}
	rows.Close()
	for _, c := range deck {
		if _, ok := progress[c]; !ok {
			return 0, fmt.Errorf("%w: card %s unknown", ErrPveBattleInvalid, c)
		}
	}

	deckJSON, _ := json.Marshal(deck)
	progAny := map[string]any{}
	for cid, v := range progress {
		progAny[cid] = v
	}
	if towerHpPct > 0 || towerDmgPct > 0 {
		progAny["_towers"] = map[string]int{"hp_pct": towerHpPct, "dmg_pct": towerDmgPct}
	}
	progJSON, _ := json.Marshal(progAny)
	var battleID int64
	if err := tx.QueryRow(ctx,
		`INSERT INTO pve_battles (account_id, stage_id, deck, progress) VALUES ($1,$2,$3,$4) RETURNING id`,
		accountID, stageID, deckJSON, progJSON).Scan(&battleID); err != nil {
		return 0, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return battleID, nil
}

// PveReport 追加一批指令/哈希到会话（战斗中周期上报）。服务器按到达时间记批次
// （last_report_at）——时序真实性：想上报完整一局就必须让墙钟真实流逝。
// 拒绝：battle 不存在/不属己/已消费/指令流超上限（单条 UPDATE 的 WHERE 承担全部校验）。
func (r *Repo) PveReport(ctx context.Context, accountID, battleID int64, cmds []PveCmd, hashes []PveHashRec, cfg *Config) error {
	if len(cmds) == 0 && len(hashes) == 0 {
		return nil // 空批次 no-op（客户端周期心跳型 flush）
	}
	cmdsJSON, _ := json.Marshal(cmds)
	hashesJSON, _ := json.Marshal(hashes)
	tag, err := r.db.Pool.Exec(ctx,
		`UPDATE pve_battles
		    SET cmds = cmds || $3::jsonb, hashes = hashes || $4::jsonb,
		        report_count = report_count + 1, last_report_at = NOW()
		  WHERE id=$1 AND account_id=$2 AND consumed_at IS NULL
		    AND jsonb_array_length(cmds) + $5 <= $6`,
		battleID, accountID, cmdsJSON, hashesJSON, len(cmds), cfg.Anticheat.MaxCmdsPerBattle)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("%w: report rejected (missing/consumed/over cap)", ErrPveBattleInvalid)
	}
	return nil
}

// consumePveBattle 在 StageClear 事务内校验并消费战斗会话（KAN-78 层1 核心）：
//  1. battle 存在、属己、关匹配；相同 claim 的已消费 battle 幂等返回，变造重放拒绝
//  2. 墙钟 elapsed ≥ MinStageDurationS（堵秒推——想通关必须真实等待时间流逝）
//  3. 声称战斗时长（ticks/10）≤ 墙钟 elapsed×1.15+5（无法时间压缩；客户端暂停使墙钟
//     偏长是允许的，反向压缩不允许）
//  4. 服务器实收指令流里玩家(side=1)出过牌（赢不可能零出兵；用服务器记录而非客户端声称）
//  5. 声称星数与摘要自洽（king_hp_pct / time_under 逐星核对）
//
// 全过 → 标记 consumed_at + 存 claimed_stars/summary（层2 verifier 事后重放复核）。
// 返回 alreadyConsumed=true 表示相同 claim 的安全重试；调用方只回当前状态，绝不再次发奖。
func consumePveBattle(ctx context.Context, tx pgx.Tx, accountID, battleID int64, stageID string, stars int, sum PveSummary, stage Stage, cfg *Config, now time.Time) (bool, error) {
	if battleID <= 0 {
		return false, fmt.Errorf("%w: missing battle_id", ErrPveBattleInvalid)
	}
	var dbStage string
	var startedAt time.Time
	var consumedAt *time.Time
	var claimedStars *int
	var claimedSummary []byte
	var playerCmds int
	if err := tx.QueryRow(ctx,
		`SELECT stage_id, started_at, consumed_at, claimed_stars, claimed_summary,
		        (SELECT count(*) FROM jsonb_array_elements(cmds) e WHERE (e->>'s')::int = 1)
		   FROM pve_battles WHERE id=$1 AND account_id=$2 FOR UPDATE`,
		battleID, accountID).Scan(&dbStage, &startedAt, &consumedAt, &claimedStars, &claimedSummary, &playerCmds); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, fmt.Errorf("%w: battle not found", ErrPveBattleInvalid)
		}
		return false, err
	}
	if dbStage != stageID {
		return false, fmt.Errorf("%w: stage mismatch (battle=%s, claim=%s)", ErrPveBattleInvalid, dbStage, stageID)
	}
	if consumedAt != nil {
		var previous PveSummary
		if claimedStars == nil || *claimedStars != stars || json.Unmarshal(claimedSummary, &previous) != nil || previous != sum {
			return false, fmt.Errorf("%w: consumed battle claim mismatch", ErrPveBattleInvalid)
		}
		return true, nil
	}
	if err := validatePveClaim(now.Sub(startedAt).Seconds(), stars, sum, stage, cfg, playerCmds); err != nil {
		return false, err
	}
	sumJSON, _ := json.Marshal(sum)
	if _, err := tx.Exec(ctx,
		`UPDATE pve_battles SET consumed_at=$3, claimed_stars=$4, claimed_summary=$5 WHERE id=$1 AND account_id=$2`,
		battleID, accountID, now, stars, sumJSON); err != nil {
		return false, err
	}
	return false, nil
}

// validatePveClaim 是层1 的纯校验矩阵（无 DB，可单测）：
// elapsedS = 服务器墙钟经过秒数；playerCmds = 服务器实收指令流里 side=1 的条数。
func validatePveClaim(elapsedS float64, stars int, sum PveSummary, stage Stage, cfg *Config, playerCmds int) error {
	if elapsedS < float64(cfg.Anticheat.MinStageDurationS) {
		return fmt.Errorf("%w: too fast (%.1fs < min %ds)", ErrPveBattleInvalid, elapsedS, cfg.Anticheat.MinStageDurationS)
	}
	claimedSec := float64(sum.DurationTicks) / 10.0
	if claimedSec > elapsedS*1.15+5.0 {
		return fmt.Errorf("%w: claimed duration %.1fs exceeds wall clock %.1fs", ErrPveBattleInvalid, claimedSec, elapsedS)
	}
	if playerCmds < 1 {
		return fmt.Errorf("%w: no player deploys recorded server-side", ErrPveBattleInvalid)
	}
	// 星数 vs 摘要逐星核对（stars ≤ starCap 已由 caller 先验）。
	for i := 0; i < stars && i < len(stage.Stars); i++ {
		g := stage.Stars[i]
		switch g.Goal {
		case "win": // stars≥1 即声称 win，无附加数值
		case "king_hp_pct":
			if sum.KingHpPermille < int(math.Round(g.Min*1000)) {
				return fmt.Errorf("%w: star %d needs king_hp>=%.0f%%, summary says %.1f%%",
					ErrPveBattleInvalid, i+1, g.Min*100, float64(sum.KingHpPermille)/10.0)
			}
		case "time_under":
			if claimedSec > g.Sec {
				return fmt.Errorf("%w: star %d needs time<=%.0fs, summary says %.1fs",
					ErrPveBattleInvalid, i+1, g.Sec, claimedSec)
			}
		}
	}
	return nil
}
