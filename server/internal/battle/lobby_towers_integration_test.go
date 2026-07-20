package battle

// K5（DESIGN_KINGDOM）：建房时从 kingdom_buildings 读双方城防 → JoinRoomResp 下发。
// 需真 PG + Redis（与 KAN-76 progress 集成测试同门槛）。

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	"github.com/jchensh/godot-clash-pusher/server/internal/kingdom"
	"github.com/jchensh/godot-clash-pusher/server/internal/matchmaking"
	pbbattle "github.com/jchensh/godot-clash-pusher/server/internal/pb/battle"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"google.golang.org/protobuf/proto"
)

func TestLobby_JoinRespCarriesTowerBonus(t *testing.T) {
	pgURL := os.Getenv("INTEGRATION_DB_URL")
	redisURL := os.Getenv("INTEGRATION_REDIS_URL")
	if pgURL == "" || redisURL == "" {
		t.Skip("need INTEGRATION_DB_URL + INTEGRATION_REDIS_URL")
	}
	ctx := context.Background()
	db, err := store.Open(ctx, pgURL)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	for _, tbl := range []string{"matches", "decks", "profiles", "accounts"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("cleanup %s: %v", tbl, err)
		}
	}
	a := seedAccount(t, db, ctx, "tower-a")
	b := seedAccount(t, db, ctx, "tower-b") // b 无王国 → 缺省无加成

	// a 修了 城墙 Lv5(+15%hp) + 箭楼 Lv5(+10%dmg)（真实配置 3%/2% per level）。
	for _, row := range []struct {
		building string
		level    int
	}{{"wall", 5}, {"watchtower", 5}} {
		if _, err := db.Pool.Exec(ctx,
			`INSERT INTO kingdom_buildings (account_id, building, level) VALUES ($1,$2,$3)`,
			a, row.building, row.level); err != nil {
			t.Fatalf("seed kingdom_buildings: %v", err)
		}
	}

	bundle, err := gameconfig.Load("../../../config")
	if err != nil {
		t.Skipf("no real config: %v", err)
	}
	kc, err := kingdom.ParseConfig(bundle)
	if err != nil {
		t.Fatalf("parse kingdom config: %v", err)
	}

	rdb, err := store.OpenRedis(ctx, redisURL)
	if err != nil {
		t.Fatalf("open redis: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	q := matchmaking.NewRedisQueue(rdb.Client())
	_ = q.Remove(ctx, a)
	_ = q.Remove(ctx, b)

	now := time.Unix(1700000000, 0)
	lobby := NewLobby(q, &fakePersister{}, db, "ladder_01", func() time.Time { return now })
	lobby.KingdomCfg = kc

	sendA := make(chan []byte, 32)
	sendB := make(chan []byte, 32)
	wa, err := lobby.EnterQueue(ctx, a, &pbcommon.ProfileSummary{AccountId: a}, sendA, 1)
	if err != nil {
		t.Fatalf("enqueue A: %v", err)
	}
	if _, err := lobby.EnterQueue(ctx, b, &pbcommon.ProfileSummary{AccountId: b}, sendB, 1); err != nil {
		t.Fatalf("enqueue B: %v", err)
	}
	lobby.matchTick(ctx)
	mia := waitMatch(t, wa)

	if mid, _ := firstFrame(t, sendA); mid != pbcommon.MsgId_MATCH_FOUND_PUSH {
		t.Fatalf("A first frame != MATCH_FOUND_PUSH")
	}
	mid, pl := firstFrame(t, sendA)
	if mid != pbcommon.MsgId_JOIN_ROOM_RESP {
		t.Fatalf("A second frame = %v, want JOIN_ROOM_RESP", mid)
	}
	var resp pbbattle.JoinRoomResp
	if err := proto.Unmarshal(pl, &resp); err != nil {
		t.Fatalf("unmarshal join resp: %v", err)
	}
	mine, theirs := resp.Side1Towers, resp.Side2Towers
	if mia.side == 2 {
		mine, theirs = theirs, mine
	}
	if mine == nil || mine.HpPct != 15 || mine.DmgPct != 10 {
		t.Fatalf("A towers = %+v, want +15%%hp/+10%%dmg", mine)
	}
	if theirs != nil {
		t.Fatalf("B towers should be nil (no kingdom), got %+v", theirs)
	}
}
