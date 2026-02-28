package module

import (
	"context"
	"log/slog"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	s_rpc_mqtt "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	mqtt "github.com/eclipse/paho.mqtt.golang"
	"google.golang.org/grpc"
)

const Name = "s-rpc-mqtt"

func InitService() (*bedrock.Service, string, error) {
	protoHandler := &ProtoHandler{}
	baseConfig, err := bedrock.GetBaseConfig()
	if err != nil {
		return nil, Name, err
	}

	opts := mqtt.NewClientOptions()

	opts.ClientID = Name + "_" + baseConfig.AllocID
	opts.AddBroker("tcp://192.168.50.200:1883")
	client := mqtt.NewClient(opts)

	router := &mqttRouter{c: client}
	router.setupMqttRoutes()

	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)

	go func() {
		err := router.start(ctx)
		if err != nil {
			slog.Error("failed to start mqtt router", "err", err)
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
