package module

import (
	"context"
	"errors"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"log/slog"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

const Name = "s-web-portfolio"

func InitService() (*bedrock.Service, string, error) {
	ctx := bedrock.ContextForModule(Name, context.Background())
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

	go func() {
		err := srv.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("failed to start HTTP", "service", Name, "err", terrors.Propagate(err))
		}
	}()
	var serverErr error

	service := &bedrock.Service{
		Name: Name,
		OnShutdown: func() error {
			if conn.Close() != nil {
				return terrors.Augment(err, "failed to close gRPC conn", nil)
			}
			if serverErr != nil {
				return terrors.Augment(err, "failed to close gRPC conn", nil)
			}
			return nil
		},
	}
	return service, Name, nil
}
