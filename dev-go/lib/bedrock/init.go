package bedrock

import (
	"context"
	"fmt"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	"log"
	"log/slog"
	"os"
	"strconv"
	"strings"
)

import (
	"github.com/monzo/terrors"
)

type ShutdownFunc = func(ctx context.Context) error

func KebabToSnakeCase(name string) string {
	return strings.ReplaceAll(name, "-", "_")
}

func Init(ctx context.Context) ShutdownFunc {
	shutdown, err := setupOTelSDK(ctx)

	if err != nil {
		err = terrors.Augment(err, "failed to start otlp sdk", nil)
		log.Fatalln(err)
	}
	err = config.Init()
	if err != nil {
		err = terrors.Augment(err, "failed to start config", nil)
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

	return &BaseConfig{
		HttpHost: host,
		HttpPort: portNum,
		GrpcPort: grpcPortNum,
	}, nil
}

type BaseConfig struct {
	HttpHost string
	HttpPort int
	GrpcPort int
}

func (c *BaseConfig) HttpBind() string {
	return fmt.Sprint(c.HttpHost, ":", strconv.Itoa(c.HttpPort))
}
