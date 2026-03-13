package module

import (
	"context"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

const name = "s-rpc-flights"

func InitService() (*bedrock.Service, string, error) {
	ctx := bedrock.ContextForModule(name, context.Background())
	db, err := bedrock.OpenDB()
	if err != nil {
		return nil, name, terrors.Propagate(err)
	}
	ctx, cancel := context.WithCancel(ctx)

	go RefreshPromStats(ctx, db)

	service := &bedrock.Service{
		Name: name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_flights.RegisterFlightsServer(srv, &ProtoHandler{db: db})
		},
		OnShutdown: func() error {
			cancel()
			if db.Close() != nil {
				return terrors.Augment(err, "failed to close DB", nil)
			}
			return nil
		},
	}
	return service, name, nil
}
