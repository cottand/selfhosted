package bedrock

import (
	"context"
	"errors"
	"github.com/monzo/terrors"
	slogotel "github.com/remychantenay/slog-otel"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"log/slog"
	"os"
)

var slogOpts = &slog.HandlerOptions{ReplaceAttr: loggerReplaceErrs}

func init() {
	logger := slog.New(slogotel.OtelHandler{
		Next:          slog.NewJSONHandler(os.Stderr, slogOpts),
		NoBaggage:     false,
		NoTraceEvents: false,
	})

	slog.SetDefault(logger)
}

func loggerReplaceErrs(groups []string, pre slog.Attr) slog.Attr {
	if !(pre.Key == "err" || pre.Key == "error") {
		return pre
	}
	err, isErr := pre.Value.Any().(error)
	if !isErr {
		return pre
	}
	var terror *terrors.Error
	if !errors.As(err, &terror) {
		return pre
	}
	var params []any
	for paramK, paramV := range terror.Params {
		params = append(params, slog.String(paramK, paramV))
	}
	return slog.Group("error",
		slog.String("msg", err.Error()),
		slog.Group("param", params...),
	)
}

func LoggerFor(serviceName string) *slog.Logger {
	return slog.With("service_module", serviceName)
}

func New(name string) (Name string, slog *slog.Logger, tracer trace.Tracer) {
	return name, LoggerFor(name), otel.Tracer(name)
}

// see https://opentelemetry.io/docs/languages/go/getting-started/

// setupOTelSDK bootstraps the OpenTelemetry pipeline.
// If it does not return an error, make sure to call shutdown for proper cleanup.
func setupOTelSDK(ctx context.Context) (shutdown func(context.Context) error, err error) {
	var shutdownFuncs []func(context.Context) error

	// shutdown calls cleanup functions registered via shutdownFuncs.
	// The errors from the calls are joined.
	// Each registered cleanup will be invoked once.
	shutdown = func(ctx context.Context) error {
		var err error
		for _, fn := range shutdownFuncs {
			err = errors.Join(err, fn(ctx))
		}
		shutdownFuncs = nil
		return terrors.Propagate(err)
	}

	// handleErr calls shutdown for cleanup and makes sure that all errors are returned.
	handleErr := func(inErr error) {
		err = errors.Join(inErr, shutdown(ctx))
	}

	// Set up propagator.
	prop := newPropagator()
	otel.SetTextMapPropagator(prop)

	// Set up sdktrace provider - TODO do not set it globally
	tracerProvider, err := newTraceProvider(ctx)
	if err != nil {
		handleErr(terrors.Propagate(err))
		return
	}
	shutdownFuncs = append(shutdownFuncs, tracerProvider.Shutdown)
	otel.SetTracerProvider(tracerProvider)

	return
}

func newPropagator() propagation.TextMapPropagator {
	return propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	)
}

func newTraceProvider(ctx context.Context) (*sdktrace.TracerProvider, error) {
	traceExporter, err := otlptracegrpc.New(ctx)
	if err != nil {
		return nil, terrors.Propagate(err)
	}

	traceProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
	)
	return traceProvider, nil
}
