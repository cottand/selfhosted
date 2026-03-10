package module

import (
	"database/sql"

	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
)

type ProtoHandler struct {
	s_rpc_flights.UnsafeFlightsServer

	db *sql.DB
}

var _ s_rpc_flights.UnsafeFlightsServer = &ProtoHandler{}
