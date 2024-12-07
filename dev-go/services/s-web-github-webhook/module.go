package module

import (
	"cloud.google.com/go/bigquery"
	"context"
	"errors"
	"github.com/cottand/selfhosted/dev-go/lib/bigq"
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

var Name, slog, tracer = bedrock.New("s-web-github-webhook")

type scaffold struct {
	nomad s_rpc_nomad_api.NomadApiClient
	bq    *bigquery.Client
}

func InitService(ctx context.Context) (*mono.Service, string, error) {
	conn, err := bedrock.NewGrpcConn()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	bqClient, err := bigq.NewClient(ctx, "bigquery-querier-editor")

	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	s := &scaffold{
		nomad: s_rpc_nomad_api.NewNomadApiClient(conn),
		bq:    bqClient,
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
			slog.Error("failed to start HTTP: "+terrors.Propagate(err).Error(), "service", Name)
			serverErr = err
		}
	}()

	service := mono.Service{
		Name: Name,
		OnShutdown: func() error {
			return errors.Join(
				terrors.Augment(conn.Close(), "failed to close grpc conn", nil),
				terrors.Augment(srv.Close(), "failed to close grpc server", nil),
				terrors.Augment(bqClient.Close(), "failed to close bq client", nil),
				terrors.Augment(serverErr, "failed to close server", nil),
			)
		},
	}
	return &service, Name, nil
}
