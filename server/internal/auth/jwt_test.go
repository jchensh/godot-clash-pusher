package auth

import (
	"strings"
	"testing"
	"time"
)

func TestNewIssuer_RejectsEmptySecret(t *testing.T) {
	if _, err := NewIssuer(nil); err == nil {
		t.Error("expected error for nil secret")
	}
	if _, err := NewIssuer([]byte{}); err == nil {
		t.Error("expected error for empty secret")
	}
}

func TestSignAccessRoundtrip(t *testing.T) {
	iss, err := NewIssuer([]byte("test-secret"))
	if err != nil {
		t.Fatalf("NewIssuer: %v", err)
	}
	now := time.Date(2026, 6, 24, 0, 0, 0, 0, time.UTC)
	tok, err := iss.SignAccess(42, now)
	if err != nil {
		t.Fatalf("SignAccess: %v", err)
	}
	// A JWT is three base64 segments joined by dots.
	if strings.Count(tok, ".") != 2 {
		t.Errorf("not a JWT: %q", tok)
	}
	c, err := iss.Verify(tok, KindAccess)
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if c.AccountID != 42 {
		t.Errorf("AccountID = %d, want 42", c.AccountID)
	}
	if c.Kind != KindAccess {
		t.Errorf("Kind = %q, want %q", c.Kind, KindAccess)
	}
}

func TestSignRefreshRoundtrip(t *testing.T) {
	iss, _ := NewIssuer([]byte("test-secret"))
	tok, _ := iss.SignRefresh(7, time.Now())
	c, err := iss.Verify(tok, KindRefresh)
	if err != nil {
		t.Fatalf("Verify refresh: %v", err)
	}
	if c.AccountID != 7 || c.Kind != KindRefresh {
		t.Errorf("bad claims: %+v", c)
	}
}

func TestVerify_WrongKindRejected(t *testing.T) {
	iss, _ := NewIssuer([]byte("test-secret"))
	tok, _ := iss.SignAccess(1, time.Now())
	if _, err := iss.Verify(tok, KindRefresh); err == nil {
		t.Error("access token must not pass as refresh")
	}
}

func TestVerify_ExpiredRejected(t *testing.T) {
	iss, _ := NewIssuer([]byte("test-secret"))
	// Issue a token "31 days ago" -> exceeds default 30d access TTL.
	long := time.Now().Add(-31 * 24 * time.Hour)
	tok, _ := iss.SignAccess(1, long)
	if _, err := iss.Verify(tok, KindAccess); err == nil {
		t.Error("expired token must be rejected")
	}
}

func TestVerify_WrongSecretRejected(t *testing.T) {
	iss1, _ := NewIssuer([]byte("secret-one"))
	iss2, _ := NewIssuer([]byte("secret-two"))
	tok, _ := iss1.SignAccess(1, time.Now())
	if _, err := iss2.Verify(tok, KindAccess); err == nil {
		t.Error("token signed by issuer1 must not verify with issuer2's secret")
	}
}

func TestVerify_EmptyExpectKindAccepts(t *testing.T) {
	// expectKind="" is the middleware path: caller doesn't care which kind.
	iss, _ := NewIssuer([]byte("test-secret"))
	tok, _ := iss.SignAccess(1, time.Now())
	if _, err := iss.Verify(tok, ""); err != nil {
		t.Errorf("verify with empty expectKind should accept: %v", err)
	}
}

func TestSetTTLs_TakesEffect(t *testing.T) {
	iss, _ := NewIssuer([]byte("test-secret"))
	iss.SetTTLs(1*time.Second, 2*time.Second)
	// Signed 5s ago with 1s TTL -> must be expired.
	tok, _ := iss.SignAccess(1, time.Now().Add(-5*time.Second))
	if _, err := iss.Verify(tok, KindAccess); err == nil {
		t.Error("token past custom TTL should be rejected")
	}
}
