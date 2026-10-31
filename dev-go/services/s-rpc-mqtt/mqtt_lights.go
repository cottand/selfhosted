package module

import (
	"context"
	"encoding/json"
	"strconv"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/monzo/terrors"
)

type lightDef struct {
	id string
	// dimmable lights use the Shelly Light component, the rest the Switch component
	dimmable bool
}

func (l lightDef) topic() string { return "shelly/" + l.id + "/rpc" }

func (l lightDef) component() string {
	if l.dimmable {
		return "Light"
	}
	return "Switch"
}

var lights = []lightDef{
	{id: "plug103"},
	{id: "plug104"},
	{id: "plug106"},
	{id: "rgb105", dimmable: true},
	{id: "rgb108", dimmable: true},
}

type shellyOutputStatusResponse struct {
	Result struct {
		Output     bool `json:"output"`
		Brightness int  `json:"brightness"`
	} `json:"result"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func findLight(id string) (lightDef, error) {
	for _, l := range lights {
		if l.id == id {
			return l, nil
		}
	}
	return lightDef{}, terrors.NotFound("light", "unknown light", map[string]string{"id": id})
}

func listLights() []*pb.Light {
	res := make([]*pb.Light, len(lights))
	for i, l := range lights {
		res[i] = &pb.Light{Id: l.id, Dimmable: l.dimmable}
	}
	return res
}

func (r *mqttScaffold) setLight(ctx context.Context, req *pb.SetLightRequest) error {
	l, err := findLight(req.Id)
	if err != nil {
		return err
	}
	errParams := map[string]string{"id": l.id}
	if req.On == nil && req.Brightness == nil {
		return terrors.BadRequest("empty_request", "one of on or brightness must be set", errParams)
	}

	params := map[string]any{"id": 0, "on": true}
	if req.On != nil {
		params["on"] = *req.On
	}
	if req.Brightness != nil {
		if !l.dimmable {
			return terrors.BadRequest("not_dimmable", "light is not dimmable", errParams)
		}
		if *req.Brightness < 0 || *req.Brightness > 100 {
			return terrors.BadRequest("brightness_out_of_range", "brightness must be within 0-100", errParams)
		}
		params["brightness"] = *req.Brightness
	}

	resp, err := r.shellyRPCResp(ctx, l.topic(), l.component()+".Set", params)
	if err != nil {
		return terrors.Augment(err, "could not set light", errParams)
	}
	_, err = parseOutputStatusResponse(resp.Payload, l.id)
	return err
}

func (r *mqttScaffold) toggleLight(ctx context.Context, id string) error {
	l, err := findLight(id)
	if err != nil {
		return err
	}
	resp, err := r.shellyRPCResp(ctx, l.topic(), l.component()+".Toggle", map[string]any{"id": 0})
	if err != nil {
		return terrors.Augment(err, "could not toggle light", map[string]string{"id": id})
	}
	_, err = parseOutputStatusResponse(resp.Payload, id)
	return err
}

func (r *mqttScaffold) getLight(ctx context.Context, id string) (*pb.LightStatus, error) {
	l, err := findLight(id)
	if err != nil {
		return nil, err
	}
	resp, err := r.shellyRPCResp(ctx, l.topic(), l.component()+".GetStatus", map[string]any{"id": 0})
	if err != nil {
		return nil, terrors.Augment(err, "could not get light status", map[string]string{"id": id})
	}
	parsed, err := parseOutputStatusResponse(resp.Payload, id)
	if err != nil {
		return nil, err
	}
	status := &pb.LightStatus{Id: l.id, On: parsed.Result.Output, Dimmable: l.dimmable}
	if l.dimmable {
		status.Brightness = new(int32(parsed.Result.Brightness))
	}
	return status, nil
}

func parseOutputStatusResponse(payload []byte, id string) (*shellyOutputStatusResponse, error) {
	var parsed shellyOutputStatusResponse
	if err := json.Unmarshal(payload, &parsed); err != nil {
		return nil, terrors.Augment(err, "could not parse shelly response", map[string]string{"id": id})
	}
	if parsed.Error != nil {
		return nil, terrors.New("shelly_error", parsed.Error.Message, map[string]string{
			"id":   id,
			"code": strconv.Itoa(parsed.Error.Code),
		})
	}
	return &parsed, nil
}
