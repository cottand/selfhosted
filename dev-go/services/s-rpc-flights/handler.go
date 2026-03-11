package module

import (
	"context"
	"database/sql"
	"encoding/csv"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"

	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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

var (
	airportsOnce sync.Once
	airports     map[string]Airport
	airportsErr  error
)
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

	return status.Error(codes.Unimplemented, "method ListAll not implemented")
}

func loadAirports(ctx context.Context) (map[string]Airport, error) {
	airportsOnce.Do(func() {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, airportsCsvUrl, nil)
		if err != nil {
			airportsErr = fmt.Errorf("building airports CSV request: %w", err)
			return
		}
		http.DefaultClient.Transport = otelhttp.NewTransport(http.DefaultTransport)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			airportsErr = fmt.Errorf("fetching airports CSV: %w", err)
			return
		}
		defer resp.Body.Close()

		airports, airportsErr = parseAirportsCSV(resp.Body)
	})
	return airports, airportsErr
}

func parseAirportsCSV(r io.Reader) (map[string]Airport, error) {
	records, err := csv.NewReader(r).ReadAll()
	if err != nil {
		return nil, fmt.Errorf("parsing CSV: %w", err)
	}
	header := records[0]
	col := make(map[string]int, len(header))
	for i, h := range header {
		col[h] = i
	}
	result := make(map[string]Airport, len(records))
	for _, row := range records[1:] {
		iata := row[col["iata_code"]]
		if iata == "" {
			continue
		}
		coords := strings.Split(row[col["coordinates"]], ", ")
		if len(coords) != 2 {
			continue
		}
		lat, err1 := strconv.ParseFloat(strings.TrimSpace(coords[0]), 64)
		lon, err2 := strconv.ParseFloat(strings.TrimSpace(coords[1]), 64)
		if err1 != nil || err2 != nil {
			continue
		}
		result[iata] = Airport{
			Name:    row[col["name"]],
			Iata:    iata,
			Country: row[col["iso_country"]],
			Lat:     lat,
			Lon:     lon,
		}
	}
	return result, nil
}

type ProtoHandler struct {
	s_rpc_flights.UnimplementedFlightsServer
	db *sql.DB
}

func airportFromCode(ctx context.Context, airportCode string) (*s_rpc_flights.Airport, error) {
	byIata, err := loadAirports(ctx)
	if err != nil {
		return nil, fmt.Errorf("loading airports: %w", err)
	}
	a, ok := byIata[airportCode]
	if !ok {
		return nil, fmt.Errorf("unknown airport code: %s", airportCode)
	}
	return &s_rpc_flights.Airport{
		Code: a.Iata,
		Lat:  a.Lat,
		Lon:  a.Lon,
	}, nil
}
