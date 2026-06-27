// Command battle hosts lockstep battle rooms; one goroutine per match.
//
// V4-S0c: scaffold placeholder with signal-driven shutdown.
// Real implementation in V4-S3.
// May be merged into gateway as a sub-routine in early stages (see PLAN_V4 §3).
package main

import (
	"context"
	"log"
	"os/signal"
	"syscall"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("battle boot [%s build %s] — placeholder, idling until SIGINT/SIGTERM", version.V4Stage, version.Build)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	log.Println("battle shutdown")
}
