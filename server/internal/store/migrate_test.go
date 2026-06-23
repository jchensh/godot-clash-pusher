package store

import (
	"testing"
	"testing/fstest"
)

func TestParseMigrationFilename(t *testing.T) {
	cases := []struct {
		name        string
		wantVersion int
		wantLabel   string
		wantOK      bool
	}{
		{"0001_init.up.sql", 1, "init", true},
		{"0002_accounts.up.sql", 2, "accounts", true},
		{"0042_long_name_with_underscores.up.sql", 42, "long_name_with_underscores", true},
		{"0001_init.down.sql", 0, "", false},  // down 文件不算 up
		{"0001_init.sql", 0, "", false},       // 缺 .up
		{"init.up.sql", 0, "", false},         // 缺版本号
		{"1_init.up.sql", 0, "", false},       // 版本号不足 4 位
		{"00001_init.up.sql", 0, "", false},   // 版本号 5 位也不算 (严格)
		{"0001.up.sql", 0, "", false},         // 缺 label
		{"", 0, "", false},
	}
	for _, c := range cases {
		v, l, ok := ParseMigrationFilename(c.name)
		if v != c.wantVersion || l != c.wantLabel || ok != c.wantOK {
			t.Errorf("ParseMigrationFilename(%q) = (%d, %q, %v); want (%d, %q, %v)",
				c.name, v, l, ok, c.wantVersion, c.wantLabel, c.wantOK)
		}
	}
}

func TestReadMigrations_SortsAndFilters(t *testing.T) {
	fsys := fstest.MapFS{
		"migrations/0001_init.up.sql":     &fstest.MapFile{Data: []byte("CREATE TABLE foo();")},
		"migrations/0001_init.down.sql":   &fstest.MapFile{Data: []byte("DROP TABLE foo;")},
		"migrations/0003_third.up.sql":    &fstest.MapFile{Data: []byte("-- third")},
		"migrations/0002_accounts.up.sql": &fstest.MapFile{Data: []byte("CREATE TABLE accounts();")},
		"migrations/ignored.txt":          &fstest.MapFile{Data: []byte("not a migration")},
		"migrations/README.md":            &fstest.MapFile{Data: []byte("docs")},
	}
	migs, err := ReadMigrations(fsys, "migrations")
	if err != nil {
		t.Fatalf("ReadMigrations: %v", err)
	}
	if len(migs) != 3 {
		t.Fatalf("expected 3 migrations (0001 0002 0003), got %d", len(migs))
	}
	if migs[0].Version != 1 || migs[1].Version != 2 || migs[2].Version != 3 {
		t.Errorf("versions not sorted ascending: %d %d %d",
			migs[0].Version, migs[1].Version, migs[2].Version)
	}
	if migs[0].Name != "init" || migs[1].Name != "accounts" || migs[2].Name != "third" {
		t.Errorf("names wrong: %q %q %q", migs[0].Name, migs[1].Name, migs[2].Name)
	}
	for i, m := range migs {
		if m.SQL == "" {
			t.Errorf("migration %d SQL empty", i)
		}
	}
}

func TestReadMigrations_DuplicateVersionErrors(t *testing.T) {
	fsys := fstest.MapFS{
		"migrations/0001_init.up.sql":  &fstest.MapFile{Data: []byte("a")},
		"migrations/0001_other.up.sql": &fstest.MapFile{Data: []byte("b")},
	}
	_, err := ReadMigrations(fsys, "migrations")
	if err == nil {
		t.Error("expected error for duplicate version 0001")
	}
}

func TestReadMigrations_EmptyDir(t *testing.T) {
	fsys := fstest.MapFS{
		"migrations/.gitkeep": &fstest.MapFile{Data: []byte("")},
	}
	migs, err := ReadMigrations(fsys, "migrations")
	if err != nil {
		t.Fatalf("ReadMigrations: %v", err)
	}
	if len(migs) != 0 {
		t.Errorf("expected 0 migrations, got %d", len(migs))
	}
}

// TestReadMigrations_DotDir covers the production code path: cmd/migrate
// wraps os.DirFS(dir) and passes dir="." to Apply -> ReadMigrations. The
// io/fs convention forbids leading "./" in paths, so we must use path.Join.
func TestReadMigrations_DotDir(t *testing.T) {
	fsys := fstest.MapFS{
		"0001_init.up.sql":     &fstest.MapFile{Data: []byte("SELECT 1;")},
		"0002_accounts.up.sql": &fstest.MapFile{Data: []byte("CREATE TABLE accounts();")},
	}
	migs, err := ReadMigrations(fsys, ".")
	if err != nil {
		t.Fatalf("ReadMigrations(.): %v", err)
	}
	if len(migs) != 2 {
		t.Fatalf("expected 2 migrations, got %d", len(migs))
	}
	if migs[1].Name != "accounts" || migs[1].SQL == "" {
		t.Errorf("0002 not loaded correctly: %+v", migs[1])
	}
}
