package module

import (
	"context"
	"embed"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

//go:embed migrations
var dbMigrations embed.FS

const name = "s-rpc-portfolio-stats"

func InitService() (*bedrock.Service, string, error) {
	ctx := bedrock.ContextForModule(name, context.Background())
	db, err := bedrock.GetMigratedDB(name, dbMigrations)
	if err != nil {
		return nil, name, terrors.Propagate(err)
	}

	refreshCtx, refreshCancel := context.WithCancel(ctx)

	go RefreshPromStats(refreshCtx, db)

	service := &bedrock.Service{
		Name: name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_portfolio_stats.RegisterPortfolioStatsServer(srv, &ProtoHandler{db: db})
		},
		OnShutdown: func() error {
			refreshCancel()
			if db.Close() != nil {
				return terrors.Augment(err, "failed to close DB", nil)
			}
			return nil
		},
	}
	return service, name, nil
}
