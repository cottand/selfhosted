package util

import (
	"context"
	"iter"
	"log/slog"
)

const contextLogKeyName = "context_log_key_0rjf02"

var _ slog.Handler = (*ContextLogHandler)(nil)

func NewContextLogHandler(next slog.Handler) slog.Handler {
	return &ContextLogHandler{next}
}

type ContextLogHandler struct {
	Next slog.Handler
}

func (c ContextLogHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return c.Next.Enabled(ctx, level)
}

func logAttrsFrom(value ContextLogValue) iter.Seq[[]slog.Attr] {
	return func(yield func([]slog.Attr) bool) {
		if value.parent != nil {
			for attr := range logAttrsFrom(*value.parent) {
				if !yield(attr) {
					return
				}
			}
		}
		if len(value.LogValues) != 0 {
			yield(value.LogValues)
		}
	}
}

func (c ContextLogHandler) Handle(ctx context.Context, record slog.Record) error {
	if contextLog, ok := ctx.Value(contextLogKeyName).(ContextLogValue); ok {
		for attr := range logAttrsFrom(contextLog) {
			record.AddAttrs(attr...)
		}
	}
	return c.Next.Handle(ctx, record)
}

func (c ContextLogHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return NewContextLogHandler(c.Next.WithAttrs(attrs))
}

func (c ContextLogHandler) WithGroup(name string) slog.Handler {
	return NewContextLogHandler(c.Next.WithGroup(name))
}

// ContextLogValue stores the log values for a context
// as well as the pointer to log values of the parent context
type ContextLogValue struct {
	parent    *ContextLogValue
	LogValues []slog.Attr
}

func CtxWithLog(ctx context.Context, values ...slog.Attr) context.Context {
	newLogValue := ContextLogValue{LogValues: values}
	if existing, ok := ctx.Value(contextLogKeyName).(ContextLogValue); ok {
		newLogValue.parent = &existing
	}

	return context.WithValue(ctx, contextLogKeyName, newLogValue)
}
