// Package gameconfig loads the server-authoritative game config (config/*.json)
// into a versioned bundle. 决策 48 / V5-N2：配置以服务器为权威源，登录后下发给客户端。
package gameconfig

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Bundle is the versioned set of config/*.json files.
type Bundle struct {
	Version string                     // sha256(payload) 前 16 hex；内容不变则版本稳定
	Payload []byte                     // JSON：{"cards.json":{...},"units.json":{...},...}（文件名升序，确定性）
	files   map[string]json.RawMessage // 单文件查询（服务器侧结算用，N4+）
}

// Load reads every *.json under dir into a versioned bundle. Deterministic
// (filenames sorted, raw bytes trimmed) so the version is stable across restarts
// for identical content.
func Load(dir string) (*Bundle, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read config dir %s: %w", dir, err)
	}
	var names []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".json") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	if len(names) == 0 {
		return nil, fmt.Errorf("no *.json under %s", dir)
	}

	files := make(map[string]json.RawMessage, len(names))
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, n := range names {
		raw, err := os.ReadFile(filepath.Join(dir, n))
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", n, err)
		}
		raw = bytes.TrimSpace(raw)
		if !json.Valid(raw) {
			return nil, fmt.Errorf("invalid json: %s", n)
		}
		files[n] = json.RawMessage(raw)
		if i > 0 {
			buf.WriteByte(',')
		}
		key, _ := json.Marshal(n)
		buf.Write(key)
		buf.WriteByte(':')
		buf.Write(raw)
	}
	buf.WriteByte('}')

	payload := append([]byte(nil), buf.Bytes()...)
	sum := sha256.Sum256(payload)
	return &Bundle{
		Version: hex.EncodeToString(sum[:])[:16],
		Payload: payload,
		files:   files,
	}, nil
}

// File returns one config file's raw JSON (server-side settlement reads this, N4+).
func (b *Bundle) File(name string) (json.RawMessage, bool) {
	v, ok := b.files[name]
	return v, ok
}

// FileCount returns how many config files are bundled.
func (b *Bundle) FileCount() int { return len(b.files) }
