package module

import (
	"embed"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	"github.com/cottand/selfhosted/services/lib/mono"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
	"log"
	"log/slog"
	"os"
	"strings"
)

//go:embed migrations
var dbMigrations embed.FS

var Name = "s-rpc-portfolio-stats"

func InitService() {
	if strings.HasSuffix(os.Args[0], ".test") {
		return
	}

	db, err := bedrock.GetMigratedDB(dbMigrations)
	if err != nil {
		log.Fatal(err.Error())
	}
	this := mono.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_portfolio_stats.RegisterPortfolioStatsServer(srv, &ProtoHandler{db: db})
		},
	}

	notify := mono.Register(this)

	go func() {
		_, _ = <-notify
		if db.Close() != nil {
			slog.Error(terrors.Propagate(err).Error(), "Failed to close DB", "module", Name)
		}
	}()
}
