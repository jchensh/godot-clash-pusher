// Command gateway is the V4 WebSocket entry point: JWT auth + lockstep battle
// relay (V4-S3). Clients connect to /v4/battle/ws?token=<access>, send a
// JoinRoomReq, get paired, and play a lockstep match (see internal/battle).
//
// Environment:
//
//	DB_URL        postgres://...            required (match persistence)
//	JWT_SECRET    HS256 secret             required (no fallback)
//	GATEWAY_PORT  listen port              default 8081
//	LADDER_LEVEL  ladder level config id   default ladder_01
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

	"github.com/gorilla/websocket"
	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/battle"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"github.com/jchensh/godot-clash-pusher/server/internal/version"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	// S3 玩法验证：允许任意来源（Godot 客户端无 Origin 头）。生产收紧留 V4-S8。
	CheckOrigin: func(r *http.Request) bool { return true },
}

func main() {
	log.Printf("gateway boot [%s build %s]", version.V4Stage, version.Build)

	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		log.Fatal("gateway: DB_URL env var is required")
	}
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		log.Fatal("gateway: JWT_SECRET env var is required (no dev default — read PLAN_V4 §3)")
	}
	port := os.Getenv("GATEWAY_PORT")
	if port == "" {
		port = "8081"
	}
	levelID := os.Getenv("LADDER_LEVEL")
	if levelID == "" {
		levelID = "ladder_01"
	}

	rootCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	db, err := store.Open(rootCtx, dsn)
	if err != nil {
		log.Fatalf("gateway: open db: %v", err)
	}
	defer db.Close()
	if err := db.Ping(rootCtx); err != nil {
		log.Fatalf("gateway: ping db: %v", err)
	}

	issuer, err := auth.NewIssuer([]byte(jwtSecret))
	if err != nil {
		log.Fatalf("gateway: build jwt issuer: %v", err)
	}
	hub := battle.NewHub(battle.NewPGPersister(db), levelID)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /v4/battle/ws", func(w http.ResponseWriter, r *http.Request) {
		claims, err := issuer.Verify(r.URL.Query().Get("token"), auth.KindAccess)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		summary := fetchSummary(r.Context(), db, claims.AccountID)
		ws, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return // Upgrade already wrote the error response
		}
		hub.Serve(rootCtx, ws, claims.AccountID, summary)
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		if err := db.Ping(r.Context()); err != nil {
			http.Error(w, "db down", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	srv := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		log.Printf("gateway listening on :%s (ladder level %s)", port, levelID)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("gateway: listen: %v", err)
		}
	}()
	<-rootCtx.Done()

	log.Println("gateway shutdown")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}

// fetchSummary loads a lightweight opponent card from profiles. Returns a
// minimal summary (just the id) if the row is missing — never blocks a match.
func fetchSummary(ctx context.Context, db *store.DB, accountID int64) *pbcommon.ProfileSummary {
	s := &pbcommon.ProfileSummary{AccountId: accountID}
	_ = db.Pool.QueryRow(ctx, `
		SELECT nickname, avatar_id, level, trophies FROM profiles WHERE account_id = $1
	`, accountID).Scan(&s.Nickname, &s.AvatarId, &s.Level, &s.Trophies)
	return s
}
