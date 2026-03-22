package module

import (
	"cloud.google.com/go/bigquery"
	"context"
	"errors"
	"github.com/cottand/selfhosted/dev-go/lib/bigq"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"log/slog"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

type scaffold struct {
	bq *bigquery.Client
}

func InitService() (*bedrock.Service, string, error) {
	var name = "s-web-github-webhook"
	ctx := bedrock.ContextForModule(name, context.Background())
	bqClient, err := bigq.NewClient(ctx, "bigquery-querier-editor")
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	s := &scaffold{
		bq: bqClient,
	}

	srv := &http.Server{
		Addr:         "localhost:7002",
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
				terrors.Augment(srv.Close(), "failed to close http server", nil),
				terrors.Augment(bqClient.Close(), "failed to close bq client", nil),
				terrors.Augment(serverErr, "failed to close server", nil),
			)
		},
	}
	return &service, name, nil
}
