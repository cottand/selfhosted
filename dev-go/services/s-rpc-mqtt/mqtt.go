package module

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

type BLEEvent struct {
	Addr        string      `json:"addr"`
	RSSI        int         `json:"rssi"`
	LocalName   string      `json:"local_name"`
	ServiceData ServiceData `json:"service_data"`
}

type ServiceData struct {
	Encryption    bool  `json:"encryption"`
	BTHomeVersion int   `json:"BTHome_version"`
	PID           int   `json:"pid"`
	Battery       int   `json:"battery"`
	Button        []int `json:"button"`
}

type mqttRouter struct {
	c mqtt.Client
}

func (r *mqttRouter) setupMqttRoutes() {
}

func (r *mqttRouter) start(ctx context.Context) error {
	defer r.c.Disconnect(250)
	if token := r.c.Connect(); token.Wait() && token.Error() != nil {
		return token.Error()
	}
	if token := r.c.Subscribe("94:b2:16:1d:c1:ed", 1, handleButtonEvent); token.Wait() && token.Error() != nil {
		return token.Error()
	}

	<-ctx.Done()
	return ctx.Err()
}

var processed = make(map[uint16]bool, 2^8)
var processedMutex sync.Mutex

func handleButtonEvent(client mqtt.Client, message mqtt.Message) {
	defer message.Ack()

	processedMutex.Lock()
	defer processedMutex.Unlock()
	if processed[message.MessageID()] {
		return
	}
	processed[message.MessageID()] = true

	event := BLEEvent{}
	err := json.Unmarshal(message.Payload(), &event)
	if err != nil {
		slog.Error("could not parse BLE event", "err", err, "payload", string(message.Payload()))
		return
	}

	slog.Info("BLE event", "button", event.ServiceData.Button)

}
