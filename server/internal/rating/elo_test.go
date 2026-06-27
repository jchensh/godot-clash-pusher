package rating

import "testing"

func TestExpected_EqualIsHalf(t *testing.T) {
	if e := Expected(1200, 1200); e != 0.5 {
		t.Errorf("equal ratings expected=%v, want 0.5", e)
	}
}

func TestExpected_HigherFavored(t *testing.T) {
	if Expected(1400, 1200) <= 0.5 {
		t.Error("higher-rated player should be favored (>0.5)")
	}
	if Expected(1000, 1200) >= 0.5 {
		t.Error("lower-rated player should be the underdog (<0.5)")
	}
}

func TestUpdate_EqualWin(t *testing.T) {
	na, nb := Update(1200, 1200, 1)
	if na != 1216 || nb != 1184 {
		t.Errorf("equal win -> %d/%d, want 1216/1184 (±16 at K=32)", na, nb)
	}
}

func TestUpdate_DrawNoMoveWhenEqual(t *testing.T) {
	na, nb := Update(1200, 1200, 0.5)
	if na != 1200 || nb != 1200 {
		t.Errorf("equal draw should not move ratings, got %d/%d", na, nb)
	}
}

func TestUpdate_ZeroSum(t *testing.T) {
	ra, rb := 1300, 1100
	na, nb := Update(ra, rb, 1)
	if (na - ra) != -(nb - rb) {
		t.Errorf("not zero-sum: dA=%d dB=%d", na-ra, nb-rb)
	}
}

func TestUpdate_UpsetGainsMoreThanExpectedWin(t *testing.T) {
	// Underdog (1000) beating favorite (1400) should gain far more than a
	// favorite (1400) beating an underdog (1000).
	upset, _ := Update(1000, 1400, 1)
	expected, _ := Update(1400, 1000, 1)
	if (upset - 1000) <= (expected - 1400) {
		t.Errorf("upset gain %d should exceed expected-win gain %d", upset-1000, expected-1400)
	}
}
