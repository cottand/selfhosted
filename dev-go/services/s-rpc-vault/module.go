package module

import (
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	vault "github.com/hashicorp/vault/api"
	"google.golang.org/grpc"
)

var Name, slog, tracer = bedrock.Service("s-rpc-vault")

func InitService() {
	vaultClient, err := vault.NewClient(vault.DefaultConfig())
	if err != nil {
		slog.Error("failed to init vault client: %v", err)
		return
	}
	protoHandler := &ProtoHandler{
		vaultClient: vaultClient,
	}
	this := mono.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_vault.RegisterVaultApiServer(srv, protoHandler)
		},
	}

	notify := mono.Register(this)

	go func() {
		_, _ = <-notify
	}()
}
