package main

import (
	"context"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"google.golang.org/grpc"
	"log/slog"
	"net/http"
)

func main() {
	println(bedrock.ServiceName())
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)

	defer shutdown(ctx)

	mux := http.NewServeMux()
	db, err := GetMigratedDB()
	if err != nil {
		slog.Warn(err.Error())
		//log.Fatal(err.Error())
	}
	bedrock.ServeWithGrpc(ctx, mux, func(srv *grpc.Server) {
		s_portfolio_stats.RegisterPortfolioStatsServer(srv, &ProtoHandler{db: db})
	})
}
