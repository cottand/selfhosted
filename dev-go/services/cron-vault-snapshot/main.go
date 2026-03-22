package main

import (
	"context"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"log/slog"
	"os"
)

func main() {
	name := "cron-vault-snapshot"
	ctx := bedrock.ContextForModule(name, context.Background())
	tracer := bedrock.GetTracer(ctx)

	ctx, span := tracer.Start(ctx, "cron")
	defer span.End()

	_, err := s_rpc_vault.Snapshot(ctx, &emptypb.Empty{})
	if err != nil {
		slog.ErrorContext(ctx, "error during cron", "err", terrors.Propagate(err))
		span.RecordError(err)
		os.Exit(1)
	}
	slog.InfoContext(ctx, "cron snapshot completed")
}
