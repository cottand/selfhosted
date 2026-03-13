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

func (h *ProtoHandler) EmissionsForJourney(ctx context.Context, req *s_rpc_flights.Journey) (*s_rpc_flights.EmissionsForJourneyResponse, error) {
	distance, err := distanceBetweenAirportsKm(ctx, req.SrcAirportCode, req.DstAirportCode)
	if err != nil {
		return nil, terrors.Augment(err, "failed to calculate distance", nil)
	}

	co2ekg := flightKmToCO2e(distance)

	return &s_rpc_flights.EmissionsForJourneyResponse{
		CO2Ekg: co2ekg,
	}, nil
}

type ProtoHandler struct {
	s_rpc_flights.UnimplementedFlightsServer
	db *sql.DB
}
