package module

import (
	"context"
	"fmt"
	"log/slog"
	"strconv"
	"sync"
	"time"

	s_rpc_prometheus "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	"github.com/monzo/terrors"
)

const (
	aquariumLight     = "rgb105"
	tempPeriod        = 5 * time.Second
	tempUnknown       = "--°C"
	aquariumTempQuery = `max(s_rpc_mqtt_pill_temp{shelly_id="pill107"})`
	roomTempQuery     = "max(digitemp_temperature)"
)

// cachedTemp is shared by every open page, so viewers do not multiply the queries
type cachedTemp struct {
	mutex sync.Mutex
	value string
	at    time.Time
}

func (s *scaffold) aquariumTemp(ctx context.Context) string {
	return s.temperature(ctx, &s.aquarium, aquariumTempQuery)
}

func (s *scaffold) roomTemp(ctx context.Context) string {
	return s.temperature(ctx, &s.room, roomTempQuery)
}

func (s *scaffold) withTemp(ctx context.Context, l light) light {
	if l.ID == aquariumLight {
		l.Temp = s.aquariumTemp(ctx)
	}
	return l
}

func (s *scaffold) temperature(ctx context.Context, cached *cachedTemp, query string) string {
	cached.mutex.Lock()
	defer cached.mutex.Unlock()

	if !cached.at.IsZero() && time.Since(cached.at) < s.tempPeriod {
		return cached.value
	}
	// a viewer leaving must not blank the value for the others
	temp, err := fetchTemp(context.WithoutCancel(ctx), query)
	if err != nil {
		slog.WarnContext(ctx, "failed to fetch temperature", "query", query, "err", terrors.Propagate(err))
		temp = tempUnknown
	}
	cached.value = temp
	cached.at = time.Now()
	return temp
}

func fetchTemp(ctx context.Context, query string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	response, err := s_rpc_prometheus.QueryInstant(ctx, &s_rpc_prometheus.QueryInstantRequest{PromQLQuery: query})
	if err != nil {
		return "", terrors.Augment(err, "failed to query temperature", nil)
	}
	parsed, err := strconv.ParseFloat(response.Result, 64)
	if err != nil {
		return "", terrors.Augment(err, "failed to parse temperature", map[string]string{"result": response.Result})
	}
	return fmt.Sprintf("%.1f°C", parsed), nil
}

// tempEvent is named after the id of the element that shows the temperature
func tempEvent(id, temp string) []byte {
	return []byte("event: " + id + "\ndata: " + temp + "\n\n")
}
