package kingdom_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	"github.com/jchensh/godot-clash-pusher/server/internal/kingdom"
)

// 最小合法配置：keep + 一个 producer + granary + 一个 defense。
const minimalKingdomJSON = `{
	"resources": ["food", "wood"],
	"rules": {"builders": 1, "keep_cap_mult": 2,
		"base_storage": {"food": 1000, "wood": 1000},
		"speedup_gems_per_hour": 12, "speedup_min_gems": 1,
		"initial": {"resources": {"food": 200, "wood": 200}, "buildings": {"keep": 1, "farm": 1}}},
	"buildings": {
		"keep": {"kind": "core", "levels": [
			{"level": 1, "cost": {"food": 0, "wood": 0}, "time_s": 0, "chapter_req": 0},
			{"level": 2, "cost": {"food": 400, "wood": 400}, "time_s": 300, "chapter_req": 1}]},
		"farm": {"kind": "producer", "produces": "food", "levels": [
			{"level": 1, "cost": {"wood": 40}, "time_s": 60, "rate_per_h": 60, "storage": 480},
			{"level": 2, "cost": {"wood": 160}, "time_s": 96, "rate_per_h": 120, "storage": 960}]},
		"granary": {"kind": "storage", "levels": [
			{"level": 1, "cost": {"food": 30, "wood": 30}, "time_s": 90, "storage_bonus": {"food": 600, "wood": 480}}]},
		"wall": {"kind": "defense", "levels": [
			{"level": 1, "cost": {"food": 60, "wood": 80}, "time_s": 120, "tower_hp_pct": 3}]},
		"mint": {"kind": "producer", "produces": "gold", "levels": [
			{"level": 1, "cost": {"food": 50, "wood": 50}, "time_s": 60, "rate_per_h": 30, "storage": 240}]}
	}
}`

func loadKingdomCfg(t *testing.T, raw string) (*kingdom.Config, error) {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "kingdom.json"), []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
	b, err := gameconfig.Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	return kingdom.ParseConfig(b)
}

func TestParseConfig_Minimal(t *testing.T) {
	cfg, err := loadKingdomCfg(t, minimalKingdomJSON)
	if err != nil {
		t.Fatalf("parse minimal: %v", err)
	}
	if cfg.MaxLevel("farm") != 2 {
		t.Fatalf("farm max level want 2, got %d", cfg.MaxLevel("farm"))
	}
	if _, ok := cfg.LevelRow("farm", 3); ok {
		t.Fatal("level 3 must be out of range")
	}
	if got := cfg.StorageCap("food", 1); got != 1600 {
		t.Fatalf("storage cap with granary lv1 want 1600, got %d", got)
	}
	if got := cfg.StorageCap("food", 0); got != 1000 {
		t.Fatalf("storage cap without granary want 1000, got %d", got)
	}
}

// 铁门（DESIGN_KINGDOM §4）：建筑成本禁用 gold——金币不能买城建资源。
func TestParseConfig_RejectsGoldCost(t *testing.T) {
	bad := `{
		"resources": ["food"],
		"rules": {"builders": 1, "keep_cap_mult": 2, "base_storage": {},
			"speedup_gems_per_hour": 12, "speedup_min_gems": 1,
			"initial": {"resources": {}, "buildings": {}}},
		"buildings": {"keep": {"kind": "core", "levels": [
			{"level": 1, "cost": {"gold": 100}, "time_s": 0}]}}
	}`
	if _, err := loadKingdomCfg(t, bad); err == nil {
		t.Fatal("gold cost must be rejected")
	}
}

func TestParseConfig_RejectsNonContiguousLevels(t *testing.T) {
	bad := `{
		"resources": ["food"],
		"rules": {"builders": 1, "keep_cap_mult": 2, "base_storage": {},
			"speedup_gems_per_hour": 12, "speedup_min_gems": 1,
			"initial": {"resources": {}, "buildings": {}}},
		"buildings": {"keep": {"kind": "core", "levels": [
			{"level": 1, "cost": {}, "time_s": 0},
			{"level": 3, "cost": {}, "time_s": 0}]}}
	}`
	if _, err := loadKingdomCfg(t, bad); err == nil {
		t.Fatal("non-contiguous level table must be rejected")
	}
}

func TestParseConfig_RequiresKeep(t *testing.T) {
	bad := `{
		"resources": ["food"],
		"rules": {"builders": 1, "keep_cap_mult": 2, "base_storage": {},
			"speedup_gems_per_hour": 12, "speedup_min_gems": 1,
			"initial": {"resources": {}, "buildings": {}}},
		"buildings": {"farm": {"kind": "producer", "produces": "food", "levels": [
			{"level": 1, "cost": {}, "time_s": 0, "rate_per_h": 60, "storage": 480}]}}
	}`
	if _, err := loadKingdomCfg(t, bad); err == nil {
		t.Fatal("missing keep must be rejected")
	}
}

// 仓库真实配置必须可解析（提交前防 drift；镜像 economy config_test 的做法）。
func TestParseConfig_RealRepoConfig(t *testing.T) {
	b, err := gameconfig.Load("../../../config")
	if err != nil {
		t.Skipf("no real config: %v", err)
	}
	cfg, err := kingdom.ParseConfig(b)
	if err != nil {
		t.Fatalf("real kingdom.json must parse: %v", err)
	}
	for _, name := range []string{"keep", "farm", "workshop", "granary", "wall", "watchtower", "mint"} {
		if cfg.MaxLevel(name) == 0 {
			t.Fatalf("real config missing building %s", name)
		}
	}
	if cfg.MaxLevel("keep") != 10 {
		t.Fatalf("keep max level want 10, got %d", cfg.MaxLevel("keep"))
	}
}
