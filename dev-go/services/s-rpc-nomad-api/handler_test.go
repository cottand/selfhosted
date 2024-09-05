package module

import (
	"context"
	"strings"
	"testing"
)

func TestEvalNixJobJSON(t *testing.T) {
	res, err := evalNixJobJSON(context.Background(),
		"dev-go/services/job.nix",
		"7b43cbe3275cef8dd514c12ba137bd98c85da6e6",
		"7b43cbe",
		nil,
	)
	if err != nil {
		t.Fatal(err.Error())
	}
	if !strings.Contains(res, `"job":`) {
		t.Fatalf("expected to find JSON key in job render, but did not")
	}
}
