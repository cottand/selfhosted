package module

import (
	"context"
	"log/slog"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	s_rpc_mqtt "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	mqtt "github.com/eclipse/paho.mqtt.golang"
	"google.golang.org/grpc"
)

const Name = "s-rpc-mqtt"

func InitService() (*bedrock.Service, string, error) {
	ctx := bedrock.ContextForModule(Name, context.Background())
	protoHandler := &ProtoHandler{}
	baseConfig, err := bedrock.GetBaseConfig()
	if err != nil {
		return nil, Name, err
	}

	brokerAddr, err := config.Get(ctx, "mqttBrokerAddr").String("tcp://192.168.50.200:1883")
	if err != nil {
		return nil, Name, err
	}

	opts := mqtt.NewClientOptions()
	opts.SetClientID(Name + "_" + baseConfig.AllocID)
	opts.AddBroker(brokerAddr)

	ctx, cancel := context.WithCancel(ctx)
	opts.SetConnectionLostHandler(func(client mqtt.Client, err error) {
		slog.WarnContext(ctx, "mqtt connection lost", "brokerAddr", brokerAddr, "err", err)

		go func() {
			router := &mqttRouter{c: client, clientId: opts.ClientID}
			err := router.start(ctx)
			if err != nil {
				slog.ErrorContext(ctx, "failed to start mqtt router", "brokerAddr", brokerAddr, "err", err)
			}
		}()
	})

	client := mqtt.NewClient(opts)

	router := &mqttRouter{c: client, clientId: opts.ClientID}

	go func() {
		err := router.start(ctx)
		if err != nil {
			slog.ErrorContext(ctx, "failed to start mqtt router", "brokerAddr", brokerAddr, "err", err)
		}
	}()

	return &bedrock.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_mqtt.RegisterMqttServer(srv, protoHandler)
		},
		OnShutdown: func() error {
			cancel()
			return nil
		},
	}, Name, nil
}
