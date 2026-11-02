package module

import (
	"context"
	"testing"
	"time"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	prom "github.com/prometheus/client_golang/api/prometheus/v1"
	"github.com/prometheus/common/model"
	"github.com/stretchr/testify/assert"
)

type fakeAPI struct {
	prom.API
	value model.Value
}

func (f fakeAPI) Query(context.Context, string, time.Time, ...prom.Option) (model.Value, prom.Warnings, error) {
	return f.value, nil, nil
}

func TestQueryInstant(t *testing.T) {
	handler := &ProtoHandler{prom: fakeAPI{value: model.Vector{{Value: 24.5}}}}

	response, err := handler.QueryInstant(context.Background(), &pb.QueryInstantRequest{})

	assert.NoError(t, err)
	assert.Equal(t, "24.5", response.Result)
}

func TestQueryInstantWithoutResults(t *testing.T) {
	handler := &ProtoHandler{prom: fakeAPI{value: model.Vector{}}}

	_, err := handler.QueryInstant(context.Background(), &pb.QueryInstantRequest{})

	assert.Error(t, err)
}
