package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/url"
	"strconv"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	"github.com/eclipse/paho.golang/autopaho"
	"github.com/eclipse/paho.golang/paho"
	"github.com/monzo/terrors"
	cache "github.com/patrickmn/go-cache"
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

type mqttScaffold struct {
	cm       *autopaho.ConnectionManager
	clientId string
}

const buttonTopic = "94:b2:16:1d:c1:ed"

func newMqtt(ctx context.Context, brokerAddr string, clientID string) (*mqttScaffold, error) {
	u, err := url.Parse(brokerAddr)
	if err != nil {
		return nil, terrors.Augment(err, "could not parse broker URL", nil)
	}

	scaffold := &mqttScaffold{clientId: clientID}

	cfg := autopaho.ClientConfig{
		ServerUrls:                    []*url.URL{u},
		KeepAlive:                     5,
		CleanStartOnInitialConnection: true,
		SessionExpiryInterval:         60,
		OnConnectionUp: func(cm *autopaho.ConnectionManager, connAck *paho.Connack) {
			slog.InfoContext(ctx, "mqtt connection up, subscribing to BLE events")
			// MQTT v5 shared subscription: the broker delivers each message to
			// only one subscriber in the group, removing the need for a distributed lock.
			topic := "$share/" + Name + "/" + buttonTopic
			if _, err := cm.Subscribe(ctx, &paho.Subscribe{
				Subscriptions: []paho.SubscribeOptions{
					{Topic: topic, QoS: 1},
				},
			}); err != nil {
				slog.ErrorContext(ctx, "failed to subscribe to BLE events", "err", err)
			}
			slog.InfoContext(ctx, "subscribed to BLE events", "topic", topic)
		},
		OnConnectError: func(err error) {
			slog.ErrorContext(ctx, "mqtt connection error", "err", err)
		},
		ClientConfig: paho.ClientConfig{
			ClientID: clientID,
			OnPublishReceived: []func(paho.PublishReceived) (bool, error){
				func(pr paho.PublishReceived) (bool, error) {
					if pr.Packet.Topic == buttonTopic {
						go scaffold.handleButtonEvent(pr.Packet)
						return true, nil
					}
					return false, nil
				},
			},
		},
	}

	cm, err := autopaho.NewConnection(ctx, cfg)
	if err != nil {
		return nil, terrors.Augment(err, "could not create mqtt connection", nil)
	}
	err = cm.AwaitConnection(ctx)
	if err != nil {
		return nil, terrors.Augment(err, "could not await mqtt connection", nil)
	}
	scaffold.cm = cm

	return scaffold, nil
}

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

var tracer = otel.Tracer(Name)

func (r *mqttScaffold) shellyRPCResp(ctx context.Context, topic string, rpcMethod string, paramsJson map[string]any) (_ *paho.Publish, err error) {
	ctx, span := tracer.Start(ctx, "mqtt_call.shellyRPC")
	defer span.End()
	defer func() {
		if err != nil {
			span.RecordError(err)
		}
	}()

	errParams := map[string]string{"rpcMethod": rpcMethod, "paramsJson": fmt.Sprint(paramsJson)}

	recv := make(chan *paho.Publish, 1)
	replyTopic := fmt.Sprintf("%s/%s", topic, r.clientId)
	// shelly replies on dst/rpc, see https://shelly-api-docs.shelly.cloud/gen2/ComponentsAndServices/Mqtt#step-6-receive-notifications-over-mqtt
	replySubTopic := replyTopic + "/rpc"
	errParams["replyTopic"] = replyTopic

	removeHandler := r.cm.AddOnPublishReceived(func(pr autopaho.PublishReceived) (bool, error) {
		if pr.Packet.Topic != replySubTopic {
			return false, nil
		}
		span.AddEvent("mqtt_receive", trace.WithAttributes(
			attribute.String("topic", pr.Packet.Topic),
			attribute.String("payload", string(pr.Packet.Payload)),
		))
		recv <- pr.Packet
		return true, nil
	})
	defer removeHandler()

	if _, err := r.cm.Subscribe(ctx, &paho.Subscribe{
		Subscriptions: []paho.SubscribeOptions{
			{Topic: replySubTopic, QoS: 1},
		},
	}); err != nil {
		return nil, terrors.Augment(err, "could not subscribe to topic", errParams)
	}
	defer func() {
		_, _ = r.cm.Unsubscribe(ctx, &paho.Unsubscribe{Topics: []string{replySubTopic}})
	}()

	uniqueId := strconv.FormatInt(time.Now().UnixNano(), 10)
	payload, err := json.Marshal(map[string]any{
		"id":     uniqueId,
		"src":    replyTopic,
		"method": rpcMethod,
		"params": paramsJson,
	})
	if err != nil {
		return nil, terrors.Augment(err, "could not marshal payload", errParams)
	}

	if _, err := r.cm.Publish(ctx, &paho.Publish{
		QoS:     1,
		Topic:   topic,
		Payload: payload,
	}); err != nil {
		return nil, terrors.Augment(err, "could not publish message", errParams)
	}

	select {
	case msg := <-recv:
		return msg, nil
	case <-ctx.Done():
		return nil, terrors.Augment(ctx.Err(), "context cancelled", errParams)
	}
}

