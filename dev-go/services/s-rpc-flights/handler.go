package module

import (
	"context"
	"database/sql"

	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
)

type Airport struct {
	Name    string
	Iata    string
	Country string
	Lat     float64
	Lon     float64
}

const airportsCsvUrl = "https://raw.githubusercontent.com/datasets/airport-codes/refs/heads/main/data/airport-codes.csv"

var _ s_rpc_flights.FlightsServer = &ProtoHandler{}

func (h *ProtoHandler) ListAll(_ *emptypb.Empty, stream grpc.ServerStreamingServer[s_rpc_flights.Flight]) error {
	rows, err := h.db.QueryContext(stream.Context(), `select src_airport, dst_airport from "s-rpc-flights".flight`)
	if err != nil {
		return terrors.Augment(err, "failed to query flights", nil)
	}
	defer rows.Close()

	for rows.Next() {
		var srcAirport, dstAirport string
		err = rows.Scan(&srcAirport, &dstAirport)
		if err != nil {
			return terrors.Augment(err, "failed to scan flight query result", nil)
		}

		ctx := stream.Context()
		srcAirportObj, err := airportFromCode(ctx, srcAirport)
		if err != nil {
			return terrors.Augment(err, "failed to get airport object for src", nil)
		}
		dstAirportObj, err := airportFromCode(ctx, dstAirport)
		if err != nil {
			return terrors.Augment(err, "failed to get airport object for dst", nil)
		}

		flight := &s_rpc_flights.Flight{
			Src: srcAirportObj,
			Dst: dstAirportObj,
		}
		err = stream.Send(flight)
		if err != nil {
			return terrors.Augment(err, "failed to send flight", nil)
		}
	}

	return nil
}

type ProtoHandler struct {
	s_rpc_flights.UnimplementedFlightsServer
	db *sql.DB
}

var closedAirports = map[string]Airport{
	"SXF": {
		Name:    "Berlin Schönefeld",
		Lat:     52.380001,
		Lon:     13.5225,
		Iata:    "SXF",
		Country: "DE",
	},
}

func airportFromCode(ctx context.Context, airportCode string) (*s_rpc_flights.Airport, error) {
	byIata, err := loadAirports(ctx)
	if err != nil {
		return nil, terrors.Augment(err, "airport", nil)
	}
	a, ok := byIata[airportCode]
	if !ok {
		a, ok = closedAirports[airportCode]
		if !ok {
			return nil, terrors.NotFound("airport", "unknown airport code", map[string]string{"code": airportCode})
		}
	}
	return &s_rpc_flights.Airport{
		Code: a.Iata,
		Lat:  a.Lat,
		Lon:  a.Lon,
	}, nil
}
