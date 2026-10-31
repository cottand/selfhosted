package module

import (
	"context"
	"log/slog"
	"net/http"
	"sync"
	"time"

	s_rpc_mqtt "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-mqtt"
	"github.com/gsxhq/gsx"
	"github.com/monzo/terrors"
)

var lightIDs = []string{"plug103", "plug104", "plug106"}

type light struct {
	ID string
	// Known is false when the status could not be fetched
	Known bool
	On    bool
}

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.home)
	mux.HandleFunc("POST /lights/{id}", s.setLight)
	return mux
}

func (s *scaffold) home(writer http.ResponseWriter, request *http.Request) {
	render(writer, request, Home(fetchLights(request.Context())))
}

func fetchLights(ctx context.Context) []light {
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	lights := make([]light, len(lightIDs))
	var wg sync.WaitGroup
	for i, id := range lightIDs {
		lights[i] = light{ID: id}
		wg.Go(func() {
			status, err := s_rpc_mqtt.GetLight(ctx, &s_rpc_mqtt.GetLightRequest{Id: id})
			if err != nil {
				slog.WarnContext(ctx, "failed to get light status", "id", id, "err", terrors.Propagate(err))
				return
			}
			lights[i].Known = true
			lights[i].On = status.On
		})
	}
	wg.Wait()
	return lights
}

func (s *scaffold) setLight(writer http.ResponseWriter, request *http.Request) {
	id := request.PathValue("id")
	on := request.FormValue("on") == "true"

	ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
	defer cancel()

	_, err := s_rpc_mqtt.SetLight(ctx, &s_rpc_mqtt.SetLightRequest{Id: id, On: on})
	if err != nil {
		slog.ErrorContext(ctx, "failed to set light", "id", id, "on", on, "err", terrors.Propagate(err))
		http.Error(writer, "failed to switch "+id, http.StatusBadGateway)
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
