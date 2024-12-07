package module

import (
	"context"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

var Name, slog, tracer = bedrock.New("s-rpc-vault")

func InitService(_ context.Context) (*mono.Service, string, error) {
	vaultClient, err := secretstore.NewClient()
	if err != nil {
		return nil, Name, terrors.Augment(err, "failed to init vault client", nil)
	}
	protoHandler := &ProtoHandler{
		vaultClient: vaultClient,
	}
	return &mono.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_vault.RegisterVaultApiServer(srv, protoHandler)
		},
		OnShutdown: func() error { return nil },
	}, Name, nil
}
