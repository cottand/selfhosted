package module

import (
	"context"
	"encoding/json"
	"strconv"

	"github.com/monzo/terrors"
)

// simplePlugs are Shelly plugs that can only be switched on or off
var simplePlugs = map[string]bool{
	"plug103": true,
	"plug104": true,
	"plug106": true,
}

type shellySwitchStatusResponse struct {
	Result struct {
		Output bool `json:"output"`
	} `json:"result"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func plugTopic(id string) (string, error) {
	if !simplePlugs[id] {
		return "", terrors.NotFound("light", "unknown light", map[string]string{"id": id})
	}
	return "shelly/" + id + "/rpc", nil
}

func (r *mqttScaffold) setPlug(ctx context.Context, id string, on bool) error {
	topic, err := plugTopic(id)
	if err != nil {
		return err
	}
	resp, err := r.shellyRPCResp(ctx, topic, "Switch.Set", map[string]any{"id": 0, "on": on})
	if err != nil {
		return terrors.Augment(err, "could not set plug", map[string]string{"id": id})
	}
	_, err = parseSwitchResponse(resp.Payload, id)
	return err
}

func (r *mqttScaffold) getPlug(ctx context.Context, id string) (bool, error) {
	topic, err := plugTopic(id)
	if err != nil {
		return false, err
	}
	resp, err := r.shellyRPCResp(ctx, topic, "Switch.GetStatus", map[string]any{"id": 0})
	if err != nil {
		return false, terrors.Augment(err, "could not get plug status", map[string]string{"id": id})
	}
	parsed, err := parseSwitchResponse(resp.Payload, id)
	if err != nil {
		return false, err
	}
	return parsed.Result.Output, nil
}

func parseSwitchResponse(payload []byte, id string) (*shellySwitchStatusResponse, error) {
	var parsed shellySwitchStatusResponse
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
