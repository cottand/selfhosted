package mono

import (
	"context"
	"errors"
	"fmt"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"google.golang.org/grpc"
	"log"
	"log/slog"
	"net"
	"net/http"
	"os"
	"time"
)

var services = map[string]Service{}

type Service struct {
	Name         string
	PromMetrics  http.Handler
	RegisterGrpc func(grpcServer *grpc.Server)
	registration Registration
}

type Registration struct {
	notify chan struct{}
}

func Register(new Service) <-chan struct{} {
	new.registration.notify = make(chan struct{})
	services[new.Name] = new
	return new.registration.notify
}

func RunRegistered() {
	ctx := context.Background()
	bedrock.Init(ctx)
	grpcServer := grpc.NewServer(grpc.StatsHandler(otelgrpc.NewServerHandler()))
	defer grpcServer.GracefulStop()
	for name, module := range services {
		if module.RegisterGrpc != nil {
			module.RegisterGrpc(grpcServer)
		}
		slog.Info("registered mono", "service", name)
	}

	config, err := bedrock.GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to get config", nil).Error())
	}
	lis, err := net.Listen("tcp", fmt.Sprintf("%s:%d", config.HttpHost, config.GrpcPort))
	if err != nil {
		log.Fatalf("failed to listen grpc: %v", err)
	}
	shutdownServices := func() {
		for _, service := range services {
			close(service.registration.notify)
		}
	}

	defer shutdownServices()

	go func() {
		err := SetupAndServeMetrics(ctx)
		if err != nil {
			log.Fatalf(err.Error())
		}
	}()

	slog.Info("successfully registered all services in mono 🐒, listening grpc", "host", config.HttpHost, "port", config.GrpcPort)

	err = grpcServer.Serve(lis)

	if err != nil && !errors.Is(err, grpc.ErrServerStopped) {
		log.Fatalf(err.Error())
	}
}

func SetupAndServeMetrics(ctx context.Context) error {

	port, ok := os.LookupEnv("HTTP_PORT")
	if !ok {
		return terrors.Propagate(errors.New("no environment variable HTTP_PORT"))
	}

	srv := &http.Server{
		Addr:         "localhost:" + port,
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      promhttp.Handler(),
	}
	err := srv.ListenAndServe()
	if !errors.Is(err, http.ErrServerClosed) {
		return terrors.Propagate(err)
	}
	return nil
}
