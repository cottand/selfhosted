package module

import (
	"context"
	"encoding/json"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"net/http"
)

type scaffold struct {
	fs             http.HandlerFunc
	stats          s_rpc_portfolio_stats.PortfolioStatsClient
	doGrpcUpstream bool
}

func (s *scaffold) MakeHandler() http.Handler {
	mux := http.NewServeMux()

	mux.Handle("/static/", s.fs)
	mux.Handle("/assets/", s.fs)
	mux.Handle("/styles/", s.fs)
	mux.Handle("/robots.txt", s.fs)
	mux.Handle("/CNAME", s.fs)
	mux.HandleFunc("/", s.handleHTTPRoot)
	mux.HandleFunc("/api/browse", s.handleHttpBrowse)

	return mux
}

func (s *scaffold) handleHTTPRoot(rw http.ResponseWriter, req *http.Request) {
	originalPath := req.URL.Path
	req.URL.Path = "/"
	s.fs.ServeHTTP(rw, req)

	go func() {
		if s.doGrpcUpstream {
			_, _ = s.stats.Report(context.WithoutCancel(req.Context()), &s_rpc_portfolio_stats.Visit{
				Url:       originalPath,
				Ip:        req.Header.Get("X-Forwarded-For"),
				UserAgent: req.Header.Get("User-Agent"),
			})
		}
	}()
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
