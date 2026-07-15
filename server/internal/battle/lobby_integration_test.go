package battle

// Integration test for the matchmaking lobby. Needs BOTH a real Postgres
// (INTEGRATION_DB_URL) and Redis (INTEGRATION_REDIS_URL):
//
//   INTEGRATION_DB_URL=postgres://app:dev@localhost:5432/gcp?sslmode=disable \
//   INTEGRATION_REDIS_URL=redis://localhost:6379/0 \
//       go test -p 1 ./internal/battle/...

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/matchmaking"
	pbbattle "github.com/jchensh/godot-clash-pusher/server/internal/pb/battle"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbmatch "github.com/jchensh/godot-clash-pusher/server/internal/pb/match"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"google.golang.org/protobuf/proto"
)

func TestLobby_MatchmakingPairsAndCreatesRoom(t *testing.T) {
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
	a := seedAccount(t, db, ctx, "lob-a") // both rating 1200, no saved deck -> default
	b := seedAccount(t, db, ctx, "lob-b")

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

	sendA := make(chan []byte, 32)
	sendB := make(chan []byte, 32)
	wa, err := lobby.EnterQueue(ctx, a, &pbcommon.ProfileSummary{AccountId: a, Nickname: "A"}, sendA, 1)
	if err != nil {
		t.Fatalf("enqueue A: %v", err)
	}
	wb, err := lobby.EnterQueue(ctx, b, &pbcommon.ProfileSummary{AccountId: b, Nickname: "B"}, sendB, 1)
	if err != nil {
		t.Fatalf("enqueue B: %v", err)
	}

	lobby.matchTick(ctx)

	mia := waitMatch(t, wa)
	mib := waitMatch(t, wb)
	if mia.side != 1 || mib.side != 2 {
		t.Errorf("sides a=%d b=%d, want 1/2", mia.side, mib.side)
	}
	if mia.room == nil || mia.room != mib.room {
		t.Fatal("both should land in the same room")
	}

	// Each gets MatchFoundPush first, naming the other as opponent.
	if mid, pl := firstFrame(t, sendA); mid != pbcommon.MsgId_MATCH_FOUND_PUSH {
		t.Fatalf("A first frame = %v, want MATCH_FOUND_PUSH", mid)
	} else {
		var mf pbmatch.MatchFoundPush
		_ = proto.Unmarshal(pl, &mf)
		if mf.YourSide != 1 || mf.Opponent.GetAccountId() != b || mf.RoomId == "" {
			t.Errorf("A match found: side=%d opp=%d room=%q", mf.YourSide, mf.Opponent.GetAccountId(), mf.RoomId)
		}
	}
	if mid, _ := firstFrame(t, sendB); mid != pbcommon.MsgId_MATCH_FOUND_PUSH {
		t.Fatalf("B first frame = %v, want MATCH_FOUND_PUSH", mid)
	}

	// Both accounts now map to the same live room (for reconnect).
	lobby.mu.Lock()
	ra, rb := lobby.active[a], lobby.active[b]
	lobby.mu.Unlock()
	if ra == nil || ra != rb {
		t.Error("both accounts should map to the same active room")
	}

	// Paired accounts are out of the queue.
	all, _ := q.All(ctx)
	for _, e := range all {
		if e.AccountID == a || e.AccountID == b {
			t.Errorf("account %d should have left the queue", e.AccountID)
		}
	}
}

