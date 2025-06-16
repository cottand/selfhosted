package bedrock

import (
	"context"
	"errors"
	"fmt"
	"github.com/cottand/selfhosted/dev-go/lib/util"
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
	"strings"
	"time"
)

var servicesHooks []RegistrationHook

type Service struct {
	Name         string
	PromMetrics  http.Handler
	RegisterGrpc func(grpcServer *grpc.Server)
	OnShutdown   func() error
}

type RegistrationHook = func() (*Service, string, error)

func Register(hook RegistrationHook) {
	servicesHooks = append(servicesHooks, hook)
}

// parseFullMethod takes `/s_rpc_vault.VaultApi/Snapshot` and returns `s-rpc-vault` and `Snapshot`
func parseFullMethod(fullMethod string) (service, method string) {
	parts := strings.Split(fullMethod, "/")
	if len(parts) != 3 {
		return "", ""
	}
	nameParts := strings.Split(parts[1], ".")
	if len(nameParts) != 2 {
		return "", ""
	}
	service = util.SnakeToKebabCase(nameParts[0])

	return service, parts[2]
}

var addModuleNameToContextUnary grpc.UnaryServerInterceptor = func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	service, method := parseFullMethod(info.FullMethod)
	newCtx := ContextForModule(service, ctx)
	newCtx = util.CtxWithLog(newCtx, slog.String("grpc_method", method))
	return handler(newCtx, req)
}

// streamHandlerWithContext wraps a grpc.ServerStream to return a new context.Context via newCtx
type streamHandlerWithContext struct {
	newCtx func(context.Context) context.Context
	grpc.ServerStream
}

func (h streamHandlerWithContext) Context() context.Context {
	return h.newCtx(h.ServerStream.Context())
}

var addModuleNameToContextStream grpc.StreamServerInterceptor = func(srv any, stream grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	service, method := parseFullMethod(info.FullMethod)
	newStream := streamHandlerWithContext{
		ServerStream: stream,
		newCtx: func(oldCtx context.Context) context.Context {
			return util.CtxWithLog(oldCtx, slog.String("module", service), slog.String("grpc_method", method))
		},
	}
	return handler(srv, newStream)
}

func RunRegistered() {
	ctx := context.Background()
	Init(ctx)
	grpcServer := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
		grpc.UnaryInterceptor(addModuleNameToContextUnary),
		grpc.StreamInterceptor(addModuleNameToContextStream),
	)
	reflection.Register(grpcServer)
	defer grpcServer.GracefulStop()

	services := map[string]*Service{}

	for _, registrationHook := range servicesHooks {
		svc, name, err := registrationHook()
		if err != nil {
			slog.ErrorContext(ctx, "failed to init service", "module", name, "err", err)
			continue
		}
		slog.InfoContext(ctx, "initialised service", "module", name)
		services[name] = svc
	}

	for name, module := range services {
		if module.RegisterGrpc != nil {
			module.RegisterGrpc(grpcServer)
		}
		slog.InfoContext(ctx, "registered grpc", "module", name)
	}
	config, err := GetBaseConfig()
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
