package main

import (
	"context"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"google.golang.org/protobuf/types/known/emptypb"
	"log/slog"
)

type ProtoHandler struct {
	s_portfolio_stats.UnimplementedPortfolioStatsServer
}

var _ s_portfolio_stats.PortfolioStatsServer = &ProtoHandler{}

func (p *ProtoHandler) Report(ctx context.Context, visit *s_portfolio_stats.Visit) (*emptypb.Empty, error) {
	slog.Info("Received visit! ", "url", visit.Url)

	return &emptypb.Empty{}, nil
}
