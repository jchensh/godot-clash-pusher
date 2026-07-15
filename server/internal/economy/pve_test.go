package economy

// KAN-78 层1 纯校验矩阵单测（无 DB）：validatePveClaim 的限速/时长一致/实收出兵/
// 星数摘要自洽逐条验证。DB 相关（会话建立/消费/重放拒）走 integration。

import (
	"errors"
	"testing"
)

func acCfg() *Config {
	return &Config{Anticheat: Anticheat{MinStageDurationS: 15, MaxCmdsPerBattle: 2000, VerifySampleRate: 1.0}}
}

// 典型三星配置：win / 王塔≥50% / 120 秒内。
func acStage() Stage {
	return Stage{
		Stars:   []StarGoal{{Goal: "win"}, {Goal: "king_hp_pct", Min: 0.5}, {Goal: "time_under", Sec: 120}},
		starCap: 3,
	}
}

func TestValidatePveClaim_LegitPasses(t *testing.T) {
	sum := PveSummary{DurationTicks: 600, DeployCount: 5, KingHpPermille: 800} // 60s 局、王塔 80%
	if err := validatePveClaim(65.0, 3, sum, acStage(), acCfg(), 5); err != nil {
		t.Fatalf("legit claim rejected: %v", err)
	}
}

func TestValidatePveClaim_TooFastRejected(t *testing.T) {
	// 墙钟 5s < 下限 15s —— 秒推被拒。
	sum := PveSummary{DurationTicks: 40, DeployCount: 1, KingHpPermille: 1000}
	if err := validatePveClaim(5.0, 1, sum, acStage(), acCfg(), 1); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("want ErrPveBattleInvalid (too fast), got %v", err)
	}
}

func TestValidatePveClaim_TimeCompressionRejected(t *testing.T) {
	// 声称打了 300s（3000 ticks），墙钟只过了 20s —— 时间压缩被拒。
	sum := PveSummary{DurationTicks: 3000, DeployCount: 5, KingHpPermille: 1000}
	if err := validatePveClaim(20.0, 1, sum, acStage(), acCfg(), 5); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("want ErrPveBattleInvalid (compression), got %v", err)
	}
}

func TestValidatePveClaim_WallClockLongerIsFine(t *testing.T) {
	// 反向不限制：墙钟远超声称时长（中途暂停/挂后台）是允许的。
	sum := PveSummary{DurationTicks: 300, DeployCount: 2, KingHpPermille: 1000} // 30s 局
	if err := validatePveClaim(3600.0, 1, sum, acStage(), acCfg(), 2); err != nil {
		t.Fatalf("long wall clock should pass: %v", err)
	}
}

func TestValidatePveClaim_NoServerDeploysRejected(t *testing.T) {
	// 服务器实收指令流里玩家没出过牌（playerCmds=0）——赢不可能零出兵。
	sum := PveSummary{DurationTicks: 600, DeployCount: 5, KingHpPermille: 1000}
	if err := validatePveClaim(65.0, 1, sum, acStage(), acCfg(), 0); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("want ErrPveBattleInvalid (no deploys), got %v", err)
	}
}

func TestValidatePveClaim_StarVsSummaryCrossCheck(t *testing.T) {
	cfg, stage := acCfg(), acStage()
	// 声称 2 星（王塔≥50%）但摘要王塔只剩 30% → 拒。
	bad := PveSummary{DurationTicks: 600, DeployCount: 3, KingHpPermille: 300}
	if err := validatePveClaim(65.0, 2, bad, stage, cfg, 3); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("want ErrPveBattleInvalid (king hp), got %v", err)
	}
	// 只声称 1 星 → 不检查 2 星条件 → 过。
	if err := validatePveClaim(65.0, 1, bad, stage, cfg, 3); err != nil {
		t.Fatalf("1 star with low king hp should pass: %v", err)
	}
	// 恰好在边界（500 permille = 50%）→ 过。
	edge := PveSummary{DurationTicks: 600, DeployCount: 3, KingHpPermille: 500}
	if err := validatePveClaim(65.0, 2, edge, stage, cfg, 3); err != nil {
		t.Fatalf("edge king hp should pass: %v", err)
	}
	// 声称 3 星（≤120s）但打了 121s（1210 ticks）→ 拒。
	slow := PveSummary{DurationTicks: 1210, DeployCount: 3, KingHpPermille: 800}
	if err := validatePveClaim(130.0, 3, slow, stage, cfg, 3); !errors.Is(err, ErrPveBattleInvalid) {
		t.Fatalf("want ErrPveBattleInvalid (time_under), got %v", err)
	}
}
