package bedrock

import (
	otrace "go.opentelemetry.io/otel/trace"
	"log/slog"
)

func Cron(name string) (Name string, slog *slog.Logger, tracer otrace.Tracer) {
	return Service(name)
}
