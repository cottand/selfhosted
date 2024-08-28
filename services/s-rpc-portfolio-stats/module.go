package module

import (
	"embed"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-rpc-portfolio-stats"
	"github.com/cottand/selfhosted/services/mono"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
	"log"
	"os"
	"strings"
)

//go:embed migrations
var dbMigrations embed.FS

var ModuleName = "s-rpc-portfolio-stats"

func InitService() {
	if strings.HasSuffix(os.Args[0], ".test") {
		return
	}

	db, err := bedrock.GetMigratedDB(dbMigrations)
	if err != nil {
		log.Fatal(err.Error())
	}
	this := mono.Service{
		Name: ModuleName,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_portfolio_stats.RegisterPortfolioStatsServer(srv, &ProtoHandler{db: db})
		},
		Http: nil,
		Close: func() error {
			return terrors.Propagate(db.Close())
		},
	}
	mono.Register(this)
}
