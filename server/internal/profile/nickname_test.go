package profile

import (
	"errors"
	"testing"
)

// V5-S9：昵称宽度校验（服务器权威）——中文/全角=1、英数=0.5，上限 10（=20 半格）。
func TestValidateNickname(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		wantErr bool
		want    string
	}{
		{"empty", "", true, ""},
		{"spaces only", "   ", true, ""},
		{"trims surrounding spaces", "  Bob  ", false, "Bob"},
		{"ten cjk ok", "一二三四五六七八九十", false, "一二三四五六七八九十"},
		{"eleven cjk too long", "一二三四五六七八九十一", true, ""},
		{"twenty ascii ok", "abcdefghijklmnopqrst", false, "abcdefghijklmnopqrst"},
		{"twentyone ascii too long", "abcdefghijklmnopqrstu", true, ""},
		{"mixed cjk+ascii", "勇者A1", false, "勇者A1"},
		{"control char rejected", "ab\ncd", true, ""},
	}
	for _, c := range cases {
		got, err := validateNickname(c.in)
		if c.wantErr {
			if !errors.Is(err, ErrNicknameInvalid) {
				t.Errorf("%s: want ErrNicknameInvalid, got %v", c.name, err)
			}
			continue
		}
		if err != nil {
			t.Errorf("%s: unexpected err %v", c.name, err)
			continue
		}
		if got != c.want {
			t.Errorf("%s: got %q want %q", c.name, got, c.want)
		}
	}
}
