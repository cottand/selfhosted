package module

import (
	"context"
	"errors"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"log"
	"log/slog"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

var Name = "s-web-github-webhook"
var logger = slog.With("service", Name)
var tracer = otel.Tracer(Name)

type scaffold struct {
	nomad s_rpc_nomad_api.NomadApiClient
}

func InitService() {
	ctx := context.Background()

	conn, err := bedrock.NewGrpcConn()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	s := &scaffold{
		nomad: s_rpc_nomad_api.NewNomadApiClient(conn),
	}

	srv := &http.Server{
		Addr:         "localhost:7002",
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelhttp.NewHandler(s.MakeHTTPHandler(), Name+"-http"),
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