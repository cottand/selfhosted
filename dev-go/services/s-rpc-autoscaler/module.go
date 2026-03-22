package module

import (
	"context"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_autoscaler "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-autoscaler"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

const name = "s-rpc-autoscaler"

func InitService() (*bedrock.Service, string, error) {
	ctx := bedrock.ContextForModule(name, context.Background())

	handler, err := NewHandler()
	if err != nil {
		return nil, name, terrors.Augment(err, "failed to init autoscaler handler", nil)
	}

	ctx, cancel := context.WithCancel(ctx)
	service := &bedrock.Service{
		Name: name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_autoscaler.RegisterAutoscalerServer(srv, handler)
		},
		OnShutdown: func() error {
			cancel()
			return handler.Close()
		},
	}
	return service, name, nil
}
