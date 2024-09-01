package bedrock

import (
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"log/slog"
	"os"
)

func NewGrpcConn() (*grpc.ClientConn, error) {
	port, ok := os.LookupEnv("GRPC_PORT")
	if !ok {
		slog.Warn("Failed to find GRPC_PORT env var", "var", "GRPC_PORT")
	}
	conn, err := grpc.NewClient(
		"localhost:"+port,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
	)
	return conn, err
}