// KAN-76：养成进 PVP——账号在 economy_cards 里的 level/rank 要随 JoinRoomResp
// 权威下发；没有行的卡（懒播种未触发）fallback level1/rank1，绝不因此配不了对。
func TestLobby_JoinRespCarriesEconomyProgress(t *testing.T) {
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
	// economy_cards/economy_state 有 ON DELETE CASCADE，删 accounts 即级联清。
	for _, tbl := range []string{"matches", "decks", "profiles", "accounts"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("cleanup %s: %v", tbl, err)
		}
	}
	a := seedAccount(t, db, ctx, "prog-a")
	b := seedAccount(t, db, ctx, "prog-b") // b 无 economy_cards 行 -> 全 fallback 1/1

	// a 练过 knight(4级2阶) + giant(7级3阶)，其余卡无行（部分 fallback）。
	for _, row := range []struct {
		card        string
		level, rank int
	}{{"knight", 4, 2}, {"giant", 7, 3}} {
		if _, err := db.Pool.Exec(ctx,
			`INSERT INTO economy_cards (account_id, card_id, level, rank, unlocked) VALUES ($1,$2,$3,$4,TRUE)`,
			a, row.card, row.level, row.rank); err != nil {
			t.Fatalf("seed economy_cards: %v", err)
		}
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

	sendA := make(chan []byte, 32)
	sendB := make(chan []byte, 32)
	wa, err := lobby.EnterQueue(ctx, a, &pbcommon.ProfileSummary{AccountId: a}, sendA, 1)
	if err != nil {
		t.Fatalf("enqueue A: %v", err)
	}
	wb, err := lobby.EnterQueue(ctx, b, &pbcommon.ProfileSummary{AccountId: b}, sendB, 1)
	if err != nil {
		t.Fatalf("enqueue B: %v", err)
	}
	lobby.matchTick(ctx)
	mia := waitMatch(t, wa)
	_ = waitMatch(t, wb)

	// A 的帧序：MATCH_FOUND_PUSH -> JOIN_ROOM_RESP（room.Run 发）。
	if mid, _ := firstFrame(t, sendA); mid != pbcommon.MsgId_MATCH_FOUND_PUSH {
		t.Fatalf("A first frame = %v, want MATCH_FOUND_PUSH", mid)
	}
	mid, pl := firstFrame(t, sendA)
	if mid != pbcommon.MsgId_JOIN_ROOM_RESP {
		t.Fatalf("A second frame = %v, want JOIN_ROOM_RESP", mid)
	}
	var resp pbbattle.JoinRoomResp
	if err := proto.Unmarshal(pl, &resp); err != nil {
		t.Fatalf("unmarshal join resp: %v", err)
	}

	// 按 A 实际分到的 side 取两侧 progress。
	mine, theirs := resp.Side1Progress, resp.Side2Progress
	if mia.side == 2 {
		mine, theirs = theirs, mine
	}
	if len(mine) != 8 || len(theirs) != 8 {
		t.Fatalf("progress size %d/%d, want 8/8 (deck cards)", len(mine), len(theirs))
	}
	byCard := map[string]*pbbattle.CardProgress{}
	for _, p := range mine {
		byCard[p.CardId] = p
	}
	if p := byCard["knight"]; p == nil || p.Level != 4 || p.Rank != 2 {
		t.Errorf("A knight progress = %+v, want 4/2", byCard["knight"])
	}
	if p := byCard["giant"]; p == nil || p.Level != 7 || p.Rank != 3 {
		t.Errorf("A giant progress = %+v, want 7/3", byCard["giant"])
	}
	if p := byCard["archers"]; p == nil || p.Level != 1 || p.Rank != 1 {
		t.Errorf("A archers (no row) should fall back to 1/1, got %+v", byCard["archers"])
	}
	for _, p := range theirs {
		if p.Level != 1 || p.Rank != 1 {
			t.Errorf("B (never seeded) card %s = %d/%d, want all 1/1", p.CardId, p.Level, p.Rank)
		}
	}
}

func waitMatch(t *testing.T, w *waiter) matchInfo {
	t.Helper()
	select {
	case mi := <-w.matched:
		return mi
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for match")
		return matchInfo{}
	}
}

func firstFrame(t *testing.T, ch chan []byte) (pbcommon.MsgId, []byte) {
	t.Helper()
	select {
	case f := <-ch:
		mid, pl, ok := decodeFrame(f)
		if !ok {
			t.Fatal("short frame")
		}
		return mid, pl
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for frame")
		return 0, nil
	}
}
