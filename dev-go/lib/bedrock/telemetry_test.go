package bedrock

import (
	"bytes"
	"github.com/monzo/terrors"
	"log/slog"
	"strings"
	"testing"
)

func TestLoggerReplaceErrors(t *testing.T) {
	b := &bytes.Buffer{}
	logger := slog.New(slog.NewTextHandler(b, slogOpts))

	logger.Info("some info with err", "err", terrors.BadRequest("", "message", nil))

	if !strings.Contains(b.String(), "error.msg") {
		t.Fail()
	}
}
func TestLoggerReplaceErrorsWithParams(t *testing.T) {
	b := &bytes.Buffer{}
	logger := slog.New(slog.NewTextHandler(b, slogOpts))

	errParams := map[string]string{
		"when": "tomorrow",
	}

	logger.Info("some info with err", "err", terrors.BadRequest("", "message", errParams))

	println(b.String())

	if !strings.Contains(b.String(), "error.param.when=tomorrow") {
		t.Fail()
	}
}
