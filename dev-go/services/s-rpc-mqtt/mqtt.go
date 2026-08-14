package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/url"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/locks"
	"github.com/cottand/selfhosted/dev-go/lib/util"
	"github.com/eclipse/paho.golang/autopaho"
	"github.com/eclipse/paho.golang/paho"
	"github.com/monzo/terrors"
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
	leader   *leaderState
}

type leaderState struct {
	isLeader *atomic.Bool
}

func newLeaderState(ctx context.Context) *leaderState {
	ls := &leaderState{
		isLeader: &atomic.Bool{},
	}
	go ls.run(ctx)
	return ls
}

func (ls *leaderState) run(ctx context.Context) {
	lockKey := fmt.Sprintf("services/%s/mqtt-leader", Name)
	for {
		if ctx.Err() != nil {
			return
		}
		lock, err := locks.Grab(ctx, lockKey)
		if err != nil {
			slog.ErrorContext(ctx, "failed to grab mqtt-leader lock", "err", err)
			continue
		}
		ls.isLeader.Store(true)
		leaderGauge.Set(1)
		slog.InfoContext(ctx, "became mqtt leader")

		select {
		case <-ctx.Done():
			lock.Release(ctx)
			return
		case <-lock.Lost:
			slog.InfoContext(ctx, "lost mqtt-leader lock")
		}
		ls.isLeader.Store(false)
		leaderGauge.Set(0)
	}
}

const buttonTopic = "94:b2:16:1d:c1:ed"

func newMqtt(ctx context.Context, brokerAddr string, clientID string) (*mqttScaffold, error) {
	u, err := url.Parse(brokerAddr)
	if err != nil {
		return nil, terrors.Augment(err, "could not parse broker URL", nil)
	}

	scaffold := &mqttScaffold{
		clientId: clientID,
		leader:   newLeaderState(ctx),
	}
	ctx = util.CtxWithLog(ctx,
		slog.String("mqtt-broker", brokerAddr),
		slog.String("mqtt-client-id", clientID),
	)

	cfg := autopaho.ClientConfig{
		ServerUrls:                    []*url.URL{u},
		KeepAlive:                     5,
		CleanStartOnInitialConnection: true,
		SessionExpiryInterval:         60,
		OnConnectionUp: func(cm *autopaho.ConnectionManager, connAck *paho.Connack) {
			if _, err := cm.Subscribe(ctx, &paho.Subscribe{
				Subscriptions: []paho.SubscribeOptions{
					{Topic: buttonTopic, QoS: 1},
				},
			}); err != nil {
				slog.ErrorContext(ctx, "failed to subscribe to BLE events", "err", err)
			}
			slog.InfoContext(ctx, "mqtt connection up, subscribed to BLE events")

			go scaffold.aquariumTempPollingForever(ctx)
		},
		OnConnectError: func(err error) {
			slog.ErrorContext(ctx, "mqtt connection error", "err", err)
		},
		ClientConfig: paho.ClientConfig{
			ClientID: clientID,
			OnPublishReceived: []func(paho.PublishReceived) (bool, error){
				func(pr paho.PublishReceived) (bool, error) {
					if pr.Packet.Topic == buttonTopic {
						if scaffold.leader.isLeader.Load() {
							go scaffold.handleButtonEvent(pr.Packet)
						}
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

var tracer = otel.Tracer(Name)

func (r *mqttScaffold) shellyRPCResp(ctx context.Context, topic string, rpcMethod string, paramsJson map[string]any) (_ *paho.Publish, err error) {
	ctx, span := tracer.Start(ctx, "mqtt_call.shellyRPC", trace.WithAttributes(attribute.String("topic", topic), attribute.String("rpcMethod", rpcMethod), attribute.String("paramsJson", fmt.Sprint(paramsJson))))
	ctx, _ = context.WithDeadline(ctx, time.Now().Add(10*time.Second))
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
		close(recv)
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
