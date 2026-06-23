package profile

import (
	"errors"
	"testing"
)

func TestValidateDeck(t *testing.T) {
	eight := []string{"knight", "archer", "fireball", "giant", "goblins", "musketeer", "minions", "cannon"}

	cases := []struct {
		name    string
		slot    int32
		cards   []string
		wantErr bool
	}{
		{"valid slot 1", 1, eight, false},
		{"valid slot 3", 3, eight, false},
		{"slot too low", 0, eight, true},
		{"slot too high", 4, eight, true},
		{"seven cards", 1, eight[:7], true},
		{"nine cards", 1, append(append([]string{}, eight...), "wizard"), true},
		{"duplicate card", 1, []string{"knight", "knight", "fireball", "giant", "goblins", "musketeer", "minions", "cannon"}, true},
		{"empty card id", 1, []string{"knight", "", "fireball", "giant", "goblins", "musketeer", "minions", "cannon"}, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := validateDeck(tc.slot, tc.cards)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				if !errors.Is(err, ErrDeckInvalid) {
					t.Fatalf("expected ErrDeckInvalid, got %v", err)
				}
				return
			}
			if err != nil {
				t.Fatalf("expected nil, got %v", err)
			}
		})
	}
}
