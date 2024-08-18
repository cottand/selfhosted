package main

import (
	"context"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
	"log"
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

	var opts []grpc.DialOption
	addr, ok := os.LookupEnv("NOMAD_UPSTREAM_ADDR_s_portfolio_stats_grpc")
	if !ok {
		log.Fatalf("Failed to find upstream env var")
	}
	conn, err := grpc.NewClient(addr, opts...)
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	defer conn.Close()
	stats := s_portfolio_stats.NewPortfolioStatsClient(conn)

	mux := http.NewServeMux()

	fs := http.FileServer(http.Dir(root + "/srv"))
	mux.Handle("/static/", otelhttp.WithRouteTag("/static/", fs))
	mux.Handle("/", otelhttp.WithRouteTag("/", http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		req.URL.Path = "/"
		fs.ServeHTTP(rw, req)

		go func() {
			_, _ = stats.Report(context.Background(), &s_portfolio_stats.Visit{})
		}()
	})))

	bedrock.Serve(ctx, mux)
}
