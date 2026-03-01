package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"sync"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/locks"
	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/monzo/terrors"
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
	c        mqtt.Client
	clientId string
}

func (r *mqttRouter) setupMqttRoutes() {
}

func (r *mqttRouter) start(ctx context.Context) error {
	defer r.c.Disconnect(250)
	if token := r.c.Connect(); token.Wait() && token.Error() != nil {
		return token.Error()
	}
	if token := r.c.Subscribe("94:b2:16:1d:c1:ed", 1, r.handleButtonEvent); token.Wait() && token.Error() != nil {
		return token.Error()
	}

	<-ctx.Done()
	return ctx.Err()
}

func (r *mqttRouter) shellyRPCResp(ctx context.Context, topic string, rpcMethod string, paramsJson string) (mqtt.Message, error) {
	errParams := map[string]string{"rpcMethod": rpcMethod, "paramsJson": paramsJson}
	recv := make(chan mqtt.Message)

	replyTopic := fmt.Sprintf("%s/rpc", topic)
	errParams["replyTopic"] = replyTopic
	t := r.c.Subscribe(replyTopic, 1, func(client mqtt.Client, message mqtt.Message) {
		recv <- message
	})
	if t.Wait() && t.Error() != nil {
		return nil, terrors.Augment(t.Error(), "could not subscribe to topic", errParams)
	}
	defer r.c.Unsubscribe(replyTopic)

	uniqueId := strconv.FormatInt(time.Now().UnixNano(), 10)
	r.c.Publish(topic, 1, false, []byte(fmt.Sprintf(`{"id":%s, "src":"%s", "method":"%s", "params": %s}`, uniqueId, r.clientId, rpcMethod, paramsJson)))

	select {
	case msg := <-recv:
		return msg, nil
	case <-ctx.Done():
		return nil, terrors.Augment(ctx.Err(), "context cancelled", errParams)
	}
}

var processed = make(map[uint16]bool, 2^8)
var processedMutex sync.Mutex

func (r *mqttRouter) handleButtonEvent(client mqtt.Client, message mqtt.Message) {
	defer message.Ack()
	lock, err := locks.Grab(fmt.Sprintf("mqtt-%s", message.Topic()))
	if err != nil {
		slog.Error("could not grab lock", "err", err)
		return
	}
	defer lock.Release(context.Background())

	processedMutex.Lock()
	defer processedMutex.Unlock()
	if processed[message.MessageID()] {
		return
	}
	processed[message.MessageID()] = true

	event := BLEEvent{}
	err = json.Unmarshal(message.Payload(), &event)
	if err != nil {
		slog.Error("could not parse BLE event", "err", err, "payload", string(message.Payload()))
		return
	}

	button := event.ServiceData.Button
	slog.Info("BLE event", "button", button)

	// short press of the 1st button
	if button[0] == 254 {
		// toggle both plugs
		client.Publish("shelly/plug103/rpc", 1, false, []byte(`{"id":1, "src":"tmp", "method":"Switch.Toggle", "params": {"id":0}}`))
		client.Publish("shelly/plug104/rpc", 1, false, []byte(`{"id":1, "src":"tmp", "method":"Switch.Toggle", "params": {"id":0}}`))
	}

	// single press of the 4th button
	if button[3] == 1 {
		// simply toggle the light
		client.Publish("shelly/rgb105/rpc", 1, false, []byte(`{"id":1, "src":"tmp", "method":"Light.Toggle", "params": {"id":0}}`))
	}

	// double press of the 4th button
	if button[3] == 2 {
		lightStatus, err := r.shellyRPCResp(context.TODO(), "shelly/rgb105/rpc", "Light.GetStatus", `{id: 0}`)
		if err != nil {
			slog.Error("could not get light status", "err", err)
			return
		}
		slog.Info("light status", "status", string(lightStatus.Payload()))
	}
}
