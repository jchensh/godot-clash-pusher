// Command verifier is the KAN-79 PVE replay verifier: it polls pve_battles for
// consumed-but-unverified battles, replays each one in a headless Godot child
// process (tools/pve_verify.gd — the same deterministic logic/ the clients run),
// and writes the verdict back. A mismatch means the client's reported hashes /
// claims cannot be reproduced from its own command stream → shadow-flag the
// account (ban_status=1). 玩法验证期只记不罚：不回滚经济、不拒服务。
//
// Environment:
//
//	DB_URL              postgres://...    required
//	CONFIG_DIR          /app/config       economy.json anticheat.verify_sample_rate
//	GODOT_BIN           godot binary path (default /usr/local/bin/godot)
//	PROJECT_DIR         godot project root (default /work/project)
//	VERIFY_INTERVAL_S   poll interval seconds (default 5)
package main

import (
	"context"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"github.com/jchensh/godot-clash-pusher/server/internal/verify"
	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("verifier boot [%s build %s]", version.V4Stage, version.Build)

	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		log.Fatal("verifier: DB_URL env var is required")
	}
	cfgDir := os.Getenv("CONFIG_DIR")
	if cfgDir == "" {
		cfgDir = "/app/config"
	}
	godotBin := os.Getenv("GODOT_BIN")
	if godotBin == "" {
		godotBin = "/usr/local/bin/godot"
	}
	projectDir := os.Getenv("PROJECT_DIR")
	if projectDir == "" {
		projectDir = "/work/project"
	}
	interval := 5 * time.Second
	if s := os.Getenv("VERIFY_INTERVAL_S"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 {
			interval = time.Duration(n) * time.Second
		}
	}

	rootCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	db, err := store.Open(rootCtx, dsn)
	if err != nil {
		log.Fatalf("verifier: open db: %v", err)
	}
	defer db.Close()

	sampleRate := 1.0
	if bundle, err := gameconfig.Load(cfgDir); err != nil {
		log.Printf("verifier: config load (%s): %v — sample rate defaults to 1.0", cfgDir, err)
	} else if econCfg, err := economy.ParseConfig(bundle); err != nil {
		log.Printf("verifier: parse economy config: %v — sample rate defaults to 1.0", err)
	} else {
		sampleRate = econCfg.Anticheat.VerifySampleRate
	}

	w := verify.NewWorker(db, verify.GodotRunner(godotBin, projectDir), sampleRate, rand.Float64)
	log.Printf("verifier: polling every %s (sample rate %.2f, godot=%s, project=%s)", interval, sampleRate, godotBin, projectDir)

	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-rootCtx.Done():
			log.Println("verifier shutdown")
			return
		case <-t.C:
			// Drain the queue each tick (one battle at a time, SKIP LOCKED-safe).
			for {
				did, err := w.VerifyOne(rootCtx)
				if err != nil {
					log.Printf("verifier: %v", err)
					break
				}
				if !did {
					break
				}
			}
		}
	}
}
