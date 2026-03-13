package module

import (
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

var (
	airportsOnce sync.Once
	airports     map[string]Airport
	airportsErr  error
)

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
