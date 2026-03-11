package module

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"sync"

	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
)

type Coords struct {
	Lat float64
	Lon float64
}

type ProtoHandler struct {
	s_rpc_flights.UnimplementedFlightsServer
	db *sql.DB
}

var _ s_rpc_flights.FlightsServer = &ProtoHandler{}

func (h *ProtoHandler) ListAll(_ *emptypb.Empty, stream grpc.ServerStreamingServer[s_rpc_flights.Flight]) error {
	rows, err := h.db.QueryContext(stream.Context(), `select src_airport, dst_airport from "s-rpc-flights".flight`)
	if err != nil {
		return terrors.Augment(err, "failed to query flights", nil)
	}
	defer rows.Close()

	for rows.Next() {
		ctx := stream.Context()
		var srcAirport, dstAirport string
		err = rows.Scan(&srcAirport, &dstAirport)
		if err != nil {
			return terrors.Augment(err, "failed to scan flight query result", nil)
		}

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

	return status.Error(codes.Unimplemented, "method ListAll not implemented")
}

var airportCodeCoordsCache = map[string]Coords{}
var airportCodeCoordsCacheLock = &sync.Mutex{}

func airportFromCode(ctx context.Context, airportCode string) (*s_rpc_flights.Airport, error) {
	airportCodeCoordsCacheLock.Lock()
	defer airportCodeCoordsCacheLock.Unlock()
	airportCodeCoords, ok := airportCodeCoordsCache[airportCode]
	if !ok {
		request, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("https://airportsapi.com/api/airports/%s", airportCode), nil)
		if err != nil {
			return nil, terrors.Augment(err, "failed to make airportsapi request", nil)
		}
		request.Header.Set("Accept", "application/json")
		response, err := http.DefaultClient.Do(request)
		if err != nil {
			return nil, terrors.Augment(err, "failed to make airportsapi request", nil)
		}
		defer response.Body.Close()
		if response.StatusCode != http.StatusOK {
			return nil, terrors.Augment(fmt.Errorf("failed to fetch airport from airportsapi, status code %d", response.StatusCode), "failed to fetch airport from airportsapi", nil)
		}

		buf := bytes.NewBuffer(nil)
		_, err = buf.ReadFrom(response.Body)
		if err != nil {
			return nil, terrors.Augment(err, "failed to read airportsapi response body", nil)
		}

		resp := GetAirportResponse{}
		err = json.Unmarshal(buf.Bytes(), &resp)
		if err != nil {
			return nil, terrors.Augment(err, "failed to unmarshal airportsapi response body", nil)
		}

		lat, _ := strconv.ParseFloat(resp.Data.Attributes.Latitude, 64)
		lon, _ := strconv.ParseFloat(resp.Data.Attributes.Longitude, 64)

		airportCodeCoords = Coords{Lat: lat, Lon: lon}
		airportCodeCoordsCache[airportCode] = airportCodeCoords
	}

	return &s_rpc_flights.Airport{
		Code: airportCode,
		Lat:  airportCodeCoords.Lat,
		Lon:  airportCodeCoords.Lon,
	}, nil
}
