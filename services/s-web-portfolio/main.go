package main

import (
	"context"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"log"
	"log/slog"
	"net/http"
	"os"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

func main() {
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)
	defer shutdown(ctx)

	root, err := bedrock.NixAssetsDir()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	addr, enableGrpcReporting := os.LookupEnv("NOMAD_UPSTREAM_ADDR_s_portfolio_stats_grpc")
	if !enableGrpcReporting {
		slog.Warn("Failed to find upstream env var", "var", "NOMAD_UPSTREAM_ADDR_s_portfolio_stats_grpc")
	}
	conn, err := grpc.NewClient(
		addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
	)
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	defer conn.Close()
	stats := s_portfolio_stats.NewPortfolioStatsClient(conn)

	mux := http.NewServeMux()

	fs := http.FileServer(http.Dir(root + "/srv"))
	mux.Handle("/static/", otelhttp.WithRouteTag("/static/", fs))
	mux.Handle("/assets/", otelhttp.WithRouteTag("/assets/", fs))
	mux.Handle("/", otelhttp.WithRouteTag("/", http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		originalPath := req.URL.Path
		req.URL.Path = "/"
		fs.ServeHTTP(rw, req)

		go func() {
			if enableGrpcReporting {
				_, _ = stats.Report(context.WithoutCancel(req.Context()), &s_portfolio_stats.Visit{
					Url:       originalPath,
					Ip:        req.Header.Get("X-Forwarded-For"),
					UserAgent: req.Header.Get("User-Agent"),
				})
			}
		}()
	})))

	bedrock.Serve(ctx, mux)
}
