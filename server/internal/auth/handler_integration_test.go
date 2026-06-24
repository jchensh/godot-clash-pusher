package auth_test

// Integration test: requires a real Postgres reachable via INTEGRATION_DB_URL.
// Default `go test ./...` skips it; run with:
//
//   INTEGRATION_DB_URL=postgres://app:dev@localhost:5432/gcp?sslmode=disable \
//       go test -v ./internal/auth/...
//
// docker-compose already exposes 5432; just `make up` first.

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	authsvc "github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbauth "github.com/jchensh/godot-clash-pusher/server/internal/pb/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"google.golang.org/protobuf/proto"
)

func setupIntegration(t *testing.T) (*store.DB, *httptest.Server, context.Context) {
	t.Helper()
	dsn := os.Getenv("INTEGRATION_DB_URL")
	if dsn == "" {
		t.Skip("INTEGRATION_DB_URL not set; skipping integration test")
	}
	ctx := context.Background()
	db, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatalf("Open db: %v", err)
	}
	// Clean prior runs (FK children before parents) so the test is deterministic.
	for _, tbl := range []string{"matches", "decks", "profiles", "accounts"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("cleanup %s: %v", tbl, err)
		}
	}

	iss, _ := authsvc.NewIssuer([]byte("test-secret-for-integration"))
	h := authsvc.NewHandler(authsvc.NewAccountRepo(db.Pool), iss)
	mux := http.NewServeMux()
	h.Mount(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(func() {
		srv.Close()
		db.Close()
	})
	return db, srv, ctx
}

func postProto(t *testing.T, url string, m proto.Message) (int, []byte) {
	t.Helper()
	body, err := proto.Marshal(m)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	resp, err := http.Post(url, httpx.ContentTypeProtobuf, bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST %s: %v", url, err)
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, out
}

func TestLogin_CreatesAccountAndProfile(t *testing.T) {
	db, srv, ctx := setupIntegration(t)
	req := &pbauth.LoginReq{DeviceId: "dev-int-1", ClientVersion: "0.4.0", Platform: "test"}
	status, body := postProto(t, srv.URL+"/v4/auth/login", req)
	if status != http.StatusOK {
		t.Fatalf("login status = %d, body=%s", status, body)
	}
	var resp pbauth.LoginResp
	if err := proto.Unmarshal(body, &resp); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if resp.Token == "" || resp.RefreshToken == "" {
		t.Errorf("empty tokens: %+v", &resp)
	}
	// Row exists, profile seeded.
	var nAcc, nProf int
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM accounts WHERE external_id = 'dev-int-1'").Scan(&nAcc)
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM profiles WHERE nickname LIKE 'Player%'").Scan(&nProf)
	if nAcc != 1 {
		t.Errorf("accounts count = %d, want 1", nAcc)
	}
	if nProf != 1 {
		t.Errorf("profiles count = %d, want 1", nProf)
	}
}

func TestLogin_IdempotentForSameDevice(t *testing.T) {
	db, srv, ctx := setupIntegration(t)
	req := &pbauth.LoginReq{DeviceId: "dev-int-2", ClientVersion: "0.4.0", Platform: "test"}
	postProto(t, srv.URL+"/v4/auth/login", req)
	postProto(t, srv.URL+"/v4/auth/login", req) // second call must not duplicate
	var n int
	_ = db.Pool.QueryRow(ctx, "SELECT COUNT(*) FROM accounts WHERE external_id = 'dev-int-2'").Scan(&n)
	if n != 1 {
		t.Errorf("expected 1 row after 2 logins, got %d", n)
	}
}

func TestRefresh_RoundTrip(t *testing.T) {
	_, srv, _ := setupIntegration(t)
	// Login first.
	loginReq := &pbauth.LoginReq{DeviceId: "dev-int-3", ClientVersion: "0.4.0", Platform: "test"}
	_, body := postProto(t, srv.URL+"/v4/auth/login", loginReq)
	var loginResp pbauth.LoginResp
	_ = proto.Unmarshal(body, &loginResp)
	// Refresh with the refresh token.
	refReq := &pbauth.RefreshReq{RefreshToken: loginResp.RefreshToken}
	status, body2 := postProto(t, srv.URL+"/v4/auth/refresh", refReq)
	if status != http.StatusOK {
		t.Fatalf("refresh status = %d, body=%s", status, body2)
	}
	var refResp pbauth.RefreshResp
	if err := proto.Unmarshal(body2, &refResp); err != nil {
		t.Fatalf("Unmarshal RefreshResp: %v", err)
	}
	if refResp.Token == "" {
		t.Error("refresh produced empty access token")
	}
}

func TestRefresh_RejectsAccessTokenInRefreshField(t *testing.T) {
	_, srv, _ := setupIntegration(t)
	loginReq := &pbauth.LoginReq{DeviceId: "dev-int-4", ClientVersion: "0.4.0", Platform: "test"}
	_, body := postProto(t, srv.URL+"/v4/auth/login", loginReq)
	var loginResp pbauth.LoginResp
	_ = proto.Unmarshal(body, &loginResp)
	// Use the ACCESS token as if it were a refresh token — must be rejected.
	refReq := &pbauth.RefreshReq{RefreshToken: loginResp.Token}
	status, _ := postProto(t, srv.URL+"/v4/auth/refresh", refReq)
	if status != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", status)
	}
}
