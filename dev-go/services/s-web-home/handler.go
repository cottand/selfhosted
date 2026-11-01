package module

import (
	"bytes"
	"context"
	_ "embed"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	s_rpc_mqtt "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/gsxhq/gsx"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
)

const (
	ssePingPeriod   = 15 * time.Second
	sseWriteTimeout = 10 * time.Second
)

//go:embed floorplan.svg
var floorplanSVG []byte

type light struct {
	ID       string
	Dimmable bool
	// Known is false when the status could not be fetched
	Known      bool
	On         bool
	Brightness int
}

func lightFromStatus(status *s_rpc_mqtt.LightStatus) light {
	return light{
		ID:         status.Id,
		Dimmable:   status.Dimmable,
		Known:      true,
		On:         status.On,
		Brightness: int(status.GetBrightness()),
	}
}

func (l light) NextOn() string { return strconv.FormatBool(!l.On) }

func (l light) Pressed() string { return strconv.FormatBool(l.On) }

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.home)
	mux.HandleFunc("GET /floorplan.svg", floorplan)
	mux.HandleFunc("POST /lights/{id}", s.setLight)
	mux.HandleFunc("GET /lights/events", s.lightEvents)
	return mux
}

func (s *scaffold) home(writer http.ResponseWriter, request *http.Request) {
	lights, err := fetchLights(request.Context())
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to list lights", "err", terrors.Propagate(err))
	}
	render(writer, request, Home(lights, err != nil))
}

func floorplan(writer http.ResponseWriter, _ *http.Request) {
	writer.Header().Set("Content-Type", "image/svg+xml")
	writer.Header().Set("Cache-Control", "public, max-age=3600")
	_, _ = writer.Write(floorplanSVG)
}

func fetchLights(ctx context.Context) ([]light, error) {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	listed, err := s_rpc_mqtt.ListLights(ctx, &emptypb.Empty{})
	if err != nil {
		return nil, terrors.Augment(err, "failed to list lights", nil)
	}

	lights := make([]light, len(listed.Lights))
	var wg sync.WaitGroup
	for i, l := range listed.Lights {
		lights[i] = light{ID: l.Id, Dimmable: l.Dimmable}
		wg.Go(func() {
			status, err := s_rpc_mqtt.GetLight(ctx, &s_rpc_mqtt.GetLightRequest{Id: l.Id})
			if err != nil {
				slog.WarnContext(ctx, "failed to get light status", "id", l.Id, "err", terrors.Propagate(err))
				return
			}
			lights[i] = lightFromStatus(status)
		})
	}
	wg.Wait()
	return lights, nil
}

func (s *scaffold) setLight(writer http.ResponseWriter, request *http.Request) {
	req := &s_rpc_mqtt.SetLightRequest{Id: request.PathValue("id")}
	if on := request.FormValue("on"); on != "" {
		req.On = new(on == "true")
	}
	if brightness := request.FormValue("brightness"); brightness != "" {
		parsed, err := strconv.Atoi(brightness)
		if err != nil {
			http.Error(writer, "invalid brightness", http.StatusBadRequest)
			return
		}
		req.Brightness = new(int32(parsed))
	}

	ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
	defer cancel()

	status, err := s_rpc_mqtt.SetLight(ctx, req)
	if err != nil {
		slog.ErrorContext(ctx, "failed to set light", "id", req.Id, "err", terrors.Propagate(err))
		http.Error(writer, "failed to set "+req.Id, http.StatusBadGateway)
		return
	}
	if request.Header.Get("X-Row-Only") != "" {
		render(writer, request, LightRow(lightFromStatus(status)))
		return
	}
	http.Redirect(writer, request, "/", http.StatusSeeOther)
}

// lightEvents streams server-sent events with the rendered row of every light that changes. It
// starts with all of them, which is what catches a page up when it reconnects.
func (s *scaffold) lightEvents(writer http.ResponseWriter, request *http.Request) {
	ctx := request.Context()

	stream, err := s_rpc_mqtt.WatchLights(ctx, &emptypb.Empty{})
	if err != nil {
		slog.ErrorContext(ctx, "failed to watch lights", "err", terrors.Propagate(err))
		http.Error(writer, "failed to watch lights", http.StatusBadGateway)
		return
	}
	// these arrive once s-rpc-mqtt is subscribed, so the snapshot below cannot miss a change
	if _, err := stream.Header(); err != nil {
		slog.ErrorContext(ctx, "failed to watch lights", "err", terrors.Propagate(err))
		http.Error(writer, "failed to watch lights", http.StatusBadGateway)
		return
	}

	updates := make(chan *s_rpc_mqtt.LightStatus)
	go func() {
		defer close(updates)
		for {
			status, err := stream.Recv()
			if err != nil {
				return
			}
			select {
			case updates <- status:
			case <-ctx.Done():
				return
			}
		}
	}()

	controller := http.NewResponseController(writer)
	send := func(event []byte) error {
		// the server's write timeout is counted from the start of the request
		if err := controller.SetWriteDeadline(time.Now().Add(sseWriteTimeout)); err != nil {
			return err
		}
		if _, err := writer.Write(event); err != nil {
			return err
		}
		return controller.Flush()
	}
	sendLight := func(l light) error {
		event, err := renderLightEvent(ctx, l)
		if err != nil {
			return err
		}
		return send(event)
	}

	writer.Header().Set("Content-Type", "text/event-stream")
	writer.Header().Set("Cache-Control", "no-store")
	if err := send([]byte(": connected\n\n")); err != nil {
		return
	}

	lights, err := fetchLights(ctx)
	if err != nil {
		slog.WarnContext(ctx, "failed to send light snapshot", "err", terrors.Propagate(err))
		return
	}
	for _, l := range lights {
		if err := sendLight(l); err != nil {
			return
		}
	}

	ping := time.NewTicker(ssePingPeriod)
	defer ping.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ping.C:
			if err := send([]byte(": ping\n\n")); err != nil {
				return
			}
		case status, ok := <-updates:
			if !ok {
				return
			}
			if err := sendLight(lightFromStatus(status)); err != nil {
				return
			}
		}
	}
}

func renderLightEvent(ctx context.Context, l light) ([]byte, error) {
	var row bytes.Buffer
	if err := LightRow(l).Render(ctx, &row); err != nil {
		return nil, terrors.Augment(err, "failed to render light", map[string]string{"id": l.ID})
	}
	var event bytes.Buffer
	event.WriteString("event: light\n")
	for line := range strings.SplitSeq(row.String(), "\n") {
		event.WriteString("data: " + line + "\n")
	}
	event.WriteString("\n")
	return event.Bytes(), nil
}

func render(writer http.ResponseWriter, request *http.Request, node gsx.Node) {
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	err := node.Render(request.Context(), writer)
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to render page", "err", terrors.Propagate(err))
	}
}
