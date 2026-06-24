package profile_test

// Integration test: requires a real Postgres reachable via INTEGRATION_DB_URL.
// Default `go test ./...` skips it; run with:
//
//   INTEGRATION_DB_URL=postgres://app:dev@localhost:5432/gcp?sslmode=disable \
//       go test -v ./internal/profile/...
//
// docker-compose already exposes 5432; just `make up` + `make migrate` first.
//
// NOTE: these tests share one live DB with the auth integration tests and clean
// the tables on setup. Running BOTH packages at once must serialize with -p 1
// (otherwise `go test` runs the two packages in parallel and they wipe each
// other's rows): go test -p 1 ./internal/auth/... ./internal/profile/...

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/auth"
	"github.com/jchensh/godot-clash-pusher/server/internal/httpx"
	pbauth "github.com/jchensh/godot-clash-pusher/server/internal/pb/auth"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbprofile "github.com/jchensh/godot-clash-pusher/server/internal/pb/profile"
	"github.com/jchensh/godot-clash-pusher/server/internal/profile"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
	"google.golang.org/protobuf/proto"
)

var fullDeck = []string{"knight", "archer", "fireball", "giant", "goblins", "musketeer", "minions", "cannon"}

// newTestServer cleans the tables and serves auth + profile routes against a
// real DB, so the test exercises the actual middleware + repo + Postgres path.
func newTestServer(t *testing.T) *httptest.Server {
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
	for _, tbl := range []string{"matches", "decks", "profiles", "accounts"} {
		if _, err := db.Pool.Exec(ctx, "DELETE FROM "+tbl); err != nil {
			t.Fatalf("cleanup %s: %v", tbl, err)
		}
	}

	iss, _ := auth.NewIssuer([]byte("test-secret-for-integration"))
	authH := auth.NewHandler(auth.NewAccountRepo(db.Pool), iss)
	authMW := auth.NewMiddleware(iss)
	profileH := profile.NewHandler(profile.NewRepo(db.Pool))

	mux := http.NewServeMux()
	authH.Mount(mux)
	profileH.Mount(mux, authMW)
	srv := httptest.NewServer(mux)
	t.Cleanup(func() {
		srv.Close()
		db.Close()
	})
	return srv
}

func postProto(t *testing.T, url string, m proto.Message) (int, []byte) {
	return postProtoAuth(t, url, "", m)
}

// postProtoAuth POSTs a protobuf body, attaching a Bearer token when non-empty.
func postProtoAuth(t *testing.T, url, token string, m proto.Message) (int, []byte) {
	t.Helper()
	body, err := proto.Marshal(m)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", httpx.ContentTypeProtobuf)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s: %v", url, err)
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, out
}

// login bootstraps an access token for deviceID.
func login(t *testing.T, srvURL, deviceID string) string {
	t.Helper()
	status, body := postProto(t, srvURL+"/v4/auth/login", &pbauth.LoginReq{DeviceId: deviceID, ClientVersion: "0.4.0", Platform: "test"})
	if status != http.StatusOK {
		t.Fatalf("login status=%d body=%s", status, body)
	}
	var resp pbauth.LoginResp
	if err := proto.Unmarshal(body, &resp); err != nil {
		t.Fatalf("unmarshal LoginResp: %v", err)
	}
	if resp.Token == "" {
		t.Fatal("login returned empty access token")
	}
	return resp.Token
}

func decodeErr(t *testing.T, body []byte) pbcommon.ErrorCode {
	t.Helper()
	var er pbcommon.ErrorResp
	if err := proto.Unmarshal(body, &er); err != nil {
		t.Fatalf("unmarshal ErrorResp: %v", err)
	}
	return er.Code
}

func TestProfileGet_ReturnsSeededDefault(t *testing.T) {
	srv := newTestServer(t)
	token := login(t, srv.URL, "dev-prof-1")

	status, body := postProtoAuth(t, srv.URL+"/v4/profile/get", token, &pbprofile.ProfileGetReq{})
	if status != http.StatusOK {
		t.Fatalf("get status=%d body=%s", status, body)
	}
	var resp pbprofile.ProfileGetResp
	if err := proto.Unmarshal(body, &resp); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if resp.Profile == nil {
		t.Fatal("nil profile")
	}
	if resp.Profile.Version != 0 {
		t.Errorf("version=%d want 0", resp.Profile.Version)
	}
	if resp.Profile.Nickname == "" {
		t.Error("empty nickname")
	}
	if len(resp.Decks) != 0 {
		t.Errorf("decks=%d want 0 (no auto-seeding)", len(resp.Decks))
	}
	if len(resp.UnlockedCardIds) != 0 {
		t.Errorf("unlocked=%d want 0 (empty = all unlocked)", len(resp.UnlockedCardIds))
	}
}

