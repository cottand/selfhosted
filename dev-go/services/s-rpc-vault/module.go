package module

import (
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

const Name = "s-rpc-vault"

func InitService() (*bedrock.Service, string, error) {
	vaultClient, err := secretstore.NewClient()
	if err != nil {
		return nil, Name, terrors.Augment(err, "failed to init vault client", nil)
	}
	protoHandler := &ProtoHandler{
		vaultClient: vaultClient,
	}
	return &bedrock.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_vault.RegisterVaultApiServer(srv, protoHandler)
		},
		OnShutdown: func() error { return nil },
	}, Name, nil
}
