package module

import (
	"context"
	"crypto"
	"database/sql"
	"encoding/hex"
	s_rpc_portfolio_stats "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-portfolio-stats"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"strings"
	"time"
)

type ProtoHandler struct {
	s_rpc_portfolio_stats.UnimplementedPortfolioStatsServer

	db   *sql.DB
	hash *crypto.Hash
}

var _ s_rpc_portfolio_stats.PortfolioStatsServer = &ProtoHandler{}

var salt = []byte{4, 49, 127, 104, 174, 252, 225, 13}

func (p *ProtoHandler) Report(ctx context.Context, visit *s_rpc_portfolio_stats.Visit) (*emptypb.Empty, error) {
	if !shouldIncludeUrl(visit.Url) {
		return &emptypb.Empty{}, nil
	}
	var sha256 = crypto.SHA256.New()
	sha256.Write(salt)
	sha256.Write([]byte(normaliseIp(visit.Ip)))
	sha256.Write([]byte(visit.UserAgent))
	hashAsString := hex.EncodeToString(sha256.Sum(nil))

	_, err := p.db.ExecContext(ctx, "INSERT INTO  \"s-rpc-portfolio-stats\".visit (url, inserted_at, fingerprint_v1) VALUES ($1, $2, $3)", visit.Url, time.Now(), hashAsString)

	if err != nil {
		return nil, terrors.Augment(err, "failed to insert visit into db", nil)
	}

	return &emptypb.Empty{}, nil
}

// cloudflare may report several IPs, so we take the first one only
func normaliseIp(str string) string {
	if !strings.Contains(str, ",") {
		return str
	}
	split := strings.Split(str, ", ")
	if len(split) != 2 {
		return str
	}
	return split[0]
}

var excludeUrls = []string{
	"/static",
	"/assets",
	".",
}

var includeList = []string{
	"/blog",
	"/projects",
}

func shouldIncludeUrl(url string) bool {
	if url == "/" {
		return true
	}
	for _, urlSub := range excludeUrls {
		if strings.Contains(url, urlSub) {
			return false
		}
	}
	for _, urlSub := range includeList {
		if strings.Contains(url, urlSub) {
			return true
		}
	}
	return false
}
