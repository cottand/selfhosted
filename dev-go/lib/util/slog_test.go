package util_test

import (
	"bytes"
	"context"
	"github.com/cottand/selfhosted/dev-go/lib/util"
	"github.com/stretchr/testify/assert"
	"log/slog"
	"testing"
)

func TestContextPropagatesMessages(t *testing.T) {
	b := &bytes.Buffer{}

	logger := slog.New(util.NewContextLogHandler(slog.NewTextHandler(b, nil)))

	withFoo := util.CtxWithLog(context.Background(), slog.String("foo", "bar"))
	logger.InfoContext(withFoo, "test")

	assert.Contains(t, b.String(), "foo=bar")
}

func TestContextPropagatesStackedMessages(t *testing.T) {
	b := &bytes.Buffer{}

	logger := slog.New(util.NewContextLogHandler(slog.NewTextHandler(b, nil)))

	withFooBar := util.CtxWithLog(context.Background(), slog.String("foo", "bar"))
	withFooBaz := util.CtxWithLog(withFooBar, slog.String("foo", "baz"))
	logger.InfoContext(withFooBaz, "test")

	assert.Contains(t, b.String(), "foo=bar")
	assert.Contains(t, b.String(), "foo=baz")
}

func TestContextValueNotMuted(t *testing.T) {
	b := &bytes.Buffer{}

	logger := slog.New(util.NewContextLogHandler(slog.NewTextHandler(b, nil)))

	withFooBar := util.CtxWithLog(context.Background(), slog.String("foo", "bar"))
	_ = util.CtxWithLog(withFooBar, slog.String("foo", "baz"))
	logger.InfoContext(withFooBar, "test")

	assert.Contains(t, b.String(), "foo=bar")
	assert.NotContains(t, b.String(), "foo=baz")
}
