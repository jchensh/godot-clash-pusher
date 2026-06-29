package session

import (
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	pbsession "github.com/jchensh/godot-clash-pusher/server/internal/pb/session"
)

func TestManager_RegisterEvictsOlder(t *testing.T) {
	m := NewManager()
	s1 := newSession(7)
	if ev := m.register(s1); ev != nil {
		t.Fatal("first register should evict nothing")
	}
	if m.Count() != 1 || m.Get(7) != s1 {
		t.Fatal("s1 should be the live session")
	}
	s2 := newSession(7)
	if ev := m.register(s2); ev != s1 {
		t.Fatal("second register should evict s1")
	}
	if m.Count() != 1 || m.Get(7) != s2 {
		t.Fatal("s2 should now be the live session (count stays 1)")
	}
}

func TestManager_UnregisterOnlyIfCurrent(t *testing.T) {
	m := NewManager()
	s1 := newSession(7)
	m.register(s1)
	s2 := newSession(7)
	m.register(s2) // s1 evicted, s2 current
	m.unregister(s1) // stale → no-op
	if m.Get(7) != s2 {
		t.Fatal("stale unregister must not drop the current session")
	}
	m.unregister(s2) // current → removed
	if m.Get(7) != nil || m.Count() != 0 {
		t.Fatal("current session should be removed")
	}
}

func TestManager_MultipleAccounts(t *testing.T) {
	m := NewManager()
	m.register(newSession(1))
	m.register(newSession(2))
	if m.Count() != 2 {
		t.Fatalf("want 2 accounts online, got %d", m.Count())
	}
}

func TestSession_StopIdempotent(t *testing.T) {
	s := newSession(1)
	s.stop()
	s.stop() // must not panic (closeOnce)
	select {
	case <-s.quit:
	default:
		t.Fatal("quit should be closed after stop")
	}
}

func TestBuildConfigPush(t *testing.T) {
	// nil bundle → empty push
	p0 := buildConfigPush("", nil).(*pbsession.ConfigPush)
	if p0.GetVersion() != "" || p0.GetUpToDate() || len(p0.GetBundle()) != 0 {
		t.Fatalf("nil bundle should be empty: %+v", p0)
	}

	b := &gameconfig.Bundle{Version: "v1", Payload: []byte(`{"a":1}`)}
	// outdated client → full bundle
	p1 := buildConfigPush("old", b).(*pbsession.ConfigPush)
	if p1.GetVersion() != "v1" || p1.GetUpToDate() || string(p1.GetBundle()) != `{"a":1}` {
		t.Fatalf("outdated client should get full bundle: %+v", p1)
	}
	// up-to-date client → version only, no bundle
	p2 := buildConfigPush("v1", b).(*pbsession.ConfigPush)
	if p2.GetVersion() != "v1" || !p2.GetUpToDate() || len(p2.GetBundle()) != 0 {
		t.Fatalf("up-to-date client should skip bundle: %+v", p2)
	}
	// empty cfgver → always full
	p3 := buildConfigPush("", b).(*pbsession.ConfigPush)
	if p3.GetUpToDate() || string(p3.GetBundle()) != `{"a":1}` {
		t.Fatalf("empty cfgver should get full bundle: %+v", p3)
	}
}
