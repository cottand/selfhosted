package mono

import (
	"context"
	"fmt"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
	"log"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"time"
)

var services = map[string]Service{}

type Service struct {
	Name         string
	PromMetrics  http.Handler
	Http         http.Handler
	RegisterGrpc func(grpcServer *grpc.Server)
	Close        func() error
}

func Register(new Service) {
	services[new.Name] = new
}

func Get(name string) Service {
	return services[name]
}

func RunRegistered() {
	ctx := context.Background()
	bedrock.Init(ctx)
	grpcServer := grpc.NewServer(grpc.StatsHandler(otelgrpc.NewServerHandler()))
	mux := http.NewServeMux()
	defer grpcServer.GracefulStop()
	for name, module := range services {
		if module.RegisterGrpc != nil {
			module.RegisterGrpc(grpcServer)
		}

		if module.Http != nil {
			pattern := "/" + name
			mux.Handle(pattern, http.StripPrefix(pattern, module.Http))
		}
		slog.Info("registered mono", "service", name)
	}
	mux.Handle("/metrics", promhttp.Handler())

	config, err := bedrock.GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to get config", nil).Error())
	}
	lis, err := net.Listen("tcp", fmt.Sprintf("%s:%d", config.HttpHost, config.GrpcPort))
	if err != nil {
		log.Fatalf("failed to listen grpc: %v", err)
	}

	go func() {
		err = grpcServer.Serve(lis)
		if err != nil {
			log.Fatalf(err.Error())
		}

	}()

	srv := &http.Server{
		Addr:         config.HttpHost + ":" + strconv.Itoa(config.HttpPort),
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelhttp.NewHandler(mux, "http"),
	}

	err = srv.ListenAndServe()
}
