package economy_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
)

func loadCfg(t *testing.T) *economy.Config {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "economy.json"), []byte(`{
		"level_stat_per_level": 0.10, "rank_stat_mult": 1.25,
		"level_cap_per_rank": {"1":4,"2":7,"3":10},
		"upgrade_cost_base": {"common":80,"rare":160},
		"upgrade_cost_growth": 0.5,
		"rank_up": {"common":[{"shards":20,"gold":2000},{"shards":50,"gold":5000}]},
		"unlock_shards": {"common":30,"legendary":120}
	}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "card_progression.json"), []byte(`{
		"_comment":"x",
		"knight":{"rarity":"common","starter":true,"base_power":100},
		"golem":{"rarity":"legendary","starter":false,"base_power":260}
	}`), 0o644); err != nil {
		t.Fatal(err)
	}
	b, err := gameconfig.Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := economy.ParseConfig(b)
	if err != nil {
		t.Fatal(err)
	}
	return cfg
}

func TestParseAndCosts(t *testing.T) {
	cfg := loadCfg(t)
	if cfg.MaxRank() != 3 {
		t.Fatalf("maxRank=%d", cfg.MaxRank())
	}
	if cfg.LevelCap(1) != 4 || cfg.LevelCap(2) != 7 || cfg.LevelCap(3) != 10 {
		t.Fatal("level cap wrong")
	}
	// upgrade: common base 80, L1 → 80, L5 → 80*(1+4*0.5)=240
	if c, _ := cfg.UpgradeCost("common", 1); c != 80 {
		t.Fatalf("upgrade L1=%d", c)
	}
	if c, _ := cfg.UpgradeCost("common", 5); c != 240 {
		t.Fatalf("upgrade L5=%d", c)
	}
	// rank up: common rank1→2 = {20,2000}
	if rc, ok := cfg.RankUpCost("common", 1); !ok || rc.Shards != 20 || rc.Gold != 2000 {
		t.Fatalf("rankUp r1=%+v ok=%v", rc, ok)
	}
	// rank3 → no cost (only 2 entries)
	if _, ok := cfg.RankUpCost("common", 3); ok {
		t.Fatal("rank3 should have no cost")
	}
	if n, _ := cfg.UnlockCost("legendary"); n != 120 {
		t.Fatalf("unlock legendary=%d", n)
	}
	if r, ok := cfg.Rarity("knight"); !ok || r != "common" {
		t.Fatal("knight rarity")
	}
	if len(cfg.Cards) != 2 {
		t.Fatalf("cards=%d", len(cfg.Cards))
	}
	if !cfg.Cards["knight"].Starter || cfg.Cards["golem"].Starter {
		t.Fatal("starter flags wrong")
	}
}

// 真实 config/（双份同源校验）：16 卡、稀有度对得上。
func TestParse_RealConfig(t *testing.T) {
	b, err := gameconfig.Load("../../../config")
	if err != nil {
		t.Skipf("no real config: %v", err)
	}
	cfg, err := economy.ParseConfig(b)
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.Cards) != 16 {
		t.Fatalf("real config cards=%d (want 16)", len(cfg.Cards))
	}
	if r, _ := cfg.Rarity("golem"); r != "legendary" {
		t.Fatalf("golem rarity=%s", r)
	}
}
