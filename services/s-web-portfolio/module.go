package module

import (
	"context"
	"errors"
	"github.com/cottand/selfhosted/services/lib/mono"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"log/slog"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

var Name = "s-web-portfolio"

var logger = slog.With("service_module", Name)

func InitService() {
	ctx := context.Background()
	root, err := bedrock.NixAssetsDir()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	conn, err := bedrock.NewGrpcConn()
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
	mux.Handle("/api/browse", handleBrowse(stats, conn != nil))

	srv := &http.Server{
		Addr:         "localhost:7001",
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelhttp.NewHandler(mux, Name+"-http"),
	}

	var serverErr error
	go func() {
		err := srv.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("failed to start HTTP: "+terrors.Propagate(err).Error(), "service", Name)
		}
	}()

	notify := mono.Register(mono.Service{
		Name: Name,
	})
	go func() {
		_, _ = <-notify
		if conn.Close() != nil {
			logger.Error(terrors.Propagate(err).Error(), "Failed to close gRPC conn", "service", Name)
		}
		if serverErr != nil {
			logger.Error(terrors.Propagate(err).Error(), "Failed to close gRPC conn", "service", Name)
		}
	}()
}
