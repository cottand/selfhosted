package module

import (
	"context"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"google.golang.org/protobuf/types/known/emptypb"
)

type ProtoHandler struct {
	pb.UnimplementedMqttServer
}

func (h *ProtoHandler) Dummy(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	return &emptypb.Empty{}, nil
}
