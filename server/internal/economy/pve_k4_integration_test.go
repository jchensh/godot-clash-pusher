package economy

// K4（DESIGN_KINGDOM）：PveStart 把王国城防塔加成写进 progress 快照的 "_towers"
// 保留键（重放验证器同源注入的证据链）。需真 PG（INTEGRATION_DB_URL）。

import (
	"context"
	"encoding/json"
	"testing"
)

func TestRepo_PveStart_WritesTowerBonusIntoProgress(t *testing.T) {
	repo, cfg, acc := setupRepo(t)
	ctx := context.Background()
	if _, err := repo.Get(ctx, acc, cfg); err != nil {
		t.Fatal(err)
	}
	bid, err := repo.PveStart(ctx, acc, "stage_1_1", starterDeck, cfg, 30, 20)
	if err != nil {
		t.Fatalf("pve start with tower bonus: %v", err)
	}
	var raw []byte
	if err := repo.db.Pool.QueryRow(ctx,
		`SELECT progress FROM pve_battles WHERE id=$1`, bid).Scan(&raw); err != nil {
		t.Fatal(err)
	}
	var prog map[string]json.RawMessage
	if err := json.Unmarshal(raw, &prog); err != nil {
		t.Fatal(err)
	}
	var towers struct {
		HpPct  int `json:"hp_pct"`
		DmgPct int `json:"dmg_pct"`
	}
	tw, ok := prog["_towers"]
	if !ok {
		t.Fatalf("progress missing _towers key: %s", string(raw))
	}
	if err := json.Unmarshal(tw, &towers); err != nil {
		t.Fatal(err)
	}
	if towers.HpPct != 30 || towers.DmgPct != 20 {
		t.Fatalf("_towers want 30/20, got %+v", towers)
	}
	// 卡牌快照键不受保留键污染（"_" 前缀被重放端跳过）。
	if _, ok := prog["knight"]; !ok {
		t.Fatalf("progress missing card snapshot: %s", string(raw))
	}
	// 零加成不写键（老包兼容形状）。
	bid2, err := repo.PveStart(ctx, acc, "stage_1_1", starterDeck, cfg, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if err := repo.db.Pool.QueryRow(ctx,
		`SELECT progress FROM pve_battles WHERE id=$1`, bid2).Scan(&raw); err != nil {
		t.Fatal(err)
	}
	prog = nil
	if err := json.Unmarshal(raw, &prog); err != nil {
		t.Fatal(err)
	}
	if _, ok := prog["_towers"]; ok {
		t.Fatalf("zero bonus must not write _towers: %s", string(raw))
	}
}
