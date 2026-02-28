package bedrock

import (
	"context"
	"fmt"
	"log"
	"log/slog"
	"os"
	"strconv"
)

import (
	"github.com/monzo/terrors"
)

type ShutdownFunc = func(ctx context.Context) error

func Init(ctx context.Context) ShutdownFunc {
	shutdown, err := setupOTelSDK(ctx)

	if err != nil {
		err = terrors.Augment(err, "failed to start otlp sdk", nil)
		log.Fatalln(err)
	}
	slog.Info("bedrock initialized 🚀")

	return shutdown
}

func GetBaseConfig() (*BaseConfig, error) {
	port, ok := os.LookupEnv("HTTP_PORT")
	if !ok {
		slog.Warn("missing HTTP_PORT environment variable, defaulting to 8080")
		port = "8080"
	}
	portNum, err := strconv.Atoi(port)
	if err != nil {
		return nil, terrors.Augment(err, "invalid env config for http port", nil)
	}
	grpcPort, ok := os.LookupEnv("GRPC_PORT")
	if !ok {
		slog.Warn("missing GRPC_PORT environment variable, defaulting to 8081")
		grpcPort = "8081"
	}
	grpcPortNum, err := strconv.Atoi(grpcPort)
	if err != nil {
		return nil, terrors.Augment(err, "invalid env config for http port", nil)
	}
	host, ok := os.LookupEnv("HTTP_HOST")
	if !ok {
		slog.Warn("missing HTTP_HOST environment variable, defaulting to localhost")
		host = "localhost"
	}

	allocId, ok := os.LookupEnv("NOMAD_ALLOC_ID")
	if !ok {
		return nil, terrors.Augment(err, "could not determine alloc ID", nil)
	}

	return &BaseConfig{
		HttpHost: host,
		HttpPort: portNum,
		GrpcPort: grpcPortNum,
		AllocID: allocId,
	}, nil
}

type BaseConfig struct {
	HttpHost string
	HttpPort int
	GrpcPort int
	AllocID string
}

func (c *BaseConfig) HttpBind() string {
	return fmt.Sprint(c.HttpHost, ":", strconv.Itoa(c.HttpPort))
}
