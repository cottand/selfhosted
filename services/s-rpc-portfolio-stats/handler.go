package main

import (
	"context"
	"crypto"
	"database/sql"
	"encoding/binary"
	s_portfolio_stats "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"log/slog"
	"strings"
	"time"
)

type ProtoHandler struct {
	s_portfolio_stats.UnimplementedPortfolioStatsServer

	db   *sql.DB
	hash *crypto.Hash
}

var _ s_portfolio_stats.PortfolioStatsServer = &ProtoHandler{}

var excludeUrls = []string{
	"/static",
	"/assets",
}

var salt = uint64(9431096920698204420)
var sha256 = crypto.SHA256.New()

func (p *ProtoHandler) Report(ctx context.Context, visit *s_portfolio_stats.Visit) (*emptypb.Empty, error) {
	slog.Info("Received visit! ", "ip", visit.Ip)

	for _, urlSub := range excludeUrls {
		if strings.Contains(visit.Url, urlSub) {
			return &emptypb.Empty{}, nil
		}
	}

	var visitor []byte
	visitor = binary.LittleEndian.AppendUint64(visitor, salt)
	visitor = append(visitor, visit.Ip...)
	visitor = append(visitor, visit.UserAgent...)
	hashed, err := sha256.Write(visitor)
	if err != nil {
		return nil, terrors.Augment(err, "error hashing visit ", map[string]string{"url": visit.Url})
	}

	_, err = p.db.ExecContext(ctx, "INSERT INTO  \"s-rpc-portfolio-stats\".visit (url, inserted_at, fingerprint_v1) VALUES ($1, $2, $3)", visit.Url, time.Now(), int64(hashed))

	if err != nil {
		return nil, terrors.Augment(err, "failed to insert visit into db", nil)
	}

	return &emptypb.Empty{}, nil
}
