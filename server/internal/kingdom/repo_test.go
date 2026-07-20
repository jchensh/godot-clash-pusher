package kingdom

import "testing"

// 纯函数单测（无 DB）：产出结算 / 加速定价 / 仓库封顶。全整数运算，服务器时钟语义。

func testCfg() *Config {
	cfg := &Config{
		Resources: []string{"food", "wood"},
		Buildings: map[string]Building{
			"keep": {Kind: "core", Levels: []BuildingLevel{{Level: 1}}},
			"farm": {Kind: "producer", Produces: "food", Levels: []BuildingLevel{
				{Level: 1, RatePerH: 60, Storage: 480},
				{Level: 2, RatePerH: 120, Storage: 960},
			}},
			"mint": {Kind: "producer", Produces: "gold", Levels: []BuildingLevel{
				{Level: 1, IdleMultPct: 100},
				{Level: 2, IdleMultPct: 150},
			}},
			"granary": {Kind: "storage", Levels: []BuildingLevel{
				{Level: 1, StorageBonus: map[string]int64{"food": 600}},
			}},
		},
	}
	cfg.Rules.Builders = 1
	cfg.Rules.KeepCapMult = 2
	cfg.Rules.BaseStorage = map[string]int64{"food": 1000, "wood": 1000}
	cfg.Rules.SpeedupGemsPerHour = 12
	cfg.Rules.SpeedupMinGems = 1
	return cfg
}

func TestPendingProduction_RateAndCap(t *testing.T) {
	cfg := testCfg()
	rows := map[string]BuildingRow{
		"farm": {Building: "farm", Level: 1},
		"mint": {Building: "mint", Level: 1},
	}
	// 1 小时：farm 60 food、mint 30 gold。
	got := pendingProduction(cfg, rows, 1000, 1000+3600, 30, 8)
	if got["food"] != 60 || got["gold"] != 30 {
		t.Fatalf("1h production want food=60 gold=30, got %v", got)
	}
	// 100 小时：farm 被 storage 封顶 480；mint 被 cap_hours 封顶 = 30×8h = 240。
	got = pendingProduction(cfg, rows, 1000, 1000+360000, 30, 8)
	if got["food"] != 480 || got["gold"] != 240 {
		t.Fatalf("capped production want food=480 gold=240, got %v", got)
	}
}

func TestPendingProduction_ZeroCases(t *testing.T) {
	cfg := testCfg()
	rows := map[string]BuildingRow{"farm": {Building: "farm", Level: 1}}
	if got := pendingProduction(cfg, rows, 0, 3600, 30, 8); len(got) != 0 {
		t.Fatalf("lastCollect<=0 must yield nothing, got %v", got)
	}
	if got := pendingProduction(cfg, rows, 2000, 2000, 30, 8); len(got) != 0 {
		t.Fatalf("zero elapsed must yield nothing, got %v", got)
	}
	// Lv0（未建造）不产出。
	rows["farm"] = BuildingRow{Building: "farm", Level: 0}
	if got := pendingProduction(cfg, rows, 1000, 1000+3600, 30, 8); len(got) != 0 {
		t.Fatalf("level 0 must yield nothing, got %v", got)
	}
}

func TestSpeedupGems_CeilAndFloor(t *testing.T) {
	cfg := testCfg()
	if got := speedupGems(cfg, 3600); got != 12 {
		t.Fatalf("1h speedup want 12, got %d", got)
	}
	if got := speedupGems(cfg, 3601); got != 13 {
		t.Fatalf("1h+1s speedup must ceil to 13, got %d", got)
	}
	if got := speedupGems(cfg, 1); got != 1 {
		t.Fatalf("tiny remaining must floor at min_gems=1, got %d", got)
	}
	if got := speedupGems(cfg, 0); got != 0 {
		t.Fatalf("nothing remaining costs 0, got %d", got)
	}
}

func TestApplyStorageCap(t *testing.T) {
	cfg := testCfg()
	held := map[string]int64{"food": 900}
	// granary lv1：cap = 1000 + 600 = 1600。
	applyStorageCap(cfg, held, "food", 1000, 1)
	if held["food"] != 1600 {
		t.Fatalf("capped add want 1600, got %d", held["food"])
	}
	// 无 granary：cap = 1000；存量已超 cap（配置下调场景）不没收。
	held = map[string]int64{"food": 1200}
	applyStorageCap(cfg, held, "food", 100, 0)
	if held["food"] != 1200 {
		t.Fatalf("over-cap holdings must not shrink, got %d", held["food"])
	}
}

// K3：铸币坊产率 = 挂机章节曲线 × idle_mult_pct%；章 0（曲线 0）不产金；等级系数生效。
func TestPendingProduction_MintIdleCurve(t *testing.T) {
	cfg := testCfg()
	rows := map[string]BuildingRow{"mint": {Building: "mint", Level: 2}}
	// Lv2 系数 150%：基线 100/h × 1.5 = 150/h。
	got := pendingProduction(cfg, rows, 1000, 1000+3600, 100, 8)
	if got["gold"] != 150 {
		t.Fatalf("mint lv2 1h want 150, got %v", got)
	}
	// 章 0 → 基线 0 → 不产金（与旧挂机金库口径一致）。
	if zero := pendingProduction(cfg, rows, 1000, 1000+3600, 0, 8); len(zero) != 0 {
		t.Fatalf("zero base rate must yield nothing, got %v", zero)
	}
}
