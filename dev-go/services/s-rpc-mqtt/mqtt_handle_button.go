package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"sync"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	"github.com/eclipse/paho.golang/paho"
	"github.com/monzo/terrors"
	cache "github.com/patrickmn/go-cache"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

type shellyLightStatusResponse struct {
	Id     int64  `json:"id"`
	Src    string `json:"src"`
	Dst    string `json:"dst"`
	Result struct {
		Id          int    `json:"id"`
		Source      string `json:"source"`
		Output      bool   `json:"output"`
		Brightness  int    `json:"brightness"`
		Temperature struct {
			TC float64 `json:"tC"`
			TF float64 `json:"tF"`
		} `json:"temperature"`
		Aenergy struct {
			Total    float64   `json:"total"`
			ByMinute []float64 `json:"by_minute"`
			MinuteTs int       `json:"minute_ts"`
		} `json:"aenergy"`
		Apower  float64 `json:"apower"`
		Current float64 `json:"current"`
		Voltage float64 `json:"voltage"`
	} `json:"result"`
}

// seenPIDs is a cache so that we can reuse PIDs
var seenPIDs = cache.New(10*time.Second, 10*time.Second)

// cache is thread-safe, but we need seenPIDsLock so that we can compare-and-set
var seenPIDsLock = &sync.Mutex{}

func pidSeen(pid int) bool {
	seenPIDsLock.Lock()
	defer seenPIDsLock.Unlock()
	_, ok := seenPIDs.Get(strconv.Itoa(pid))

	seenPIDs.Set(strconv.Itoa(pid), 1, cache.DefaultExpiration)

	return ok
}

func (r *mqttScaffold) handleButtonEvent(packet *paho.Publish) {
	ctx := bedrock.ContextForModule(Name, context.Background())
	ctx, span := tracer.Start(ctx, "mqtt_handle.handleButtonEvent")
	defer span.End()
	span.AddEvent("mqtt_receive", trace.WithAttributes(attribute.String("topic", packet.Topic), attribute.String("payload", string(packet.Payload))))

	event := BLEEvent{}
	err := json.Unmarshal(packet.Payload, &event)
	if err != nil {
		slog.Error("could not parse BLE event", "err", err, "payload", string(packet.Payload))
		return
	}

	if pidSeen(event.ServiceData.PID) {
		return
	}

	button := event.ServiceData.Button
	slog.InfoContext(ctx, "BLE event", "button", button)
	buttonEvent.With(prometheus.Labels{"button": fmt.Sprintf("[%d, %d, %d, %d]", button[0], button[1], button[2], button[3])}).Inc()

	// double press of the 1st button
	if button[0] == 2 {
		for _, id := range []string{"shelly/plug103/rpc", "shelly/plug104/rpc", "shelly/plug106/rpc"} {
			go func(id string) {
				_, err = r.shellyRPCResp(ctx, id, "Switch.Toggle", map[string]any{"id": 0})
				if err != nil {
					slog.ErrorContext(ctx, "could not toggle plug", "err", err)
				}
			}(id)
		}
	}

	// single press of the 1st button
	if button[0] == 1 {
		go func() {
			_, err = r.shellyRPCResp(ctx, "shelly/plug103/rpc", "Switch.Toggle", map[string]any{"id": 0})
			if err != nil {
				slog.ErrorContext(ctx, "could not toggle plug", "err", err)
			}
		}()
	}

	// short press of the 2nd button
	if button[1] == 254 {
		go func() {
			_, err = r.shellyRPCResp(ctx, "shelly/plug104/rpc", "Switch.Toggle", map[string]any{"id": 0})
			if err != nil {
				slog.ErrorContext(ctx, "could not toggle plug", "err", err)
			}
		}()
	}

	// short press of the 3rd button
	if button[2] == 254 {
		go func() {
			_, err = r.shellyRPCResp(ctx, "shelly/plug106/rpc", "Switch.Toggle", map[string]any{"id": 0})
			if err != nil {
				slog.ErrorContext(ctx, "could not toggle plug", "err", err)
			}
		}()
	}

	// single press of the 4th button
	if button[3] == 1 {
		// simply toggle the light
		if _, err := r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.Toggle", map[string]any{"id": 0}); err != nil {
			slog.ErrorContext(ctx, "could not toggle light", "err", err)
		}
	}

	// double press of the 4th button
	if button[3] == 2 {
		if err := r.handleButton4DoublePress(ctx); err != nil {
			slog.ErrorContext(ctx, "could not handle double press", "err", err)
		}
	}
}

func (r *mqttScaffold) handleButton4DoublePress(ctx context.Context) error {
	lightStatus, err := r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.GetStatus", map[string]any{"id": 0})
	if err != nil {
		return terrors.Augment(err, "could not get light status", nil)
	}
	var parsed shellyLightStatusResponse
	if err := json.Unmarshal(lightStatus.Payload, &parsed); err != nil {
		return terrors.Augment(err, "could not parse light status", nil)
	}
	highBrightness, err := config.Get(ctx, "mqtt/lights/aquariumHigh").Int(70)
	if err != nil {
		slog.WarnContext(ctx, "could not get aquarium low brightness config", "err", err)
	}

	if parsed.Result.Output && parsed.Result.Brightness < highBrightness {
		// if the light is on but dim, make it bright
		_, err = r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.Set", map[string]any{"id": 0, "brightness": highBrightness, "on": true})
		if err != nil {
			return terrors.Augment(err, "could not set light", nil)
		}
	} else {
		lowBrightness, err := config.Get(ctx, "mqtt/lights/aquariumLow").Int(4)
		if err != nil {
			slog.WarnContext(ctx, "could not get aquarium low brightness config", "err", err)
		}
		// otherwise it's off (so make it on + dim) or it's bright (do the same)
		_, err = r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.Set", map[string]any{"id": 0, "brightness": lowBrightness, "on": true})
		if err != nil {
			return terrors.Augment(err, "could not set light", nil)
		}
	}
	return nil
}
