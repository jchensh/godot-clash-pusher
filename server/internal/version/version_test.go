package version

import "testing"

func TestVersionConstants(t *testing.T) {
	if V4Stage == "" {
		t.Fatal("V4Stage must not be empty")
	}
	if Build == "" {
		t.Fatal("Build must not be empty")
	}
}
