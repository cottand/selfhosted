package module

import (
	"crypto"
	"database/sql"

	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
)

type ProtoHandler struct {
	s_rpc_flights.UnimplementedPortfolioStatsServer

	db   *sql.DB
	hash *crypto.Hash
}

var _ s_rpc_flights.PortfolioStatsServer = &ProtoHandler{}