func TestDeckUpdate_BumpsVersionAndPersists(t *testing.T) {
	srv := newTestServer(t)
	token := login(t, srv.URL, "dev-prof-2")

	status, body := postProtoAuth(t, srv.URL+"/v4/profile/deck-update", token, &pbprofile.DeckUpdateReq{
		Slot: 1, CardIds: fullDeck, SetActive: true, ExpectedVersion: 0,
	})
	if status != http.StatusOK {
		t.Fatalf("deck-update status=%d body=%s", status, body)
	}
	var resp pbprofile.DeckUpdateResp
	if err := proto.Unmarshal(body, &resp); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if !resp.Ok || resp.NewVersion != 1 {
		t.Fatalf("ok=%v new_version=%d, want ok=true ver=1", resp.Ok, resp.NewVersion)
	}

	// Re-fetch: deck persisted, marked active, profile version advanced.
	_, gbody := postProtoAuth(t, srv.URL+"/v4/profile/get", token, &pbprofile.ProfileGetReq{})
	var gresp pbprofile.ProfileGetResp
	if err := proto.Unmarshal(gbody, &gresp); err != nil {
		t.Fatalf("unmarshal get: %v", err)
	}
	if len(gresp.Decks) != 1 {
		t.Fatalf("decks=%d want 1", len(gresp.Decks))
	}
	d := gresp.Decks[0]
	if d.Slot != 1 || !d.IsActive || len(d.CardIds) != 8 {
		t.Errorf("deck unexpected: slot=%d active=%v ncards=%d", d.Slot, d.IsActive, len(d.CardIds))
	}
	if gresp.Profile.Version != 1 {
		t.Errorf("profile version=%d want 1", gresp.Profile.Version)
	}
}

func TestDeckUpdate_StaleVersionConflict(t *testing.T) {
	srv := newTestServer(t)
	token := login(t, srv.URL, "dev-prof-3")

	// First update: version 0 -> 1.
	st, body := postProtoAuth(t, srv.URL+"/v4/profile/deck-update", token, &pbprofile.DeckUpdateReq{Slot: 1, CardIds: fullDeck, ExpectedVersion: 0})
	if st != http.StatusOK {
		t.Fatalf("first update status=%d body=%s", st, body)
	}
	// Second update still claims version 0 -> stale -> 409.
	st2, body2 := postProtoAuth(t, srv.URL+"/v4/profile/deck-update", token, &pbprofile.DeckUpdateReq{Slot: 1, CardIds: fullDeck, ExpectedVersion: 0})
	if st2 != http.StatusConflict {
		t.Fatalf("stale update status=%d want 409", st2)
	}
	if code := decodeErr(t, body2); code != pbcommon.ErrorCode_ERR_PROFILE_VERSION_MISMATCH {
		t.Errorf("code=%v want ERR_PROFILE_VERSION_MISMATCH", code)
	}
}

func TestDeckUpdate_InvalidDeckRejected(t *testing.T) {
	srv := newTestServer(t)
	token := login(t, srv.URL, "dev-prof-4")

	short := []string{"knight", "archer", "fireball"} // 3, not 8
	st, body := postProtoAuth(t, srv.URL+"/v4/profile/deck-update", token, &pbprofile.DeckUpdateReq{Slot: 1, CardIds: short, ExpectedVersion: 0})
	if st != http.StatusBadRequest {
		t.Fatalf("status=%d want 400", st)
	}
	if code := decodeErr(t, body); code != pbcommon.ErrorCode_ERR_PROFILE_DECK_INVALID {
		t.Errorf("code=%v want ERR_PROFILE_DECK_INVALID", code)
	}
}

func TestProfile_RequiresAuth(t *testing.T) {
	srv := newTestServer(t)
	st, _ := postProto(t, srv.URL+"/v4/profile/get", &pbprofile.ProfileGetReq{})
	if st != http.StatusUnauthorized {
		t.Errorf("no-token status=%d want 401", st)
	}
}

func TestProfile_RejectsBadToken(t *testing.T) {
	srv := newTestServer(t)
	st, _ := postProtoAuth(t, srv.URL+"/v4/profile/get", "not.a.valid.jwt", &pbprofile.ProfileGetReq{})
	if st != http.StatusUnauthorized {
		t.Errorf("bad-token status=%d want 401", st)
	}
}
