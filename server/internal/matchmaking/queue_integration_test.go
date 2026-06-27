package matchmaking

// Integration test for the Redis-backed queue. Requires a real Redis via
// INTEGRATION_REDIS_URL (default `go test` skips it):
//
//   INTEGRATION_REDIS_URL=redis://localhost:6379/0 go test ./internal/matchmaking/...

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

func TestRedisQueue_RoundTrip(t *testing.T) {
	url := os.Getenv("INTEGRATION_REDIS_URL")
	if url == "" {
		t.Skip("INTEGRATION_REDIS_URL not set; skipping integration test")
	}
	ctx := context.Background()
	r, err := store.OpenRedis(ctx, url)
	if err != nil {
		t.Fatalf("open redis: %v", err)
	}
	t.Cleanup(func() { _ = r.Close() })
	q := NewRedisQueue(r.Client())

	// Use high ids unlikely to collide; clean prior runs.
	const idA, idB = 9000001, 9000002
	_ = q.Remove(ctx, idA)
	_ = q.Remove(ctx, idB)

	now := time.Now().Truncate(time.Millisecond)
	if err := q.Add(ctx, Entry{AccountID: idA, MMR: 1200, DeckSlot: 1, JoinedAt: now}); err != nil {
		t.Fatalf("add A: %v", err)
	}
	if err := q.Add(ctx, Entry{AccountID: idB, MMR: 1250, DeckSlot: 2, JoinedAt: now}); err != nil {
		t.Fatalf("add B: %v", err)
	}

	all, err := q.All(ctx)
	if err != nil {
		t.Fatalf("All: %v", err)
	}
	a := findEntry(all, idA)
	b := findEntry(all, idB)
	if a == nil || b == nil {
		t.Fatalf("both entries should be in queue; got %d entries", len(all))
	}
	if a.MMR != 1200 || a.DeckSlot != 1 {
		t.Errorf("A: mmr=%d slot=%d, want 1200/1", a.MMR, a.DeckSlot)
	}
	if b.MMR != 1250 || b.DeckSlot != 2 {
		t.Errorf("B: mmr=%d slot=%d, want 1250/2", b.MMR, b.DeckSlot)
	}

	if err := q.Remove(ctx, idA); err != nil {
		t.Fatalf("remove A: %v", err)
	}
	all2, _ := q.All(ctx)
	if findEntry(all2, idA) != nil {
		t.Error("A should be gone after Remove")
	}
	_ = q.Remove(ctx, idB)
}

func findEntry(entries []Entry, id int64) *Entry {
	for i := range entries {
		if entries[i].AccountID == id {
			return &entries[i]
		}
	}
	return nil
}
