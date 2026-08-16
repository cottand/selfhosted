package module

import (
	"net/http"
	"os"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_prometheus "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	promapi "github.com/prometheus/client_golang/api"
	prom "github.com/prometheus/client_golang/api/prometheus/v1"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
)

const Name = "s-rpc-prometheus"

func InitService() (*bedrock.Service, string, error) {
	c, err := promapi.NewClient(promapi.Config{
		Address:      "http://" + os.Getenv("NOMAD_UPSTREAM_ADDR_prometheus"),
		RoundTripper: otelhttp.NewTransport(http.DefaultTransport),
	})
	if err != nil {
		return nil, Name, err
	}
	api := prom.NewAPI(c)
	protoHandler := &ProtoHandler{
		prom: api,
	}
	return &bedrock.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_prometheus.RegisterPrometheusServer(srv, protoHandler)
		},
		OnShutdown: func() error { return nil },
	}, Name, nil
}
