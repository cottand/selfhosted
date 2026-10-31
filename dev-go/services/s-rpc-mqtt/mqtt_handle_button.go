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
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/eclipse/paho.golang/paho"
	"github.com/monzo/terrors"
	cache "github.com/patrickmn/go-cache"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

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

var aquariumLights = []string{"rgb105", "rgb108"}

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

	toggle := func(ids ...string) {
		for _, id := range ids {
			go func() {
				if err := r.toggleLight(ctx, id); err != nil {
					slog.ErrorContext(ctx, "could not toggle light", "id", id, "err", err)
				}
			}()
		}
	}

	// double press of the 1st button
	if button[0] == 2 {
		toggle("plug103", "plug104", "plug106")
	}

	// single press of the 1st button
	if button[0] == 1 {
		toggle("plug103")
	}

	// short press of the 2nd button
	if button[1] == 254 {
		toggle("plug104")
	}

	// short press of the 3rd button
	if button[2] == 254 {
		toggle("plug106")
	}

	// single press of the 4th button
	if button[3] == 1 {
		toggle(aquariumLights...)
	}

	// double press of the 4th button
	if button[3] == 2 {
		for _, id := range aquariumLights {
			go func() {
				if err := r.aquariumLightsDoublePress(ctx, id); err != nil {
					slog.ErrorContext(ctx, "could not handle double press", "id", id, "err", err)
				}
			}()
		}
	}
}

func (r *mqttScaffold) aquariumLightsDoublePress(ctx context.Context, id string) error {
	status, err := r.getLight(ctx, id)
	if err != nil {
		return terrors.Augment(err, "could not get light status", nil)
	}
	highBrightness, err := config.Get(ctx, "mqtt/lights/aquariumHigh").Int(70)
	if err != nil {
		slog.WarnContext(ctx, "could not get aquarium high brightness config", "err", err)
	}

	// if the light is on but dim, make it bright.
	// Otherwise it's off (so make it on + dim) or it's bright (do the same)
	brightness := highBrightness
	if !status.On || status.GetBrightness() >= int32(highBrightness) {
		brightness, err = config.Get(ctx, "mqtt/lights/aquariumLow").Int(4)
		if err != nil {
			slog.WarnContext(ctx, "could not get aquarium low brightness config", "err", err)
		}
	}

	err = r.setLight(ctx, &pb.SetLightRequest{Id: id, On: new(true), Brightness: new(int32(brightness))})
	return terrors.Augment(err, "could not set light", nil)
}
