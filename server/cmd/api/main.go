// Command api serves the V4 HTTP API: auth, profile, matchmaking, leaderboard.
//
// V4-S0c: scaffold placeholder with signal-driven shutdown.
// Real implementation begins in V4-S1 (auth).
package main

import (
	"context"
	"log"
	"os/signal"
	"syscall"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("api boot [%s build %s] — placeholder, idling until SIGINT/SIGTERM", version.V4Stage, version.Build)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	log.Println("api shutdown")
}