func (r *mqttScaffold) handleButtonEvent(packet *paho.Publish) {
	ctx := bedrock.ContextForModule(Name, context.Background())
	ctx, span := tracer.Start(ctx, "mqtt_handle.handleButtonEvent")
	span.AddEvent("mqtt_receive", trace.WithAttributes(attribute.String("topic", packet.Topic), attribute.String("payload", string(packet.Payload))))

	defer span.End()

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
	slog.Info("BLE event", "button", button)
	buttonEvent.With(prometheus.Labels{"button": fmt.Sprintf("[%d, %d, %d, %d]", button[0], button[1], button[2], button[3])}).Inc()

	// short press of the 1st button
	if button[0] == 254 {
		// toggle both plugs
		go func() {
			_, err = r.shellyRPCResp(ctx, "shelly/plug103/rpc", "Switch.Toggle", map[string]any{"id": 0})
			if err != nil {
				slog.ErrorContext(ctx, "could not toggle plug", "err", err)
			}
		}()
		go func() {
			_, err = r.shellyRPCResp(ctx, "shelly/plug104/rpc", "Switch.Toggle", map[string]any{"id": 0})
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
		lightStatus, err := r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.GetStatus", map[string]any{"id": 0})
		if err != nil {
			span.RecordError(err)
			slog.Error("could not get light status", "err", err)
			return
		}
		var parsed shellyLightStatusResponse
		if err := json.Unmarshal(lightStatus.Payload, &parsed); err != nil {
			span.RecordError(err)
			slog.Error("could not parse light status", "err", err)
			return
		}

		if parsed.Result.Output && parsed.Result.Brightness < 90 {
			highBrightness, err := config.Get(ctx, "mqtt/lights/aquariumHigh").Int(70)
			if err != nil {
				slog.WarnContext(ctx, "could not get aquarium low brightness config", "err", err)
			}
			// if the light is on but dim, make it bright
			_, err = r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.Set", map[string]any{"id": 0, "brightness": highBrightness, "on": true})
			if err != nil {
				slog.WarnContext(ctx, "could not set light", "err", err)
			}
		} else {
			lowBrightness, err := config.Get(ctx, "mqtt/lights/aquariumLow").Int(4)
			if err != nil {
				slog.WarnContext(ctx, "could not get aquarium low brightness config", "err", err)
			}
			// otherwise it's off (so make it on + dim) or it's bright (do the same)
			_, err = r.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Light.Set", map[string]any{"id": 0, "brightness": lowBrightness, "on": true})
			if err != nil {
				slog.WarnContext(ctx, "could not set light", "err", err)
			}
		}
	}
}

var seenPIDs = cache.New(10*time.Second, 10*time.Second)

func pidSeen(pid int) bool {
	found, _ := seenPIDs.IncrementInt(strconv.Itoa(pid), 1)
	return found != 0
}
