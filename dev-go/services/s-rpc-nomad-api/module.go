package module

import (
	"context"
	"errors"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
	"net/http"
	"os"
)

var Name, slog, tracer = bedrock.New("s-rpc-nomad-api")

func InitService(_ context.Context) (*mono.Service, string, error) {
	token, ok := os.LookupEnv("NOMAD_TOKEN")
	if !ok {
		return nil, Name, errors.New("NOMAD_TOKEN environment variable not set")
	}
	nomadClient, err := nomad.NewClient(&nomad.Config{
		Address:    "unix:///secrets/api.sock",
		SecretID:   token,
		HttpClient: &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)},
	})
	if err != nil {
		return nil, Name, terrors.Augment(err, "failed to create nomad client", nil)
	}
	protoHandler := &ProtoHandler{
		nomadClient: nomadClient,
	}
	service := mono.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_nomad_api.RegisterNomadApiServer(srv, protoHandler)
		},
		OnShutdown: func() error {
			nomadClient.Close()
			return nil
		},
	}
	return &service, Name, nil
}
