package economy

import (
	"testing"
)

// idlePending 纯函数测试（不需 PG）：累计/封顶/章节驱动/lastCollect<=0/未通关。
// 配置镜像真实 economy.json：gold_per_hour_per_chapter=50, cap_hours=8。
func cfg50x8() *Config {
	return &Config{
		Idle: Idle{GoldPerHourPerChapter: 50, CapHours: 8},
		Stages: map[string]Stage{
			"stage_1_2": {Chapter: 1},
			"stage_3_5": {Chapter: 3},
		},
	}
}

func TestIdlePending_Accumulation(t *testing.T) {
	cfg := cfg50x8()
	const base int64 = 1000000000 // 远大于测试用的 elapsed，避免 lastCollect 变负
	// 章节驱动：最高 chapter 3 → rate 150/h。累计 2 小时 → 300。
	got := idlePending(base, base-7200, "stage_3_5", cfg)
	if got != 300 {
		t.Fatalf("2h chapter3 = %d (want 300)", got)
	}
	// 章节更高产更多：chapter 3 → 150/h vs chapter 1 → 50/h。
	got1 := idlePending(base, base-3600, "stage_1_2", cfg)
	if got1 != 50 {
		t.Fatalf("1h chapter1 = %d (want 50)", got1)
	}
}

func TestIdlePending_Cap(t *testing.T) {
	cfg := cfg50x8()
	const base int64 = 1000000000
	// 封顶 cap_hours=8：即使离线 100h，按 8h 算 → chapter3 rate 150 × 8 = 1200。
	got := idlePending(base, base-3600*100, "stage_3_5", cfg)
	if got != 1200 {
		t.Fatalf("100h capped = %d (want 1200)", got)
	}
	// 刚好 cap 临界：8h → 1200。
	if g := idlePending(base, base-3600*8, "stage_3_5", cfg); g != 1200 {
		t.Fatalf("8h = %d (want 1200)", g)
	}
}

func TestIdlePending_EdgeCases(t *testing.T) {
	cfg := cfg50x8()
	const base int64 = 1000000000
	// lastCollect<=0 → 0（防御；播种已设 now）。
	if got := idlePending(base, 0, "stage_3_5", cfg); got != 0 {
		t.Fatalf("lastCollect=0 → %d (want 0)", got)
	}
	// 未通关（highest 空）→ chapter 0 → rate 0 → 0。
	if got := idlePending(base, base-3600, "", cfg); got != 0 {
		t.Fatalf("no progress → %d (want 0)", got)
	}
	// now < lastCollect（时钟倒退）→ elapsed 钳 0 → 0。
	if got := idlePending(base-3600, base, "stage_3_5", cfg); got != 0 {
		t.Fatalf("time reversed → %d (want 0)", got)
	}
	// 未知 highest stage → chapter 0 → 0。
	if got := idlePending(base, base-3600, "nope", cfg); got != 0 {
		t.Fatalf("unknown stage → %d (want 0)", got)
	}
}
