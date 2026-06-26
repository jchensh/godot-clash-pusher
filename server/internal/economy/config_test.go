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
	if err := os.WriteFile(filepath.Join(dir, "stages.json"), []byte(`{
		"_comment":"x",
		"stage_1_1":{"chapter":1,"index":1,"difficulty_coef":1.0,
			"first_clear":{"gold":300,"gems":5,"shards":{}},
			"repeat":{"gold":30},
			"shard_drop":{"knight":{"chance":0.5,"amount":1}}},
		"stage_1_2":{"chapter":1,"index":2,"difficulty_coef":1.05,
			"first_clear":{"gold":320,"gems":0,"shards":{"golem":3}},
			"repeat":{"gold":32},
			"shard_drop":{}}
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
	// stages.json 也应被解析：真实 config 有 stage_1_1 / stage_1_2。
	if _, ok := cfg.Stage("stage_1_1"); !ok {
		t.Fatal("real config missing stage_1_1")
	}
	if ids := cfg.OrderedStageIDs(); len(ids) < 2 {
		t.Fatalf("real config stages=%d (want >=2)", len(ids))
	}
}

// stages.json 解析：有序序列 + reward/drop 查询 + stars 上限。
func TestParseStages(t *testing.T) {
	cfg := loadCfg(t)

	// 有序序列：stage_1_1 在前、stage_1_2 在后。
	ids := cfg.OrderedStageIDs()
	if len(ids) != 2 || ids[0] != "stage_1_1" || ids[1] != "stage_1_2" {
		t.Fatalf("ordered ids=%v", ids)
	}
	// 前驱查询：第一关无前驱，第二关前驱 = 第一关。
	if prev, ok := cfg.PrevStage("stage_1_1"); ok {
		t.Fatalf("stage_1_1 should have no prev, got %q", prev)
	}
	if prev, ok := cfg.PrevStage("stage_1_2"); !ok || prev != "stage_1_1" {
		t.Fatalf("stage_1_2 prev=%q ok=%v", prev, ok)
	}
	// 未知关卡。
	if _, ok := cfg.Stage("nope"); ok {
		t.Fatal("unknown stage should be absent")
	}
	if _, ok := cfg.PrevStage("nope"); ok {
		t.Fatal("unknown stage prev should be absent")
	}

	// stage_1_2 first_clear 含 golem:3 碎片。
	s, _ := cfg.Stage("stage_1_2")
	if s.FirstClear.Gold != 320 || s.FirstClear.Gems != 0 {
		t.Fatalf("stage_1_2 first_clear=%+v", s.FirstClear)
	}
	if s.FirstClear.Shards["golem"] != 3 {
		t.Fatalf("stage_1_2 first_clear shards=%+v", s.FirstClear.Shards)
	}
	// repeat。
	if s.Repeat.Gold != 32 || len(s.Repeat.Shards) != 0 {
		t.Fatalf("stage_1_2 repeat=%+v", s.Repeat)
	}
	// shard_drop：stage_1_1 knight 50% 掉 1。
	s1, _ := cfg.Stage("stage_1_1")
	if len(s1.ShardDrop) != 1 {
		t.Fatalf("stage_1_1 drop len=%d", len(s1.ShardDrop))
	}
	d := s1.ShardDrop["knight"]
	if d.Chance != 0.5 || d.Amount != 1 {
		t.Fatalf("knight drop=%+v", d)
	}
	// stars 上限：两关都没显式 stars 配置 → 默认 3。
	if cfg.StarCap("stage_1_1") != 3 {
		t.Fatalf("stage_1_1 starcap=%d", cfg.StarCap("stage_1_1"))
	}
}
