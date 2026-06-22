// Command battle hosts lockstep battle rooms; one goroutine per match.
//
// V4-S0b: scaffold placeholder. Real implementation in V4-S3.
// May be merged into gateway as a sub-routine in early stages (see PLAN_V4 §3).
package main

import (
	"log"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("battle boot [%s build %s] — placeholder, no rooms yet", version.V4Stage, version.Build)
}
