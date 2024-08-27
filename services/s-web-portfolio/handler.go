package main

import (
	"context"
	"encoding/json"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"net/http"
)

func handleRoot(fs http.HandlerFunc, stats s_portfolio_stats.PortfolioStatsClient, grpcUpstream bool) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {

		originalPath := req.URL.Path
		req.URL.Path = "/"
		fs.ServeHTTP(rw, req)

		go func() {
			if grpcUpstream {
				_, _ = stats.Report(context.WithoutCancel(req.Context()), &s_portfolio_stats.Visit{
					Url:       originalPath,
					Ip:        req.Header.Get("X-Forwarded-For"),
					UserAgent: req.Header.Get("User-Agent"),
				})
			}
		}()
	})
}

type BrowseRequest struct {
	Url string `json:"url"`
}

func handleBrowse(stats s_portfolio_stats.PortfolioStatsClient, grpcUpstream bool) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		parsed := &BrowseRequest{}
		err := json.NewDecoder(req.Body).Decode(parsed)
		if err != nil {
			rw.WriteHeader(http.StatusBadRequest)
		}
		go func() {
			if grpcUpstream {
				_, _ = stats.Report(context.WithoutCancel(req.Context()), &s_portfolio_stats.Visit{
					Url:       parsed.Url,
					Ip:        req.Header.Get("X-Forwarded-For"),
					UserAgent: req.Header.Get("User-Agent"),
				})
			}
		}()
	})
}
