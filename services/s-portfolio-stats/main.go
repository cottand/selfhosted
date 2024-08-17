package main

import (
	"context"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"google.golang.org/grpc"
	"net/http"
)

func main() {
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)

	defer shutdown(ctx)

	mux := http.NewServeMux()
	bedrock.ServeWithGrpc(ctx, mux, func(srv *grpc.Server) {
		s_portfolio_stats.RegisterPortfolioStatsServer(srv, &ProtoHandler{})
	})
}
