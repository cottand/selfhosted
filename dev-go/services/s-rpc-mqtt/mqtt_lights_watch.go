package module

import (
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"sync"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
)

// shelly devices publish notifications here by default, see rpc_ntf in
// https://shelly-api-docs.shelly.cloud/gen2/ComponentsAndServices/Mqtt
const lightEventsTopic = "shelly/+/events/rpc"

const (
	lightChangedBuffer = 32
	subscriberBuffer   = 16
)

type shellyNotification struct {
	Method string                     `json:"method"`
	Params map[string]json.RawMessage `json:"params"`
}

type shellyOutputChange struct {
	Output     *bool `json:"output"`
	Brightness *int  `json:"brightness"`
}

// changedLight returns the ID of the light that a message on lightEventsTopic reports as switched
// or dimmed. Lights also notify power readings, which do not count as changes.
func changedLight(topic string, payload []byte) (string, bool) {
	id, ok := strings.CutPrefix(topic, "shelly/")
	if !ok {
		return "", false
	}
	id, ok = strings.CutSuffix(id, "/events/rpc")
	if !ok {
		return "", false
	}
	l, err := findLight(id)
	if err != nil {
		return "", false
	}

	var notification shellyNotification
	if err := json.Unmarshal(payload, &notification); err != nil {
		return "", false
	}
	// devices send NotifyFullStatus when they connect, so this also covers a light coming back
	if notification.Method != "NotifyStatus" && notification.Method != "NotifyFullStatus" {
		return "", false
	}
	rawChange, ok := notification.Params[strings.ToLower(l.component())+":0"]
	if !ok {
		return "", false
	}
	var change shellyOutputChange
	if err := json.Unmarshal(rawChange, &change); err != nil {
		return "", false
	}
	return id, change.Output != nil || change.Brightness != nil
}

// notifyLightChanged must not block as it runs in the mqtt receive loop
func (r *mqttScaffold) notifyLightChanged(ctx context.Context, id string) {
	select {
	case r.lightChanged <- id:
	default:
		slog.WarnContext(ctx, "dropped light change, too many pending", "id", id)
	}
}

// broadcastLightChanges reads the full status of changed lights, because notifications only
// contain what changed
func (r *mqttScaffold) broadcastLightChanges(ctx context.Context) {
	defer r.lightUpdates.close()
	for {
		select {
		case <-ctx.Done():
			return
		case id := <-r.lightChanged:
			status, err := r.getLight(ctx, id)
			if err != nil {
				slog.WarnContext(ctx, "could not read changed light", "id", id, "err", err)
				continue
			}
			r.lightUpdates.publish(status)
		}
	}
}

type lightBroadcaster struct {
	mu          sync.Mutex
	subscribers map[chan *pb.LightStatus]struct{}
	closed      bool
}

func newLightBroadcaster() *lightBroadcaster {
	return &lightBroadcaster{subscribers: map[chan *pb.LightStatus]struct{}{}}
}

// subscribe returns a channel of light updates, which is closed if the subscriber falls behind or
// the broadcaster is closed. The returned func must be called when done.
func (b *lightBroadcaster) subscribe() (<-chan *pb.LightStatus, func()) {
	b.mu.Lock()
	defer b.mu.Unlock()

	updates := make(chan *pb.LightStatus, subscriberBuffer)
	if b.closed {
		close(updates)
		return updates, func() {}
	}
	b.subscribers[updates] = struct{}{}
	return updates, func() {
		b.mu.Lock()
		defer b.mu.Unlock()
		delete(b.subscribers, updates)
	}
}

func (b *lightBroadcaster) publish(status *pb.LightStatus) {
	b.mu.Lock()
	defer b.mu.Unlock()

	for updates := range b.subscribers {
		select {
		case updates <- status:
		default:
			delete(b.subscribers, updates)
			close(updates)
		}
	}
}

func (b *lightBroadcaster) close() {
	b.mu.Lock()
	defer b.mu.Unlock()

	b.closed = true
	for updates := range b.subscribers {
		delete(b.subscribers, updates)
		close(updates)
	}
}
