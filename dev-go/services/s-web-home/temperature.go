package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"sync"
	"time"

	s_rpc_prometheus "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	"github.com/monzo/terrors"
)

const (
	tempPeriod    = 5 * time.Second
	tempUnknown   = "--°C"
	roomTempID    = "room-temp"
	roomTempQuery = "max(digitemp_temperature)"
)

// tankPills maps each aquarium light to the Shelly pill measuring that tank's water
var tankPills = map[string]string{
	"rgb105": "pill107",
	"rgb108": "pill2",
}

func tankTempQuery(pill string) string {
	return fmt.Sprintf(`max(s_rpc_mqtt_pill_temp{shelly_id=%q})`, pill)
}

func tankTempID(lightID string) string { return "temp-" + lightID }

// tempQueries maps the id of each element showing a temperature to the query for it
func tempQueries() map[string]string {
	queries := map[string]string{roomTempID: roomTempQuery}
	for lightID, pill := range tankPills {
		queries[tankTempID(lightID)] = tankTempQuery(pill)
	}
	return queries
}

// cachedTemp is shared by every open page, so viewers do not multiply the queries
type cachedTemp struct {
	mutex sync.Mutex
	value string
	at    time.Time
}

func (s *scaffold) roomTemp(ctx context.Context) string {
	return s.temperature(ctx, roomTempQuery)
}

func (s *scaffold) withTemp(ctx context.Context, l light) light {
	if pill, ok := tankPills[l.ID]; ok {
		l.Temp = s.temperature(ctx, tankTempQuery(pill))
	}
	return l
}

func (s *scaffold) temperature(ctx context.Context, query string) string {
	stored, _ := s.temps.LoadOrStore(query, &cachedTemp{})
	cached := stored.(*cachedTemp)
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

func tempEvent(id, temp string) []byte {
	data, _ := json.Marshal(struct {
		ID    string `json:"id"`
		Value string `json:"value"`
	}{id, temp})
	return []byte("event: temp\ndata: " + string(data) + "\n\n")
}
