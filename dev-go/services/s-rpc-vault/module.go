package module

import (
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_vault "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"google.golang.org/grpc"
)

var Name, slog, tracer = bedrock.New("s-rpc-vault")

func init() {
	vaultClient, err := secretstore.NewClient()
	if err != nil {
		slog.Error("failed to init vault client", "err", err.Error())
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

	mono.RunRegistered()
}
