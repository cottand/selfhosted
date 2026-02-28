package module

import (
	"context"
	"errors"
	"os"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

func InitService() (*bedrock.Service, string, error) {
	name := "s-rpc-nomad-api"
	_ = bedrock.ContextForModule(name, context.Background())
	token, ok := os.LookupEnv("NOMAD_TOKEN")
	if !ok {
		return nil, name, errors.New("NOMAD_TOKEN environment variable not set")
	}
	nomadClient, err := nomad.NewClient(&nomad.Config{
		// available nomad API (https://developer.hashicorp.com/nomad/api-docs/task-api)
		Address:  "unix:///secrets/api.sock",
		SecretID: token,
		// can't have both an HttpClient and a unix socket in the config
		//HttpClient: &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)},
	})
	if err != nil {
		return nil, name, terrors.Augment(err, "failed to create nomad client", nil)
	}

	_, err = nomadClient.Agent().Health()
	if err != nil {
		return nil, name, terrors.Augment(err, "failed to check nomad health", nil)
	}

	protoHandler := &ProtoHandler{
		nomadClient: nomadClient,
	}
	service := bedrock.Service{
		Name: name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_nomad_api.RegisterNomadApiServer(srv, protoHandler)
		},
		OnShutdown: func() error {
			nomadClient.Close()
			return nil
		},
	}
	return &service, name, nil
}
