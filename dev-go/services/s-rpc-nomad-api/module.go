package module

import (
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	_ "github.com/farcaller/gonix"
	"google.golang.org/grpc"
	"log/slog"
)

var Name = "s-rpc-nomad-api"

var logger = slog.With("service_module", Name)

func InitService() {
	this := mono.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_nomad_api.RegisterNomadApiServer(srv, &ProtoHandler{})
		},
	}

	notify := mono.Register(this)

	go func() {
		_, _ = <-notify
	}()
}
