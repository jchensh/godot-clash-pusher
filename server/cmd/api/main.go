// Command api serves the V4 HTTP API: auth, profile, matchmaking, leaderboard.
//
// V4-S1: real implementation begins; exposes /v4/auth/{login,refresh} + /healthz.
// V4-S2 adds /v4/profile/{get,deck-update}; V4-S4 adds /v4/match/*; etc.
//
// Environment:
//
//	DB_URL       postgres://...                  required
//	JWT_SECRET   shared secret for HS256         required (no fallback)
//	API_PORT     listen port                     default 8080
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/economy"
	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	"github.com/jchensh/godot-clash-pusher/server/internal/profile"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

func main() {
	log.Printf("api boot [%s build %s]", version.V4Stage, version.Build)

	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		log.Fatal("api: DB_URL env var is required")
	}
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		log.Fatal("api: JWT_SECRET env var is required (no dev default — read PLAN_V4 §3)")
	}
	port := os.Getenv("API_PORT")
	if port == "" {
		port = "8080"
	}

	rootCtx := context.Background()
	db, err := store.Open(rootCtx, dsn)
	if err != nil {
		log.Fatalf("api: open db: %v", err)
	}
	defer db.Close()
	if err := db.Ping(rootCtx); err != nil {
		log.Fatalf("api: ping db: %v", err)
	}

	issuer, err := auth.NewIssuer([]byte(jwtSecret))
	if err != nil {
		log.Fatalf("api: build jwt issuer: %v", err)
	}
	authH := auth.NewHandler(auth.NewAccountRepo(db.Pool), issuer)
	authMW := auth.NewMiddleware(issuer)
	profileH := profile.NewHandler(profile.NewRepo(db.Pool))

	// V5-N3/N4 (决策 48)：服务器权威经济。从同一 config/ 读配置算成本（双份同源）。
	cfgDir := os.Getenv("CONFIG_DIR")
	if cfgDir == "" {
		cfgDir = "/app/config"
	}
	bundle, err := gameconfig.Load(cfgDir)
	if err != nil {
		log.Fatalf("api: load config (%s): %v", cfgDir, err)
	}
	econCfg, err := economy.ParseConfig(bundle)
	if err != nil {
		log.Fatalf("api: parse economy config: %v", err)
	}
	economyH := economy.NewHandler(economy.NewRepo(db), econCfg)
	log.Printf("api: economy config loaded (%d cards, cfg ver=%s)", len(econCfg.Cards), bundle.Version)

	mux := http.NewServeMux()
	authH.Mount(mux)
	profileH.Mount(mux, authMW)
	economyH.Mount(mux, authMW)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		if err := db.Ping(r.Context()); err != nil {
			http.Error(w, "db down", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(rootCtx, syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	go func() {
		log.Printf("api listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("api: listen: %v", err)
		}
	}()
	<-ctx.Done()

	log.Println("api shutdown")
	shutdownCtx, shutdownCancel := context.WithTimeout(rootCtx, 10*time.Second)
	defer shutdownCancel()
	_ = srv.Shutdown(shutdownCtx)
}
