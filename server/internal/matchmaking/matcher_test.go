package matchmaking

import (
	"context"
	"sort"
	"testing"
	"time"
)

var bg = context.Background()

// fakeQueue is an in-memory Queue so the pairing logic can be tested without Redis.
type fakeQueue struct{ entries map[int64]Entry }

func newFakeQueue() *fakeQueue { return &fakeQueue{entries: map[int64]Entry{}} }

func (q *fakeQueue) Add(_ context.Context, e Entry) error  { q.entries[e.AccountID] = e; return nil }
func (q *fakeQueue) Remove(_ context.Context, id int64) error { delete(q.entries, id); return nil }
func (q *fakeQueue) All(_ context.Context) ([]Entry, error) {
	out := make([]Entry, 0, len(q.entries))
	for _, e := range q.entries {
		out = append(out, e)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].MMR < out[j].MMR })
	return out, nil
}

func TestWindowFor(t *testing.T) {
	cases := []struct {
		waited time.Duration
		want   int
	}{
		{0, 50}, {4 * time.Second, 50}, {5 * time.Second, 100},
		{10 * time.Second, 150}, {15 * time.Second, 200}, {60 * time.Second, 200},
	}
	for _, c := range cases {
		if got := windowFor(c.waited); got != c.want {
			t.Errorf("windowFor(%v)=%d, want %d", c.waited, got, c.want)
		}
	}
}

func TestFindPairs_CloseMatchedImmediately(t *testing.T) {
	now := time.Unix(1700000000, 0)
	q := newFakeQueue()
	_ = q.Add(bg, Entry{AccountID: 1, MMR: 1200, JoinedAt: now})
	_ = q.Add(bg, Entry{AccountID: 2, MMR: 1230, JoinedAt: now}) // 30 apart, within ±50
	m := NewMatcher(q, func() time.Time { return now })
	pairs, _ := m.FindPairs(bg)
	if len(pairs) != 1 {
		t.Fatalf("want 1 pair, got %d", len(pairs))
	}
	if len(q.entries) != 0 {
		t.Error("paired players should be removed from the queue")
	}
}

func TestFindPairs_FarWaitsThenMatchesAfterExpansion(t *testing.T) {
	t0 := time.Unix(1700000000, 0)
	clk := t0
	q := newFakeQueue()
	_ = q.Add(bg, Entry{AccountID: 1, MMR: 1200, JoinedAt: t0})
	_ = q.Add(bg, Entry{AccountID: 2, MMR: 1330, JoinedAt: t0}) // 130 apart
	m := NewMatcher(q, func() time.Time { return clk })

	if p, _ := m.FindPairs(bg); len(p) != 0 {
		t.Fatalf("130 apart at ±50 should not pair yet, got %d", len(p))
	}
	clk = t0.Add(12 * time.Second) // window now ±150 >= 130
	if p, _ := m.FindPairs(bg); len(p) != 1 {
		t.Fatalf("after window expansion should pair, got %d", len(p))
	}
}

func TestFindPairs_CancelRemovesFromPool(t *testing.T) {
	now := time.Unix(1700000000, 0)
	q := newFakeQueue()
	_ = q.Add(bg, Entry{AccountID: 1, MMR: 1200, JoinedAt: now})
	_ = q.Add(bg, Entry{AccountID: 2, MMR: 1210, JoinedAt: now})
	_ = q.Remove(bg, 1) // cancel
	m := NewMatcher(q, func() time.Time { return now })
	if p, _ := m.FindPairs(bg); len(p) != 0 {
		t.Errorf("only one left after cancel, no pair expected; got %d", len(p))
	}
}

func TestFindPairs_NearestWins(t *testing.T) {
	now := time.Unix(1700000000, 0)
	q := newFakeQueue()
	_ = q.Add(bg, Entry{AccountID: 1, MMR: 1200, JoinedAt: now})
	_ = q.Add(bg, Entry{AccountID: 2, MMR: 1210, JoinedAt: now}) // close to 1
	_ = q.Add(bg, Entry{AccountID: 3, MMR: 1500, JoinedAt: now}) // far from both
	m := NewMatcher(q, func() time.Time { return now })
	pairs, _ := m.FindPairs(bg)
	if len(pairs) != 1 {
		t.Fatalf("want 1 pair (1&2), got %d", len(pairs))
	}
	if _, ok := q.entries[3]; !ok {
		t.Error("far player 3 should still be waiting")
	}
}
