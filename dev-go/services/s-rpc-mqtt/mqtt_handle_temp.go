package module

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/config"
	"github.com/cottand/selfhosted/dev-go/lib/util"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var tempStat = promauto.NewGauge(prometheus.GaugeOpts{
	Namespace: util.KebabToSnakeCase(Name),
	Name:      "pill107_temp",
	Help:      "Temperature as reported by pill107 (likely aquarium temp)",
})

func (r *mqttScaffold) aquariumTempPollingForever(ctx context.Context) error {
	pollPeriod, _ := config.Get(ctx, "mqtt/aquariumTemp/polling_s").Int(30)
	ticker := time.NewTicker(time.Duration(pollPeriod) * time.Second)
	for {
		select {
		case <-ticker.C:
			err := r.aquariumTempPoll(ctx)
			if err != nil {
				slog.ErrorContext(ctx, "failed to poll temp", "err", err)
			}

		case <-ctx.Done():
			return ctx.Err()
		}
	}
}

func (r *mqttScaffold) aquariumTempPoll(ctx context.Context) error {
	ctx, cancel := context.WithDeadline(ctx, time.Now().Add(10*time.Second))
	defer cancel()

	rsp, err := r.shellyRPCResp(ctx, "shelly/pill107/rpc", "Temperature.GetStatus", map[string]any{"id": 200})
	if err != nil {
		return terrors.Augment(err, "could not get temp status", nil)
	}
	var parsed shellyTempStatusResponse
	if err := json.Unmarshal(rsp.Payload, &parsed); err != nil {
		return terrors.Augment(err, "could not parse temp status", nil)
	}

	if parsed.Result != nil {
		tempStat.Set(parsed.Result.TC)
	}

	return nil
}

type shellyTempStatusResponse struct {
	Dst    string `json:"dst"`
	Id     int    `json:"id"`
	Result *struct {
		Id int     `json:"id"`
		TC float64 `json:"tC"`
		TF float64 `json:"tF"`
	} `json:"result"`
	Src string `json:"src"`
}
