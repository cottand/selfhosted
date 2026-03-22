package module

import (
	"context"
	"errors"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log/slog"
	"net"
	"net/http"
	"time"
)
import "github.com/cottand/selfhosted/dev-go/lib/bedrock"

const Name = "s-web-portfolio"

func InitService() (*bedrock.Service, string, error) {
	ctx := bedrock.ContextForModule(Name, context.Background())
	scaff := &scaffold{
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
			if serverErr != nil {
				return terrors.Augment(serverErr, "failed to close http server", nil)
			}
			return nil
		},
	}
	return service, Name, nil
}
