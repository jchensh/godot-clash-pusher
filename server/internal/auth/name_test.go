package auth

// KAN-109 username 校验单测：宽度规则须与 profile.validateNickname 同口径
// （username 即昵称）。跨包一致性由 name_integration_test 的注册→拉档流程隐式覆盖。

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateUsername_AcceptsAndTrims(t *testing.T) {
	got, err := validateUsername("  陈到·叔至  ")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got != "陈到·叔至" {
		t.Fatalf("want trimmed, got %q", got)
	}
}

func TestValidateUsername_WidthBudget(t *testing.T) {
	// 10 个全角 = 正好 20 半格，通过；11 个 = 超限。
	if _, err := validateUsername(strings.Repeat("汉", 10)); err != nil {
		t.Fatalf("10 wide should pass: %v", err)
	}
	if _, err := validateUsername(strings.Repeat("汉", 11)); !errors.Is(err, ErrUsernameInvalid) {
		t.Fatalf("11 wide should fail, got %v", err)
	}
	// 20 个窄字符 = 20 半格通过；21 个超限。
	if _, err := validateUsername(strings.Repeat("a", 20)); err != nil {
		t.Fatalf("20 narrow should pass: %v", err)
	}
	if _, err := validateUsername(strings.Repeat("a", 21)); !errors.Is(err, ErrUsernameInvalid) {
		t.Fatalf("21 narrow should fail, got %v", err)
	}
}

func TestValidateUsername_RejectsEmptyAndControl(t *testing.T) {
	for _, bad := range []string{"", "   ", "a\x01b", "a\x7fb"} {
		if _, err := validateUsername(bad); !errors.Is(err, ErrUsernameInvalid) {
			t.Fatalf("%q should be invalid, got %v", bad, err)
		}
	}
}
