package gameconfig_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
)

func write(t *testing.T, dir, name, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestLoad_VersionedBundle(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "a.json", `{"x":1}`)
	write(t, dir, "b.json", "  {\"y\":2}\n") // 带空白 → 应被 trim
	write(t, dir, "ignore.txt", "not config")

	b, err := gameconfig.Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	if b.FileCount() != 2 {
		t.Fatalf("want 2 json files, got %d", b.FileCount())
	}
	if b.Version == "" {
		t.Fatal("empty version")
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(b.Payload, &m); err != nil {
		t.Fatalf("payload not valid json: %v", err)
	}
	if _, ok := m["a.json"]; !ok {
		t.Fatal("payload missing a.json")
	}
	if _, ok := m["b.json"]; !ok {
		t.Fatal("payload missing b.json")
	}
	if raw, ok := b.File("a.json"); !ok || string(raw) != `{"x":1}` {
		t.Fatalf("File(a.json) = %q, %v", raw, ok)
	}
	if string(m["b.json"]) != `{"y":2}` {
		t.Fatalf("b.json not trimmed: %q", m["b.json"])
	}
}

func TestLoad_StableThenChanges(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "a.json", `{"x":1}`)
	b1, _ := gameconfig.Load(dir)
	b2, _ := gameconfig.Load(dir)
	if b1.Version != b2.Version {
		t.Fatal("version must be stable for identical content")
	}
	write(t, dir, "a.json", `{"x":2}`)
	b3, _ := gameconfig.Load(dir)
	if b3.Version == b1.Version {
		t.Fatal("version must change when content changes")
	}
}

func TestLoad_RejectsInvalidJSON(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "bad.json", `{not valid`)
	if _, err := gameconfig.Load(dir); err == nil {
		t.Fatal("want error on invalid json")
	}
}

func TestLoad_EmptyDir(t *testing.T) {
	if _, err := gameconfig.Load(t.TempDir()); err == nil {
		t.Fatal("want error when no *.json present")
	}
}

// 真实 config/（双份同源校验）：能加载、版本非空、含 cards.json。仓库无 config 时跳过。
func TestLoad_RealConfigDir(t *testing.T) {
	b, err := gameconfig.Load("../../../config")
	if err != nil {
		t.Skipf("real config dir not available: %v", err)
	}
	if _, ok := b.File("cards.json"); !ok {
		t.Fatal("real config missing cards.json")
	}
	if b.Version == "" {
		t.Fatal("real config empty version")
	}
}
