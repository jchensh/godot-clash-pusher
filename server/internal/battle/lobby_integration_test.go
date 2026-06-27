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
