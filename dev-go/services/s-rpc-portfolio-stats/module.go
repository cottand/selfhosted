package module

import (
	"context"
	"embed"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
)

//go:embed migrations
var dbMigrations embed.FS

var Name, slog, tracer = bedrock.New("s-rpc-portfolio-stats")

func InitService(_ context.Context) (*mono.Service, string, error) {
	db, err := bedrock.GetMigratedDB(Name, dbMigrations)
	if err != nil {
		return nil, Name, terrors.Propagate(err)
	}

	refreshCtx, refreshCancel := context.WithCancel(context.Background())

	go RefreshPromStats(refreshCtx, db)

	service := &mono.Service{
		Name: Name,
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
	return service, Name, nil
}
