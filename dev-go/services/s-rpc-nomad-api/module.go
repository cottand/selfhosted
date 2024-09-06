package module

import (
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	_ "github.com/farcaller/gonix"
	nomad "github.com/hashicorp/nomad/api"
	"go.opentelemetry.io/otel"
	"google.golang.org/grpc"
	"log/slog"
	"os"
)

var Name = "s-rpc-nomad-api"

var logger = slog.With("service", Name)
var tracer = otel.Tracer(Name)

func InitService() {
	token, ok := os.LookupEnv("NOMAD_TOKEN")
	if !ok {
		logger.Error("failed to get NOMAD_TOKEN, aborting init")
		return
	}
	nomadClient, err := nomad.NewClient(&nomad.Config{
		Address:   "https://nomad.traefik/",
		SecretID:  token,
		TLSConfig: &nomad.TLSConfig{CACert: bedrock.GetRootCaFilePath()},
	})
	if err != nil {
		logger.Error("failed to create Nomad client, aborting init", "err", err.Error())
		return
	}
	protoHandler := &ProtoHandler{
		nomadClient: nomadClient,
	}
	this := mono.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_nomad_api.RegisterNomadApiServer(srv, protoHandler)
		},
	}

	notify := mono.Register(this)

	go func() {
		_, _ = <-notify
		nomadClient.Close()
	}()
}
