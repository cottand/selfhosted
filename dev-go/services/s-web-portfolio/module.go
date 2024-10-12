package module

import (
	"context"
	"errors"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

var Name = "s-web-portfolio"

var slog = bedrock.LoggerFor(Name)

func InitService() {
	ctx := context.Background()
	conn, err := bedrock.NewGrpcConn()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	stats := s_rpc_portfolio_stats.NewPortfolioStatsClient(conn)

	scaff := &scaffold{
		stats:          stats,
		doGrpcUpstream: true,
	}

	srv := &http.Server{
		Addr:         "localhost:7001",
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelhttp.NewHandler(scaff.MakeHandler(), Name+"-http"),
	}

	var serverErr error
	go func() {
		err := srv.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("failed to start HTTP: "+terrors.Propagate(err).Error(), "service", Name)
		}
	}()

	notify := mono.Register(mono.Service{
		Name: Name,
	})
	go func() {
		_, _ = <-notify
		if conn.Close() != nil {
			slog.Error(terrors.Propagate(err).Error(), "Failed to close gRPC conn", "service", Name)
		}
		if serverErr != nil {
			slog.Error(terrors.Propagate(err).Error(), "Failed to close gRPC conn", "service", Name)
		}
	}()
}
