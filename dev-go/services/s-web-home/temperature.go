package module

import (
	"context"
	"fmt"
	"log/slog"
	"strconv"
	"time"

	s_rpc_prometheus "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	"github.com/monzo/terrors"
)

const (
	aquariumLight      = "rgb105"
	aquariumTempPeriod = 5 * time.Second
	tempUnknown        = "--°C"
	aquariumTempQuery  = `max(s_rpc_mqtt_pill107_temp{shelly_id="pill107"})`
)

func (s *scaffold) withTemp(ctx context.Context, l light) light {
	if l.ID == aquariumLight {
		l.Temp = s.aquariumTemp(ctx)
	}
	return l
}

// aquariumTemp is shared by every open page, so viewers do not multiply the queries
func (s *scaffold) aquariumTemp(ctx context.Context) string {
	s.tempMutex.Lock()
	defer s.tempMutex.Unlock()

	if !s.tempAt.IsZero() && time.Since(s.tempAt) < s.tempPeriod {
		return s.temp
	}
	// a viewer leaving must not blank the value for the others
	temp, err := fetchAquariumTemp(context.WithoutCancel(ctx))
	if err != nil {
		slog.WarnContext(ctx, "failed to fetch aquarium temperature", "err", terrors.Propagate(err))
		temp = tempUnknown
	}
	s.temp = temp
	s.tempAt = time.Now()
	return temp
}

func fetchAquariumTemp(ctx context.Context) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	response, err := s_rpc_prometheus.QueryInstant(ctx, &s_rpc_prometheus.QueryInstantRequest{PromQLQuery: aquariumTempQuery})
	if err != nil {
		return "", terrors.Augment(err, "failed to query temperature", nil)
	}
	parsed, err := strconv.ParseFloat(response.Result, 64)
	if err != nil {
		return "", terrors.Augment(err, "failed to parse temperature", map[string]string{"result": response.Result})
	}
	return fmt.Sprintf("%.1f°C", parsed), nil
}

func tempEvent(temp string) []byte {
	return []byte("event: temp\ndata: " + temp + "\n\n")
}
