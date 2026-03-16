package module

import (
	"context"
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
	router, err := newMqtt(ctx, brokerAddr, Name+"_"+baseConfig.AllocID)
	if err != nil {
		cancel()
		slog.ErrorContext(ctx, "failed to create mqtt router", "brokerAddr", brokerAddr, "err", err)
		return nil, Name, err
	}

	return &bedrock.Service{
		Name: Name,
		RegisterGrpc: func(srv *grpc.Server) {
			s_rpc_mqtt.RegisterMqttServer(srv, protoHandler)
		},
		OnShutdown: func() error {
			cancel()
			<-router.cm.Done()
			return nil
		},
	}, Name, nil
}
