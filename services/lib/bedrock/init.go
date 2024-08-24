package bedrock

import (
	"context"
	"fmt"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
	"log"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"
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

	slog.Info("bedrock initialized")

	d, err := NixAssetsDir()
	if err != nil {
		err = terrors.Augment(err, "failed to init bedrock nixAssetsDir", nil)
		log.Fatalln(err)
	}
	slog.Info("using Nix assets", "dir", d)

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

func Serve(ctx context.Context, mux *http.ServeMux) {

	mux.Handle("/metrics", promhttp.Handler())

	config, err := GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to get config", nil).Error())
	}

	srv := &http.Server{
		Addr:         config.HttpHost + ":" + strconv.Itoa(config.HttpPort),
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelhttp.NewHandler(mux, "http"),
	}

	err = srv.ListenAndServe()

	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to run server", nil).Error())
	}

}

func ServeWithGrpc(ctx context.Context, mux *http.ServeMux, registerGrpcHook func(srv *grpc.Server)) {
	config, err := GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to get config", nil).Error())
	}

	lis, err := net.Listen("tcp", fmt.Sprintf("%s:%d", config.HttpHost, config.GrpcPort))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer(grpc.StatsHandler(otelgrpc.NewServerHandler()))

	registerGrpcHook(grpcServer)

	go func() {
		err = grpcServer.Serve(lis)
		if err != nil {
			log.Fatalf(err.Error())
		}
	}()

	Serve(ctx, mux)
}

func ServiceName() string {
	return filepath.Base(os.Args[0])
}
