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
	"google.golang.org/grpc/reflection"
	"log"
	"log/slog"
	"net"
	"net/http"
	"os"
	"time"
)

var servicesHooks []RegistrationHook

type Service struct {
	Name         string
	PromMetrics  http.Handler
	RegisterGrpc func(grpcServer *grpc.Server)
	OnShutdown   func() error
}

type RegistrationHook = func(ctx context.Context) (*Service, string, error)

func Register(hook RegistrationHook) {
	servicesHooks = append(servicesHooks, hook)
}

func RunRegistered() {
	ctx := context.Background()
	bedrock.Init(ctx)
	grpcServer := grpc.NewServer(grpc.StatsHandler(otelgrpc.NewServerHandler()))
	reflection.Register(grpcServer)
	defer grpcServer.GracefulStop()

	services := map[string]*Service{}

	for _, hook := range servicesHooks {
		svc, name, err := hook(ctx)
		if err != nil {
			slog.ErrorContext(ctx, "failed to init service", "service", name, "err", err)
			continue
		}
		slog.InfoContext(ctx, "initialised service", "service", name)
		services[name] = svc
	}

	for name, module := range services {

		if module.RegisterGrpc != nil {
			module.RegisterGrpc(grpcServer)
		}
		slog.InfoContext(ctx, "registered grpc", "service", name)
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
			if err := service.OnShutdown(); err != nil {
				slog.WarnContext(ctx, "error during service shutdown", "service", service.Name, "err", terrors.Propagate(err))
			}
		}
	}

	defer shutdownServices()

	go func() {
		err := setupAndServeMetrics(ctx)
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

func setupAndServeMetrics(ctx context.Context) error {

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
