package cron

import (
	"go.opentelemetry.io/otel"
	otrace "go.opentelemetry.io/otel/trace"
	"log/slog"
)

func New(name string) (Name string, slog_ *slog.Logger, tracer otrace.Tracer) {
	return name, slog.With("service_", name), otel.Tracer(name)
}
