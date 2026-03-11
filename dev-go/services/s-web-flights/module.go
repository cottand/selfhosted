package module

import (
	"context"
	"errors"
	"log"
	"log/slog"
	"net"
	"net/http"
	"time"

	"cloud.google.com/go/bigquery"
	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

type scaffold struct {
	flights s_rpc_flights.FlightsClient
	bq      *bigquery.Client
}

func InitService() (*bedrock.Service, string, error) {
	var name = "s-web-flights"
	ctx := bedrock.ContextForModule(name, context.Background())
	conn, err := bedrock.NewGrpcConn()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	s := &scaffold{
		flights: s_rpc_flights.NewFlightsClient(conn),
	}

	srv := &http.Server{
		Addr:         "localhost:7003",
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelhttp.NewHandler(s.MakeHTTPHandler(), name+"-http"),
	}

	var serverErr error
	go func() {
		err := srv.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.ErrorContext(ctx, "failed to start HTTP: "+terrors.Propagate(err).Error())
			serverErr = err
		}
	}()

	service := bedrock.Service{
		Name: name,
		OnShutdown: func() error {
			return errors.Join(
				terrors.Augment(conn.Close(), "failed to close grpc conn", nil),
				terrors.Augment(srv.Close(), "failed to close grpc server", nil),
				terrors.Augment(serverErr, "failed to close server", nil),
			)
		},
	}
	return &service, name, nil
}
