// Command migrate runs PostgreSQL schema migrations (up/down).
//
// Unlike gateway/api/battle, migrate is a one-shot CLI: runs migrations then exits.
// V4-S0c: scaffold placeholder that just logs and exits 0.
// Real implementation in V4-S1 (accounts table) using migrations under server/migrations/.
package main

import (
	"log"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("migrate boot [%s build %s] — placeholder, no migrations defined yet", version.V4Stage, version.Build)
	log.Println("migrate exit (one-shot)")
}
