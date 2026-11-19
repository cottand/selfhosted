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

const aquariumPill1 = "pill107"
const aquariumPill2 = "pill2"

var tempStat = promauto.NewGaugeVec(prometheus.GaugeOpts{
	Namespace: util.KebabToSnakeCase(Name),
	Name:      "pill_temp",
	Help:      "Temperature as reported by a Shelly pill",
}, []string{"shelly_id"})

func (r *mqttScaffold) aquariumTempPollingForever(ctx context.Context) error {
	pollPeriod, _ := config.Get(ctx, "mqtt/aquariumTemp/polling_s").Int(30)
	ticker := time.NewTicker(time.Duration(pollPeriod) * time.Second)
	for {
		select {
		case <-ticker.C:
			if	err := r.aquariumTempPoll(ctx, aquariumPill1); err != nil {
				slog.ErrorContext(ctx, "failed to poll temp", "err", err)
			}
			if	err := r.aquariumTempPoll(ctx, aquariumPill2); err != nil {
				slog.ErrorContext(ctx, "failed to poll temp", "err", err)
			}

		case <-ctx.Done():
			return ctx.Err()
		}
	}
}

func (r *mqttScaffold) aquariumTempPoll(ctx context.Context, shellyID string) error {
	ctx, cancel := context.WithDeadline(ctx, time.Now().Add(10*time.Second))
	defer cancel()

	rsp, err := r.shellyRPCResp(ctx, "shelly/"+shellyID+"/rpc", "Temperature.GetStatus", map[string]any{"id": 200})
	if err != nil {
		return terrors.Augment(err, "could not get temp status", nil)
	}
	var parsed shellyTempStatusResponse
	if err := json.Unmarshal(rsp.Payload, &parsed); err != nil {
		return terrors.Augment(err, "could not parse temp status", nil)
	}

	if parsed.Result != nil {
		tempStat.WithLabelValues(shellyID).Set(parsed.Result.TC)
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
