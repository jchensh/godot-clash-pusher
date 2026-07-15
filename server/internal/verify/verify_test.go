package verify

import (
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
)

// judge 交叉核对矩阵：重放 verdict × 客户端声称摘要。
func TestJudge(t *testing.T) {
	claimed := economy.PveSummary{DurationTicks: 978, DeployCount: 45, KingHpPermille: 154}
	pass := Verdict{Status: "pass", Win: true, Ticks: 978, KingHpPermille: 154}

	if s, _ := judge(pass, claimed); s != StatusPass {
		t.Fatalf("legit replay want PASS, got %d", s)
	}
	// 重放 hash 分叉（改内存/改指令/改养成缓存）→ MISMATCH。
	if s, _ := judge(Verdict{Status: "mismatch", Reason: "hash mismatch at tick 90"}, claimed); s != StatusMismatch {
		t.Fatal("hash mismatch want MISMATCH")
	}
	// 重放复算没赢（伪造指令流打不赢这关）→ MISMATCH。
	lose := pass
	lose.Win = false
	if s, _ := judge(lose, claimed); s != StatusMismatch {
		t.Fatal("replay-lose want MISMATCH")
	}
	// 哈希是真的但谎报时长（骗 time_under 星）→ MISMATCH。
	shortClaim := claimed
	shortClaim.DurationTicks = 500
	if s, note := judge(pass, shortClaim); s != StatusMismatch {
		t.Fatalf("ticks lie want MISMATCH, got %d (%s)", s, note)
	}
	// 谎报王塔血（骗 king_hp 星）→ MISMATCH。
	hpClaim := claimed
	hpClaim.KingHpPermille = 900
	if s, _ := judge(pass, hpClaim); s != StatusMismatch {
		t.Fatal("king hp lie want MISMATCH")
	}
	// 重放器基建错误 → ERROR（≠ 作弊，可重跑）。
	if s, _ := judge(Verdict{Status: "error", Reason: "config load failed"}, claimed); s != StatusError {
		t.Fatal("runner error want ERROR")
	}
}
