// Command gateway is the V4 WebSocket entry point + auth + routing.
//
// V4-S0b: scaffold placeholder. Real implementation in V4-S3 (lockstep battle).
package main

import (
	"log"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("gateway boot [%s build %s] — placeholder, no listener yet", version.V4Stage, version.Build)
}
