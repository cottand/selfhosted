package module

import (
	"context"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"google.golang.org/protobuf/types/known/emptypb"
)

type ProtoHandler struct {
	pb.UnimplementedMqttServer
	mqtt *mqttScaffold
}

func (h *ProtoHandler) Dummy(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	return &emptypb.Empty{}, nil
}

func (h *ProtoHandler) SetAquariumSchedule(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	// first we delete the schedules
	_, err := h.mqtt.shellyRPCResp(ctx, "shelly/rgb105/rpc", "Schedule.DeleteAll", make(map[string]any))
	if err != nil {
		return nil, err
	}
	_, err = h.mqtt.shellyRPCResp(ctx, "shelly/rgb108/rpc", "Schedule.DeleteAll", make(map[string]any))
	if err != nil {
		return nil, err
	}

	//then export our new ones
	for _, params := range aquariumSchedule {
		_, err := h.mqtt.shellyRPCRespAny(ctx, "shelly/rgb105/rpc", "Schedule.Create", params)
		if err != nil {
			return nil, err
		}
		_, err = h.mqtt.shellyRPCRespAny(ctx, "shelly/rgb108/rpc", "Schedule.Create", params)
		if err != nil {
			return nil, err
		}
	}

	return &emptypb.Empty{}, nil

}

func (h *ProtoHandler) ListLights(_ context.Context, _ *emptypb.Empty) (*pb.ListLightsResponse, error) {
	return &pb.ListLightsResponse{Lights: listLights()}, nil
}

func (h *ProtoHandler) SetLight(ctx context.Context, req *pb.SetLightRequest) (*pb.LightStatus, error) {
	if err := h.mqtt.setLight(ctx, req); err != nil {
		return nil, err
	}
	return h.mqtt.getLight(ctx, req.Id)
}

func (h *ProtoHandler) GetLight(ctx context.Context, req *pb.GetLightRequest) (*pb.LightStatus, error) {
	return h.mqtt.getLight(ctx, req.Id)
}
