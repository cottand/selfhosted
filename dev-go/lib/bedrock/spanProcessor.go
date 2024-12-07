package bedrock

import (
	"context"
	"go.opentelemetry.io/otel/sdk/trace"
)

// spanProcessor implements trace.SpanProcessor
type spanProcessor struct {
}

var _ trace.SpanProcessor = (*spanProcessor)(nil)

func (sp *spanProcessor) OnStart(parent context.Context, span trace.ReadWriteSpan) {

	span.SpanKind()
	//TODO implement me
	panic("implement me")
}

func (sp *spanProcessor) OnEnd(span trace.ReadOnlySpan) {
	//TODO implement me
	//panic("implement me")
}

func (sp *spanProcessor) Shutdown(ctx context.Context) error {
	return nil
}

func (sp *spanProcessor) ForceFlush(ctx context.Context) error {
	return nil
}
