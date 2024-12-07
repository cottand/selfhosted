package main

import (
	"context"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"log"
	"os"
)

func main() {
	ctx := context.Background()
	_, slog, tracer := bedrock.New("cron-vault-snapshot")

	ctx, span := tracer.Start(ctx, "cron")
	defer span.End()

	conn, err := bedrock.NewGrpcConn()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}
	defer conn.Close()

	client := s_rpc_vault.NewVaultApiClient(conn)
	_, err = client.Snapshot(ctx, &emptypb.Empty{})
	if err != nil {
		slog.ErrorContext(ctx, "error during cron", "err", terrors.Propagate(err))
		span.RecordError(err)
		os.Exit(1)
	}
	slog.InfoContext(ctx, "cron snapshot completed")
}
