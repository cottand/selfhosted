package module

import (
	"context"
	"embed"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

//go:embed migrations
var dbMigrations embed.FS

const name = "s-rpc-flights"

func InitService() (*bedrock.Service, string, error) {
	_ = bedrock.ContextForModule(name, context.Background())
	db, err := bedrock.GetMigratedDB(name, dbMigrations)
	if err != nil {
		return nil, name, terrors.Propagate(err)
	}

	service := &bedrock.Service{
		Name: name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_flights.RegisterFlightsServer(srv, &ProtoHandler{db: db})
		},
		OnShutdown: func() error {
			if db.Close() != nil {
				return terrors.Augment(err, "failed to close DB", nil)
			}
			return nil
		},
	}
	return service, name, nil
}
