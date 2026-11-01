package module

import (
	"testing"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/stretchr/testify/assert"
)

func TestChangedLight(t *testing.T) {
	tests := []struct {
		name    string
		topic   string
		payload string
		changed bool
	}{
		{
			name:    "plug switched",
			topic:   "shelly/plug103/events/rpc",
			payload: `{"dst":"shelly/plug103/events","method":"NotifyStatus","params":{"switch:0":{"output":true,"source":"MQTT"},"ts":1793548257.21},"src":"shellypluspluguk-441d648dd7fc"}`,
			changed: true,
		},
		{
			name:    "dimmable light dimmed",
			topic:   "shelly/rgb105/events/rpc",
			payload: `{"dst":"shelly/rgb105/events","method":"NotifyStatus","params":{"light:0":{"brightness":5,"output":true,"source":"MQTT"},"ts":1793548420.37},"src":"shellyplusrgbwpm-ecc9ff4c62b8"}`,
			changed: true,
		},
		{
			name:    "device connected",
			topic:   "shelly/plug104/events/rpc",
			payload: `{"method":"NotifyFullStatus","params":{"switch:0":{"id":0,"output":false,"apower":0}}}`,
			changed: true,
		},
		{
			name:    "power reading only",
			topic:   "shelly/plug103/events/rpc",
			payload: `{"dst":"shelly/plug103/events","method":"NotifyStatus","params":{"switch:0":{"apower":2.4},"ts":1793548258.01},"src":"shellypluspluguk-441d648dd7fc"}`,
		},
		{
			name:    "periodic energy report",
			topic:   "shelly/plug103/events/rpc",
			payload: `{"dst":"shelly/plug103/events","method":"NotifyStatus","params":{"switch:0":{"aenergy":{"by_minute":[86.506,83.606,86.506],"minute_ts":1793548320,"total":26246.002},"apower":5.2,"current":0.03,"voltage":242.2},"ts":1793548320.0},"src":"shellypluspluguk-441d648dd7fc"}`,
		},
		{
			name:    "other component",
			topic:   "shelly/plug103/events/rpc",
			payload: `{"method":"NotifyStatus","params":{"sys":{"uptime":3}}}`,
		},
		{
			name:    "other method",
			topic:   "shelly/plug103/events/rpc",
			payload: `{"method":"NotifyEvent","params":{"events":[]}}`,
		},
		{
			name:    "unknown device",
			topic:   "shelly/pill107/events/rpc",
			payload: `{"method":"NotifyStatus","params":{"switch:0":{"output":true}}}`,
		},
		{
			name:    "other topic",
			topic:   "shelly/plug103/rpc",
			payload: `{"method":"NotifyStatus","params":{"switch:0":{"output":true}}}`,
		},
		{
			name:    "malformed payload",
			topic:   "shelly/plug103/events/rpc",
			payload: `not json`,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, changed := changedLight(tt.topic, []byte(tt.payload))
			assert.Equal(t, tt.changed, changed)
		})
	}
}

func TestBroadcasterDeliversToAllSubscribers(t *testing.T) {
	b := newLightBroadcaster()
	first, unsubscribeFirst := b.subscribe()
	defer unsubscribeFirst()
	second, unsubscribeSecond := b.subscribe()
	defer unsubscribeSecond()

	b.publish(&pb.LightStatus{Id: "plug103"})

	assert.Equal(t, "plug103", (<-first).Id)
	assert.Equal(t, "plug103", (<-second).Id)
}

func TestBroadcasterEndsSlowSubscriberOnly(t *testing.T) {
	b := newLightBroadcaster()
	slow, unsubscribeSlow := b.subscribe()
	defer unsubscribeSlow()
	healthy, unsubscribeHealthy := b.subscribe()
	defer unsubscribeHealthy()

	for range subscriberBuffer + 1 {
		b.publish(&pb.LightStatus{Id: "plug103"})
		<-healthy
	}
	b.publish(&pb.LightStatus{Id: "plug104"})

	for range subscriberBuffer {
		<-slow
	}
	_, open := <-slow
	assert.False(t, open, "slow subscriber should be closed after overflowing")
	assert.Equal(t, "plug104", (<-healthy).Id)
}

func TestBroadcasterUnsubscribeStopsDelivery(t *testing.T) {
	b := newLightBroadcaster()
	updates, unsubscribe := b.subscribe()
	unsubscribe()

	b.publish(&pb.LightStatus{Id: "plug103"})

	assert.Empty(t, updates)
}

func TestBroadcasterClose(t *testing.T) {
	b := newLightBroadcaster()
	updates, unsubscribe := b.subscribe()

	b.close()
	unsubscribe()

	_, open := <-updates
	assert.False(t, open)

	late, _ := b.subscribe()
	_, open = <-late
	assert.False(t, open, "subscribing after close should not wait forever")
}
