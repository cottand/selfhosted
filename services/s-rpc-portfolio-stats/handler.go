package main

import (
	"context"
	"database/sql"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"log/slog"
	"strings"
	"time"
)

type ProtoHandler struct {
	s_portfolio_stats.UnimplementedPortfolioStatsServer

	db *sql.DB
}

var _ s_portfolio_stats.PortfolioStatsServer = &ProtoHandler{}

var excludeUrls = []string{
	"/static",
	"/assets",
}

func (p *ProtoHandler) Report(ctx context.Context, visit *s_portfolio_stats.Visit) (*emptypb.Empty, error) {
	slog.Info("Received visit! ", "url", visit.Url)

	for _, urlSub := range excludeUrls {
		if strings.Contains(visit.Url, urlSub) {
			return &emptypb.Empty{}, nil
		}
	}
	_, err := p.db.ExecContext(ctx, "INSERT INTO  \"s-rpc-portfolio-stats\".visit (url, inserted_at) VALUES ($1, $2)", visit.Url, time.Now())

	if err != nil {
		return nil, terrors.Augment(err, "failed to insert visit into db", nil)
	}

	return &emptypb.Empty{}, nil
}
