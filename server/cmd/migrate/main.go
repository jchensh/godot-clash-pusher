// Command migrate runs PostgreSQL schema migrations (up/down).
//
// V4-S0b: scaffold placeholder. Real implementation in V4-S1 (accounts table)
// using migrations under server/migrations/.
package main

import (
	"log"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("migrate boot [%s build %s] — placeholder, no migrations defined yet", version.V4Stage, version.Build)
}
