package module

import (
	"context"
	"log/slog"
	"net/http"
	"strconv"
	"sync"
	"time"

	s_rpc_mqtt "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/gsxhq/gsx"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
)

type light struct {
	ID       string
	Dimmable bool
	// Known is false when the status could not be fetched
	Known      bool
	On         bool
	Brightness int
}

func (l light) NextOn() string { return strconv.FormatBool(!l.On) }

func (l light) Pressed() string { return strconv.FormatBool(l.On) }

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.home)
	mux.HandleFunc("POST /lights/{id}", s.setLight)
	return mux
}

func (s *scaffold) home(writer http.ResponseWriter, request *http.Request) {
	lights, err := fetchLights(request.Context())
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to list lights", "err", terrors.Propagate(err))
	}
	render(writer, request, Home(lights, err != nil))
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
			lights[i].Known = true
			lights[i].On = status.On
			lights[i].Brightness = int(status.GetBrightness())
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

	_, err := s_rpc_mqtt.SetLight(ctx, req)
	if err != nil {
		slog.ErrorContext(ctx, "failed to set light", "id", req.Id, "err", terrors.Propagate(err))
		http.Error(writer, "failed to set "+req.Id, http.StatusBadGateway)
		return
	}
	http.Redirect(writer, request, "/", http.StatusSeeOther)
}

func render(writer http.ResponseWriter, request *http.Request, node gsx.Node) {
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	err := node.Render(request.Context(), writer)
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to render page", "err", terrors.Propagate(err))
	}
}
