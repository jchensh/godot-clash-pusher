// Command gateway is the V4 WebSocket entry point + auth + routing.
//
// V4-S0c: scaffold placeholder with signal-driven shutdown.
// Real implementation in V4-S3 (lockstep battle).
package main

import (
	"context"
	"log"
	"os/signal"
	"syscall"

	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("gateway boot [%s build %s] — placeholder, idling until SIGINT/SIGTERM", version.V4Stage, version.Build)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	log.Println("gateway shutdown")
}
