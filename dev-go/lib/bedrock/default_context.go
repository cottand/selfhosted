package bedrock

import (
	"context"
	"github.com/cottand/selfhosted/dev-go/lib/util"
	"log/slog"
)

// ContextForModule enriches ctx with whatever default values the base context of the service
// called name ought to have
func ContextForModule(name string, ctx context.Context) context.Context {
	newCtx := CtxWithModuleName(ctx, name)
	newCtx = util.CtxWithLog(newCtx, slog.String("module.name", name))

	return newCtx
}
