package module

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"time"

	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

type scaffold struct{}

func InitService() (*bedrock.Service, string, error) {
	var name = "s-web-flights"
	ctx := bedrock.ContextForModule(name, context.Background())
	s := &scaffold{}

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
				terrors.Augment(srv.Close(), "failed to close http server", nil),
				terrors.Augment(serverErr, "failed to close server", nil),
			)
		},
	}
	return &service, name, nil
}
