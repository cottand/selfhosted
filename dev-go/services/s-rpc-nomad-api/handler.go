package module

import (
	"context"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"google.golang.org/protobuf/types/known/emptypb"
)

type ProtoHandler struct {
	pb.UnimplementedNomadApiServer
}

func (h *ProtoHandler) Deploy(ctx context.Context, job *pb.Job) (*emptypb.Empty, error) {
	//TODO implement me
	return &emptypb.Empty{}, nil
}
