package bedrock

import (
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"path"
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

	d, err := LocalNixDir()
	if err == nil {
		slog.Info("using local Nix dir", "dir", d)
	}
}

// LocalNixDir returns the parent of the parent dir the binary is in.
// For Nix-built binaries, this usually matches
// the root of the derivation the binary is being run from.
//
// Use this to access files included in the build via the Nix derivation.
func LocalNixDir() (string, error) {
	e, err := os.Executable()
	if err != nil {
		return "", terrors.Propagate(err)
	}
	return path.Dir(path.Dir(e)), nil
}

func GetBaseConfig() (*BaseConfig, error) {
	port, ok := os.LookupEnv("HTTP_PORT")
	if !ok {
		return nil, terrors.New("no_env", "missing env config for http port", nil)
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
