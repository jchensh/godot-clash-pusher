// Package verify implements the KAN-79 PVE replay verification worker:
// pull one consumed-but-unverified battle from pve_battles, replay its command
// stream in a headless Godot child process (the same deterministic logic/ the
// clients run), and cross-check the recorded hashes + claimed summary against
// the replay. Any divergence = the client's claims cannot be reproduced from
// its own evidence → verdict "mismatch" + shadow-flag the account.
//
// 乐观结算：StageClear 已发奖，这里事后验；玩法验证期 mismatch 只标记
// （accounts.ban_status=1）不回滚。多实例安全（FOR UPDATE SKIP LOCKED）。
package verify

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

// verify_status 值（与 migration 0008 注释一致）。
const (
	StatusPending  int16 = 0
	StatusPass     int16 = 1
	StatusMismatch int16 = 2
	StatusError    int16 = 3
	StatusSkipped  int16 = 4
)

// Verdict is tools/pve_verify.gd's output JSON.
type Verdict struct {
	Status         string `json:"status"` // pass | mismatch | error
	Reason         string `json:"reason"`
	MismatchTick   int    `json:"mismatch_tick"`
	Win            bool   `json:"win"`
	Ticks          int    `json:"ticks"`
	KingHpPermille int    `json:"king_hp_permille"`
}

// Runner replays one battle (input = pve_verify.gd's input JSON) and returns
// the verdict. Injected so tests can fake it; production uses GodotRunner.
type Runner func(ctx context.Context, inputJSON []byte) (Verdict, error)

// Worker polls pve_battles and verifies one battle at a time.
type Worker struct {
	db         *store.DB
	run        Runner
	sampleRate float64
	randf      func() float64 // 抽样随机源（可注入；生产 rand.Float64）
}

func NewWorker(db *store.DB, run Runner, sampleRate float64, randf func() float64) *Worker {
	return &Worker{db: db, run: run, sampleRate: sampleRate, randf: randf}
}

// VerifyOne picks one pending battle (consumed, unverified), samples it, and
// verifies. Returns (false, nil) when the queue is empty.
func (w *Worker) VerifyOne(ctx context.Context) (bool, error) {
	tx, err := w.db.Pool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx)

	var (
		id, accountID                int64
		stageID                      string
		deck, progress, cmds, hashes []byte
		claimedStars                 *int
		claimedSummary               []byte
	)
	err = tx.QueryRow(ctx, `
		SELECT id, account_id, stage_id, deck, progress, cmds, hashes, claimed_stars, claimed_summary
		  FROM pve_battles
		 WHERE consumed_at IS NOT NULL AND verify_status = 0
		 ORDER BY id
		 LIMIT 1
		 FOR UPDATE SKIP LOCKED`).
		Scan(&id, &accountID, &stageID, &deck, &progress, &cmds, &hashes, &claimedStars, &claimedSummary)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	// 抽样：跳过的局标 skipped（留痕，与「还没轮到」区分）。
	if w.sampleRate < 1.0 && w.randf() >= w.sampleRate {
		if _, err := tx.Exec(ctx,
			`UPDATE pve_battles SET verify_status=$2, verified_at=NOW() WHERE id=$1`, id, StatusSkipped); err != nil {
			return false, err
		}
		return true, tx.Commit(ctx)
	}

	input, err := json.Marshal(map[string]json.RawMessage{
		"stage_id": json.RawMessage(fmt.Sprintf("%q", stageID)),
		"deck":     json.RawMessage(deck),
		"progress": json.RawMessage(progress),
		"cmds":     json.RawMessage(cmds),
		"hashes":   json.RawMessage(hashes),
	})
	if err != nil {
		return false, err
	}

	status, note := StatusError, ""
	verdict, runErr := w.run(ctx, input)
	if runErr != nil {
		note = fmt.Sprintf("runner: %v", runErr) // 基建故障 ≠ 作弊；标 error 供重跑/排查
	} else {
		var claimed economy.PveSummary
		_ = json.Unmarshal(claimedSummary, &claimed)
		status, note = judge(verdict, claimed)
	}

	if _, err := tx.Exec(ctx,
		`UPDATE pve_battles SET verify_status=$2, verify_note=$3, verified_at=NOW() WHERE id=$1`,
		id, status, note); err != nil {
		return false, err
	}
	if status == StatusMismatch {
		// shadow 标记：只记不罚（玩法验证期）；风控/处置后续阶段接。
		if _, err := tx.Exec(ctx,
			`UPDATE accounts SET ban_status = GREATEST(ban_status, 1) WHERE id=$1`, accountID); err != nil {
			return false, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return false, err
	}
	fmt.Printf("verify: battle=%d acc=%d stage=%s -> %s %s\n", id, accountID, stageID, statusName(status), note)
	return true, nil
}

// judge cross-checks the replay verdict against the client's consumed claims.
// 哈希全等只证明「指令流真的产生这些状态」；还要核对声称的摘要与重放复算值一致
// （抓「哈希是真的、但摘要谎报时长/王塔血骗星级」）。同源计算 → 必须精确相等。
func judge(v Verdict, claimed economy.PveSummary) (int16, string) {
	switch v.Status {
	case "error":
		return StatusError, v.Reason
	case "mismatch":
		return StatusMismatch, v.Reason
	case "pass":
	default:
		return StatusError, "unknown verdict status " + v.Status
	}
	if !v.Win {
		return StatusMismatch, "replay says player did not win"
	}
	if v.Ticks != claimed.DurationTicks {
		return StatusMismatch, fmt.Sprintf("duration ticks: replay=%d claimed=%d", v.Ticks, claimed.DurationTicks)
	}
	if v.KingHpPermille != claimed.KingHpPermille {
		return StatusMismatch, fmt.Sprintf("king hp permille: replay=%d claimed=%d", v.KingHpPermille, claimed.KingHpPermille)
	}
	return StatusPass, ""
}

func statusName(s int16) string {
	switch s {
	case StatusPass:
		return "PASS"
	case StatusMismatch:
		return "MISMATCH"
	case StatusError:
		return "ERROR"
	case StatusSkipped:
		return "SKIPPED"
	}
	return "PENDING"
}

// GodotRunner returns a Runner that replays via a headless Godot child process
// running tools/pve_verify.gd inside projectDir.
func GodotRunner(godotBin, projectDir string) Runner {
	return func(ctx context.Context, inputJSON []byte) (Verdict, error) {
		dir, err := os.MkdirTemp("", "pve-verify-*")
		if err != nil {
			return Verdict{}, err
		}
		defer os.RemoveAll(dir)
		inPath := filepath.Join(dir, "in.json")
		outPath := filepath.Join(dir, "out.json")
		if err := os.WriteFile(inPath, inputJSON, 0o600); err != nil {
			return Verdict{}, err
		}
		runCtx, cancel := context.WithTimeout(ctx, 120*time.Second)
		defer cancel()
		cmd := exec.CommandContext(runCtx, godotBin,
			"--headless", "--path", projectDir,
			"-s", "res://tools/pve_verify.gd", "--",
			"--input="+inPath, "--output="+outPath)
		out, err := cmd.CombinedOutput()
		if err != nil {
			return Verdict{}, fmt.Errorf("godot replay failed: %w (output: %.500s)", err, string(out))
		}
		raw, err := os.ReadFile(outPath)
		if err != nil {
			return Verdict{}, fmt.Errorf("verdict file missing: %w (output: %.500s)", err, string(out))
		}
		var v Verdict
		if err := json.Unmarshal(raw, &v); err != nil {
			return Verdict{}, fmt.Errorf("verdict parse: %w", err)
		}
		return v, nil
	}
}
