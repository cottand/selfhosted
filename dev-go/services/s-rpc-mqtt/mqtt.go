package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/locks"
	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
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

	for {
		// service will block here until someone else releases the lock
		lock, err := locks.Grab(ctx, fmt.Sprintf("services/%s/mqtt-leader", Name))
		if err != nil {
			return terrors.Augment(err, "failed to grab mqtt-leader lock", nil)
		}
		leaderGauge.Set(1)

		slog.InfoContext(ctx, "became mqtt leader 🎉 starting router")

		if token := r.c.Subscribe("94:b2:16:1d:c1:ed", 1, r.handleButtonEvent); token.Wait() && token.Error() != nil {
			return token.Error()
		}

		select {
		case <-ctx.Done():
			// leave
			leaderGauge.Set(0)
			return ctx.Err()
		case <-lock.Lost:
			// try again!
			leaderGauge.Set(0)
			slog.InfoContext(ctx, "mqtt leadership lost, retrying")
		}
	}

}

var tracer = otel.Tracer(Name)

func (r *mqttRouter) shellyRPCResp(ctx context.Context, topic string, rpcMethod string, paramsJson string) (_ mqtt.Message, err error) {
	ctx, span := tracer.Start(ctx, "mqtt_call.shellyRPC")
	defer span.End()
	defer func() {
		if err != nil {
			span.RecordError(err)
		}
	}()

	errParams := map[string]string{"rpcMethod": rpcMethod, "paramsJson": paramsJson}
	recv := make(chan mqtt.Message)

	replyTopic := fmt.Sprintf("%s/rpc", topic)
	errParams["replyTopic"] = replyTopic
	t := r.c.Subscribe(replyTopic, 1, func(client mqtt.Client, message mqtt.Message) {
		recv <- message
		span.AddEvent("mqtt_receive", trace.WithAttributes(attribute.String("topic", message.Topic()), attribute.String("payload", string(message.Payload()))))
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

func (r *mqttRouter) handleButtonEvent(client mqtt.Client, message mqtt.Message) {
	ctx := bedrock.ContextForModule(Name, context.Background())
	ctx, span := tracer.Start(ctx, "mqtt_handle.handleButtonEvent")
	span.AddEvent("mqtt_receive", trace.WithAttributes(attribute.String("topic", message.Topic()), attribute.String("payload", string(message.Payload()))))

	defer span.End()
	defer message.Ack()

	event := BLEEvent{}
	err := json.Unmarshal(message.Payload(), &event)
	if err != nil {
		slog.Error("could not parse BLE event", "err", err, "payload", string(message.Payload()))
		return
	}

	button := event.ServiceData.Button
	slog.Info("BLE event", "button", button)
	buttonEvent.With(prometheus.Labels{"button": fmt.Sprintf("[%d, %d, %d, %d]", button[0], button[1], button[2], button[3])}).Inc()

	// short press of the 1st button
	if button[0] == 254 {
		// toggle both plugs
		_, err = r.shellyRPCResp(ctx, "shelly/plug103/rpc", "Switch.Toggle", `{id: 0}`)
		if err != nil {
			slog.ErrorContext(ctx, "could not toggle plug", "err", err)
		}
		_, err = r.shellyRPCResp(ctx, "shelly/plug104/rpc", "Switch.Toggle", `{id: 0}`)
		if err != nil {
			slog.ErrorContext(ctx, "could not toggle plug", "err", err)
		}
	}

	// single press of the 4th button
	if button[3] == 1 {
		// simply toggle the light
		if _, err := r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.Toggle", `{id: 0}`); err != nil {
			slog.ErrorContext(ctx, "could not toggle light", "err", err)
		}
	}

	// double press of the 4th button
	if button[3] == 2 {
		lightStatus, err := r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.GetStatus", `{id: 0}`)
		if err != nil {
			slog.Error("could not get light status", "err", err)
			return
		}
		slog.Info("light status", "status", string(lightStatus.Payload()))
	}
}
