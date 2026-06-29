package matchmaking

import (
	"context"
	"log"
	"sort"
	"time"
)

const (
	baseWindow = 50               // ±50 MMR at queue entry
	stepWindow = 50               // widen by ±50 ...
	stepEvery  = 5 * time.Second  // ... every 5s waited
	maxWindow  = 200              // capped at ±200
)

// Pair is two players the Matcher decided should play each other.
type Pair struct {
	A Entry
	B Entry
}

// Matcher pairs waiting players from a Queue. It's stateless beyond the queue +
// a clock (overridable for tests).
type Matcher struct {
	queue Queue
	now   func() time.Time
}

func NewMatcher(q Queue, now func() time.Time) *Matcher {
	if now == nil {
		now = time.Now
	}
	return &Matcher{queue: q, now: now}
}

// windowFor returns the ± MMR window a player accepts after waiting `waited`:
// ±50 at first, +±50 every 5s, capped at ±200 (PLAN_V4 §4).
func windowFor(waited time.Duration) int {
	if waited < 0 {
		waited = 0
	}
	w := baseWindow + int(waited/stepEvery)*stepWindow
	if w > maxWindow {
		w = maxWindow
	}
	return w
}

// FindPairs scans the queue and returns the pairs to match this tick, removing
// each paired account from the queue. Greedy + fair: the longest-waiting player
// goes first (widest window), matched to the nearest opponent that is within
// BOTH players' windows (so a freshly-joined player isn't dragged into a wide
// gap). Call this on a short interval (~1s) from the matchmaking loop.
func (m *Matcher) FindPairs(ctx context.Context) ([]Pair, error) {
	entries, err := m.queue.All(ctx)
	if err != nil {
		return nil, err
	}
	now := m.now()

	// Longest-waiting first.
	sort.Slice(entries, func(i, j int) bool { return entries[i].JoinedAt.Before(entries[j].JoinedAt) })

	matched := make(map[int64]bool, len(entries))
	var pairs []Pair
	for i := range entries {
		a := entries[i]
		if matched[a.AccountID] {
			continue
		}
		wa := windowFor(now.Sub(a.JoinedAt))
		var best *Entry
		bestDist := maxWindow + 1
		for j := range entries {
			if i == j || matched[entries[j].AccountID] {
				continue
			}
			b := entries[j]
			d := absInt(a.MMR - b.MMR)
			wb := windowFor(now.Sub(b.JoinedAt))
			// Mutual acceptance: within the narrower of the two windows.
			limit := wa
			if wb < limit {
				limit = wb
			}
			if d <= limit && d < bestDist {
				bestDist = d
				bb := b
				best = &bb
			}
		}
		if best != nil {
			matched[a.AccountID] = true
			matched[best.AccountID] = true
			pairs = append(pairs, Pair{A: a, B: *best})
			_ = m.queue.Remove(ctx, a.AccountID)
			_ = m.queue.Remove(ctx, best.AccountID)
		}
	}
	// Diagnostic (no per-lone-waiter spam): only when a pairing was at least
	// possible (≥2 waiting). Explains "why didn't I match" via gap vs window.
	if len(pairs) > 0 {
		log.Printf("mm: tick waiting=%d, paired %d this tick", len(entries), len(pairs))
	} else if len(entries) >= 2 {
		log.Printf("mm: tick waiting=%d, no pair (closest MMR gap=%d, max window=±%d)", len(entries), closestGap(entries), maxWindow)
	}
	return pairs, nil
}

// closestGap returns the smallest pairwise MMR distance among waiting entries
// (diagnostic only). Returns 0 for <2 entries.
func closestGap(entries []Entry) int {
	best := -1
	for i := range entries {
		for j := i + 1; j < len(entries); j++ {
			d := absInt(entries[i].MMR - entries[j].MMR)
			if best < 0 || d < best {
				best = d
			}
		}
	}
	if best < 0 {
		return 0
	}
	return best
}

func absInt(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
