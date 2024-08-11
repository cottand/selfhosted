package bedrock

import (
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strconv"
)

import (
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func Init() {
	http.Handle("/metrics", promhttp.Handler())

	//slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stderr, nil)))

	slog.Info("bedrock initialized")

	d, err := NixAssetsDir()
	if err == nil {
		slog.Info("using Nix assets", "dir", d)
	}
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