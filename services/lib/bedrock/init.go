package bedrock

import (
	"context"
	"fmt"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"log/slog"
	"net"
	"net/http"
	"os"
	"strconv"
	"time"
)

import (
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func Init(ctx context.Context) (shutdown func(ctx2 context.Context) error) {
	http.Handle("/metrics", promhttp.Handler())

	shutdown, err := setupOTelSDK(ctx)

	if err != nil {
		err = terrors.Augment(err, "failed to start otlp sdk", nil)
		log.Fatalln(err)
	}

	slog.Info("bedrock initialized")

	d, err := NixAssetsDir()
	if err != nil {
		err = terrors.Augment(err, "failed to init bedrock nixAssetsDir", nil)
		log.Fatalln(err)
	}
	slog.Info("using Nix assets", "dir", d)

	return shutdown
}

func GetBaseConfig() (*BaseConfig, error) {
	port, ok := os.LookupEnv("HTTP_PORT")
	if !ok {
		slog.Warn("missing HTT_PORT environment variable, defaulting to 8080")
		port = "8080"
	}
	portNum, err := strconv.Atoi(port)
	if err != nil {
		return nil, terrors.Augment(err, "invalid env config for http port", nil)
	}
	host, ok := os.LookupEnv("HTTP_HOST")
	if !ok {
		return nil, terrors.New("no_env", "missing env config for http host", nil)
	}

	return &BaseConfig{
		HttpHost: host,
		HttpPort: portNum,
	}, nil
}

type BaseConfig struct {
	HttpHost string
	HttpPort int
}

func (c *BaseConfig) HttpBind() string {
	return fmt.Sprint(c.HttpHost, ":", strconv.Itoa(c.HttpPort))
}

func Serve(ctx context.Context, mux *http.ServeMux) {
	otelMux := otelhttp.NewHandler(mux, "/")

	config, err := GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to get config", nil).Error())
	}

	srv := &http.Server{
		Addr:         config.HttpHost + ":" + strconv.Itoa(config.HttpPort),
		BaseContext:  func(_ net.Listener) context.Context { return ctx },
		ReadTimeout:  time.Second,
		WriteTimeout: 10 * time.Second,
		Handler:      otelMux,
	}

	err = srv.ListenAndServe()

	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to run server", nil).Error())
	}
}
