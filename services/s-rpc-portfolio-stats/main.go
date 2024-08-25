package main

import (
	"context"
	"embed"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"google.golang.org/grpc"
	"log"
	"net/http"
)

//go:embed migrations
var dbMigrations embed.FS

func main() {
	println(bedrock.ServiceName())
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)

	defer shutdown(ctx)

	mux := http.NewServeMux()
	db, err := bedrock.GetMigratedDB(dbMigrations)
	if err != nil {
		log.Fatal(err.Error())
	}
	bedrock.ServeWithGrpc(ctx, mux, func(srv *grpc.Server) {
		s_portfolio_stats.RegisterPortfolioStatsServer(srv, &ProtoHandler{db: db})
	})
}
