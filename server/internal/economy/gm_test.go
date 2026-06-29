package economy

// GM 工具集成测（需真 PG，设 INTEGRATION_DB_URL 跑；缺则 skip）。复用 setupRepo（repo_integration_test.go）。

import (
	"context"
	"testing"
)

func TestRepo_GMApply(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	repo.Get(ctx, acc, cfg) // seed 新档（gold 0）

	// ① 加货币 + 全卡碎片。
	st, err := repo.GMApply(ctx, acc, GMOps{AddGold: 5000, AddGems: 100, AddShardsAll: 50}, cfg)
	if err != nil {
		t.Fatalf("gm add: %v", err)
	}
	if st.Gold != 5000 || st.Gems != 100 {
		t.Fatalf("after add gold=%d gems=%d (want 5000/100)", st.Gold, st.Gems)
	}
	for _, c := range st.Cards {
		if c.Shards != 50 {
			t.Fatalf("card %s shards=%d (want 50 all)", c.CardID, c.Shards)
		}
	}

	// ② 解锁全部卡。
	st, _ = repo.GMApply(ctx, acc, GMOps{UnlockAll: true}, cfg)
	for _, c := range st.Cards {
		if !c.Unlocked {
			t.Fatalf("after unlock-all card %s not unlocked", c.CardID)
		}
	}

	// ③ 全卡满级满阶。
	st, _ = repo.GMApply(ctx, acc, GMOps{MaxAllCards: true}, cfg)
	maxRank := cfg.MaxRank()
	maxLevel := cfg.LevelCap(maxRank)
	for _, c := range st.Cards {
		if c.Level != maxLevel || c.Rank != maxRank {
			t.Fatalf("after max card %s level=%d rank=%d (want %d/%d)", c.CardID, c.Level, c.Rank, maxLevel, maxRank)
		}
	}

	// ④ 通关到第 2 章：ch1+ch2 共 20 关 cleared、highest=stage_2_10。
	st, _ = repo.GMApply(ctx, acc, GMOps{ClearThroughChapter: 2}, cfg)
	cleared := 0
	for _, s := range st.Stages {
		if s.Cleared {
			cleared++
		}
	}
	if cleared != 20 {
		t.Fatalf("after clear-through-2 cleared=%d (want 20 = ch1+ch2)", cleared)
	}
	if st.HighestCleared != "stage_2_10" {
		t.Fatalf("highest=%q (want stage_2_10)", st.HighestCleared)
	}

	// ⑤ 重置：清空 → 新档（gold 0、无 stage、仅 starter 解锁、碎片 0）。
	st, _ = repo.GMApply(ctx, acc, GMOps{Reset: true}, cfg)
	if st.Gold != 0 || st.Gems != 0 {
		t.Fatalf("after reset gold=%d gems=%d (want 0)", st.Gold, st.Gems)
	}
	if len(st.Stages) != 0 {
		t.Fatalf("after reset stages=%d (want 0)", len(st.Stages))
	}
	for _, c := range st.Cards {
		if c.Unlocked != cfg.Cards[c.CardID].Starter {
			t.Fatalf("after reset card %s unlocked=%v (want starter=%v)", c.CardID, c.Unlocked, cfg.Cards[c.CardID].Starter)
		}
		if c.Shards != 0 {
			t.Fatalf("after reset card %s shards=%d (want 0)", c.CardID, c.Shards)
		}
	}
}
