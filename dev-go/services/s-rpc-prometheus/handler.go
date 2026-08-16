package module

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	"github.com/monzo/terrors"
	prom "github.com/prometheus/client_golang/api/prometheus/v1"
	"github.com/prometheus/common/model"
)

type ProtoHandler struct {
	pb.UnimplementedPrometheusServer
	prom prom.API
}

func (h *ProtoHandler) QueryInstant(ctx context.Context, req *pb.QueryInstantRequest) (*pb.QueryInstantResponse, error) {
	v, warning, err := h.prom.Query(ctx, req.PromQLQuery, time.Time{})
	if err != nil {
		return nil, terrors.Augment(err, "failed to query prometheus",
			map[string]string{
				"query":   req.PromQLQuery,
				"warning": fmt.Sprint(warning),
			})
	}

	if warning != nil {
		slog.Warn("prometheus query warning", "warning", warning, "query", req.PromQLQuery)
	}

	switch v := v.(type) {
	case model.Vector:
		return &pb.QueryInstantResponse{
			// we don't have a need for queries that return more than a single value yet!
			Result: fmt.Sprint(v[0].Value),
			Type:   "float64",
		}, nil
	default:
		return nil, terrors.New("unexpected_err_type", "unexpected result type", map[string]string{
			"type": v.Type().String(),
		})
	}
}
