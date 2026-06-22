// Command api serves the V4 HTTP API: auth, profile, matchmaking, leaderboard.
//
// V4-S0b: scaffold placeholder. Real implementation begins in V4-S1 (auth).
package main

import (
	"log"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("api boot [%s build %s] — placeholder, no listener yet", version.V4Stage, version.Build)
}
