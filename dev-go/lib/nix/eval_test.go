package nix

import (
	"testing"
)

func TestEval42(t *testing.T) {
	str, err := EvalJson("{ answer = 42; }.answer", ".")
	if err != nil {
		t.Fatalf("error during eval: %v", err)
	}
	if str != "42" {
		t.Fatalf("error during eval: expected `42`, got `%v`", str)
	}
}

func TestEvalNested42(t *testing.T) {
	str, err := EvalJson("{ answer.nested.aa = 42; }", ".")
	if err != nil {
		t.Fatalf("error during eval: %v", err)
	}
	expected := `{"answer":{"nested":{"aa":42}}}`
	if str != expected {
		t.Fatalf("error during eval: expected `%v`, got `%v`", expected, str)
	}
}

func TestEvalPathExists(t *testing.T) {
	str, err := EvalJson("builtins.pathExists ./nix", "/")
	if err != nil {
		t.Fatalf("error during eval: %v", err)
	}
	if str != "true" {
		t.Fatalf("error during eval: expected `true`, got `%v`", str)
	}
}
