package module

import (
	"context"
	"encoding/json"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"net/http"
)

type scaffold struct {
	stats          s_rpc_portfolio_stats.PortfolioStatsClient
	doGrpcUpstream bool
}

func (s *scaffold) MakeHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/browse", s.handleHttpBrowse)
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
			_, _ = s.stats.Report(context.WithoutCancel(req.Context()), &s_rpc_portfolio_stats.Visit{
				Url:       parsed.Url,
				Ip:        req.Header.Get("X-Forwarded-For"),
				UserAgent: req.Header.Get("User-Agent"),
			})
		}
	}()
}
