package mono

import (
	"context"
	"fmt"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"google.golang.org/grpc"
	"log"
	"log/slog"
	"net"
	"net/http"
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

func Get(name string) Service {
	return services[name]
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

	go func() {
		err = grpcServer.Serve(lis)
		if err != nil {
			log.Fatalf(err.Error())
		}

	}()

}
