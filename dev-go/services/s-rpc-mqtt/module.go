package module

import (
	"context"
	"errors"
	"log/slog"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	s_rpc_mqtt "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
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

	ctx, cancel := context.WithCancel(ctx)
	go func() {
		for {
			err := newMqttRouter(brokerAddr, Name+"_"+baseConfig.AllocID).
				startConnection(ctx)
			if err != nil && !errors.Is(err, context.Canceled) {
				slog.ErrorContext(ctx, "failed to start mqtt router", "brokerAddr", brokerAddr, "err", err)
				return
			}
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
