// Package rating implements ELO matchmaking ratings (V4-S4). New players start
// at DefaultRating (1200); a match shifts the winner up and loser down by an
// amount that depends on how surprising the result was — beating a much
// stronger opponent gains a lot, beating a much weaker one barely moves. The
// swing is zero-sum (what one gains the other loses), capped by KFactor.
//
// rating is a hidden matchmaking number, separate from the visible trophies.
package rating

import "math"

const (
	// DefaultRating is every new account's starting matchmaking rating.
	DefaultRating = 1200
	// KFactor bounds the per-match swing (±K at most). 32 is the classic value.
	KFactor = 32
)

// Expected returns A's expected score (0..1) against B per the ELO formula.
// Equal ratings -> 0.5; a 400-point edge -> ~0.91.
func Expected(ra, rb int) float64 {
	return 1.0 / (1.0 + math.Pow(10, float64(rb-ra)/400.0))
}

// Update returns both players' new ratings after a game. scoreA is A's result:
// 1 = A won, 0 = A lost, 0.5 = draw. Zero-sum: A's gain equals B's loss.
func Update(ra, rb int, scoreA float64) (int, int) {
	delta := int(math.Round(KFactor * (scoreA - Expected(ra, rb))))
	return ra + delta, rb - delta
}
