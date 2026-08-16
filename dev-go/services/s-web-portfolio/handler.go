package module

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"sync"
	"time"

	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	s_rpc_prometheus "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-prometheus"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"

	"net/http"
)

type scaffold struct {
	doGrpcUpstream bool
}

func (s *scaffold) MakeHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/browse", s.handleHttpBrowse)
	mux.HandleFunc("/api/aquarium_temp", s.handleAquariumTemp)
	return mux
}

type BrowseRequest struct {
	Url string `json:"url"`
}

func (s *scaffold) handleHttpBrowse(rw http.ResponseWriter, req *http.Request) {
	parsed := &BrowseRequest{}
	err := json.NewDecoder(req.Body).Decode(parsed)
	if err != nil {
		rw.WriteHeader(http.StatusBadRequest)
	}
	rw.Header().Set("Access-Control-Allow-Origin", "https://nico.dcotta.com")
	go func() {
		if s.doGrpcUpstream {
			_, _ = s_rpc_portfolio_stats.Report(context.WithoutCancel(req.Context()), &s_rpc_portfolio_stats.Visit{
				Url:       parsed.Url,
				Ip:        req.Header.Get("X-Forwarded-For"),
				UserAgent: req.Header.Get("User-Agent"),
			})
		}
	}()
}

type aquariumTempResponse struct {
	TempC string `json:"tempC"`
}

var (
	cachedValue string
	cachedAt    time.Time
	cachedMutex sync.RWMutex
)

func (s *scaffold) handleAquariumTemp(rw http.ResponseWriter, req *http.Request) {
	rw.Header().Set("Access-Control-Allow-Origin", "https://nico.dcotta.com")
	rw.Header().Set("Content-Type", "application/json")
	rw.Header().Set("Cache-Control", "max-age=30")

	span := trace.SpanFromContext(req.Context())

	cachedMutex.RLock()
	defer cachedMutex.RUnlock()

	if time.Since(cachedAt) < 20*time.Second {
		span.SetAttributes(attribute.Bool("cached", true))
		rw.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(rw).Encode(aquariumTempResponse{TempC: cachedValue})
		return
	}
	span.SetAttributes(attribute.Bool("cached", false))

	tempC, err := s_rpc_prometheus.QueryInstant(req.Context(), &s_rpc_prometheus.QueryInstantRequest{
		PromQLQuery: "avg(s_rpc_mqtt_pill107_temp)",
	})

	if err != nil {
		span.RecordError(err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	parsed, err := strconv.ParseFloat(tempC.Result, 64)
	if err != nil {
		span.RecordError(err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}

	formatted := fmt.Sprintf("%.1f", parsed)
	go refreshCache(formatted, time.Now())

	resp := aquariumTempResponse{TempC: formatted}
	err = json.NewEncoder(rw).Encode(resp)
	if err != nil {
		span.RecordError(err)
		rw.WriteHeader(http.StatusInternalServerError)
	}
}

func refreshCache(value string, timestamp time.Time) {
	cachedMutex.Lock()
	defer cachedMutex.Unlock()
	if timestamp.Before(cachedAt) {
		// the cached value is actually newer
		return
	}
	cachedAt = timestamp
	cachedValue = value
}
