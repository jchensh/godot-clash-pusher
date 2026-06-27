package session

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbsession "github.com/jchensh/godot-clash-pusher/server/internal/pb/session"
	"google.golang.org/protobuf/proto"
)

var testUpgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

// wsServer spins up an httptest WS endpoint that runs Manager.Serve for a fixed account.
func wsServer(t *testing.T, m *Manager, accountID int64, bundle *gameconfig.Bundle) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ws, err := testUpgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		m.Serve(context.Background(), ws, accountID, r.URL.Query().Get("cfgver"), bundle)
	}))
}

func dial(t *testing.T, srv *httptest.Server, cfgver string) *websocket.Conn {
	t.Helper()
	url := "ws" + strings.TrimPrefix(srv.URL, "http") + "/?cfgver=" + cfgver
	c, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	return c
}

func readFrame(t *testing.T, c *websocket.Conn) (pbcommon.MsgId, []byte) {
	t.Helper()
	_ = c.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, data, err := c.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	mid, pl, ok := decodeFrame(data)
	if !ok {
		t.Fatal("short frame")
	}
	return mid, pl
}

func TestServe_PushesConfigThenHeartbeats(t *testing.T) {
	m := NewManager()
	bundle := &gameconfig.Bundle{Version: "abc", Payload: []byte(`{"cards.json":{}}`)}
	srv := wsServer(t, m, 7, bundle)
	defer srv.Close()

	c := dial(t, srv, "") // no cached version → full bundle
	defer c.Close()

	mid, pl := readFrame(t, c)
	if mid != pbcommon.MsgId_CONFIG_PUSH {
		t.Fatalf("first frame should be CONFIG_PUSH, got %d", mid)
	}
	var cp pbsession.ConfigPush
	if err := proto.Unmarshal(pl, &cp); err != nil {
		t.Fatal(err)
	}
	if cp.GetVersion() != "abc" || cp.GetUpToDate() || string(cp.GetBundle()) != `{"cards.json":{}}` {
		t.Fatalf("config push: %+v", &cp)
	}

	// heartbeat: client PING → server PONG
	if err := c.WriteMessage(websocket.BinaryMessage, encodeFrame(pbcommon.MsgId_PING, nil)); err != nil {
		t.Fatal(err)
	}
	if mid2, _ := readFrame(t, c); mid2 != pbcommon.MsgId_PONG {
		t.Fatalf("heartbeat should PONG, got %d", mid2)
	}
}

func TestServe_UpToDateSkipsBundle(t *testing.T) {
	m := NewManager()
	bundle := &gameconfig.Bundle{Version: "abc", Payload: []byte(`{"big":"payload"}`)}
	srv := wsServer(t, m, 7, bundle)
	defer srv.Close()

	c := dial(t, srv, "abc") // client already has version abc
	defer c.Close()

	_, pl := readFrame(t, c)
	var cp pbsession.ConfigPush
	_ = proto.Unmarshal(pl, &cp)
	if !cp.GetUpToDate() || len(cp.GetBundle()) != 0 {
		t.Fatalf("up-to-date client should not get bundle: %+v", &cp)
	}
}

func TestServe_NewLoginEvictsOld(t *testing.T) {
	m := NewManager()
	bundle := &gameconfig.Bundle{Version: "v", Payload: []byte("{}")}
	srv := wsServer(t, m, 7, bundle)
	defer srv.Close()

	c1 := dial(t, srv, "")
	defer c1.Close()
	readFrame(t, c1) // config push
	waitFor(t, func() bool { return m.Count() == 1 })

	c2 := dial(t, srv, "")
	defer c2.Close()
	readFrame(t, c2) // config push

	// c1 (same account) should be evicted → its socket closes.
	_ = c1.SetReadDeadline(time.Now().Add(2 * time.Second))
	if _, _, err := c1.ReadMessage(); err == nil {
		t.Fatal("old connection should be evicted/closed by new login")
	}
	waitFor(t, func() bool { return m.Count() == 1 }) // exactly one live (c2)
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("condition not met within timeout")
}
