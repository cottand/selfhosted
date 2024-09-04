package nix

import (
	"os"
	"testing"
)

func inNixBuild() bool {
	return os.Getenv("NIX_BUILD_TOP") != ""
}

func TestEval42(t *testing.T) {
	if inNixBuild() {
		t.Skip("test requires non nix environment")
	}
	str, err := EvalJson("{ answer = 42; }.answer", ".", "dummy")
	if err != nil {
		t.Fatalf("error during eval: %v", err)
	}
	if str != "42" {
		t.Fatalf("error during eval: expected `42`, got `%v`", str)
	}
}

func TestEvalNested42(t *testing.T) {
	if inNixBuild() {
		t.Skip("test requires non nix environment")
	}
	str, err := EvalJson("{ answer.nested.aa = 42; }", ".", "dummy")
	if err != nil {
		t.Fatalf("error during eval: %v", err)
	}
	expected := `{"answer":{"nested":{"aa":42}}}`
	if str != expected {
		t.Fatalf("error during eval: expected `%v`, got `%v`", expected, str)
	}
}

func TestEvalPathExists(t *testing.T) {
	if inNixBuild() {
		t.Skip("test requires non nix environment")
	}
	str, err := EvalJson("builtins.pathExists ./nix", "/", "dummy")
	if err != nil {
		t.Fatalf("error during eval: %v", err)
	}
	if str != "true" {
		t.Fatalf("error during eval: expected `true`, got `%v`", str)
	}
}
