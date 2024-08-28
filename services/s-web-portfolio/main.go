package mono

import (
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-rpc-portfolio-stats"
	"github.com/cottand/selfhosted/services/mono"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"log"
	"log/slog"
	"net/http"
	"os"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

func init() {
	root, err := bedrock.NixAssetsDir()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	addr, enableGrpcReporting := os.LookupEnv("NOMAD_UPSTREAM_ADDR_s_rpc_portfolio_stats_grpc")
	if !enableGrpcReporting {
		slog.Warn("Failed to find upstream env var", "var", "NOMAD_UPSTREAM_ADDR_s_rpc_portfolio_stats_grpc")
	}
	conn, err := grpc.NewClient(
		addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
	)
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	stats := s_rpc_portfolio_stats.NewPortfolioStatsClient(conn)

	fsWithNoCache := http.FileServer(http.Dir(root + "/srv"))
	fs := http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "max-age=600")
		fsWithNoCache.ServeHTTP(writer, request)
	})

	mux := http.NewServeMux()

	mux.Handle("/static/", fs)
	mux.Handle("/assets/", fs)
	mux.Handle("/styles/", fs)
	mux.Handle("/robots.txt", fs)
	mux.Handle("/CNAME", fs)
	mux.Handle("/", handleRoot(fs, stats, false))
	mux.Handle("/api/browse", handleBrowse(stats, enableGrpcReporting))

	mono.Register(mono.Service{
		Name: "s-web-portfolio",
		Http: mux,
		Close: func() error {
			return terrors.Propagate(conn.Close())
		},
	})
}
