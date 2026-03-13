package module

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"math"
	"strconv"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/util"
	"github.com/monzo/terrors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"go.opentelemetry.io/otel/codes"
)

var (
	refreshRate = 10 * time.Minute

	airportsStat = promauto.NewGauge(prometheus.GaugeOpts{
		Namespace: util.KebabToSnakeCase(name),
		Name:      "airports",
		Help:      "Total airports visited",
	})

	flightsStat = promauto.NewGauge(prometheus.GaugeOpts{
		Namespace: util.KebabToSnakeCase(name),
		Name:      "flights",
		Help:      "Flights flown",
	})

	flightFootprint = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: util.KebabToSnakeCase(name),
		Name:      "flight_yearly_footprint",
		Help:      "Footprint for year of flights",
	}, []string{"year"})
)

// RefreshPromStats returns when ctx is cancelled or done
func RefreshPromStats(ctx context.Context, db *sql.DB) {
	tracer := bedrock.GetTracer(ctx)
	for {
		ctx, span := tracer.Start(ctx, "periodic.refreshPromStats")
		var errs []error
		errs = append(
			errs,
			refreshFlights(ctx, db),
			totalAirports(ctx, db),
			refreshYearlyCo2(ctx, db, 2024),
			refreshYearlyCo2(ctx, db, 2025),
			refreshYearlyCo2(ctx, db, 2026),
		)
		accumulated := errors.Join(errs...)
		if accumulated != nil {
			span.RecordError(accumulated)
			span.SetStatus(codes.Error, "error")
			slog.WarnContext(ctx, "failed to refresh stats", "err", accumulated)
		}
		span.SetStatus(codes.Ok, "ok")
		span.End()
		select {
		case <-ctx.Done():
			return

		default:
			time.Sleep(refreshRate)
			continue
		}
	}
}

func refreshYearlyCo2(ctx context.Context, db *sql.DB, year int) error {
	query := `select src_airport, dst_airport, departure_date from "s-rpc-flights".flight`
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return terrors.Augment(err, "failed to query visits", nil)
	}
	defer rows.Close()

	totalKg := 0.0
	greatestKg := 0.0
	greatestFlight := struct {
		src, dst, date string
	}{}

	for rows.Next() {
		var srcAirport, dstAirport string
		var departureDate time.Time
		if err := rows.Scan(&srcAirport, &dstAirport, &departureDate); err != nil {
			return terrors.Augment(err, "failed to scan query result", nil)
		}

		if departureDate.Year() != year {
			continue
		}

		distance, err := distanceBetweenAirportsKm(ctx, srcAirport, dstAirport)
		if err != nil {
			return terrors.Augment(err, "failed to calculate distance", nil)
		}

		co2eKg := flightKmToCO2e(distance)
		totalKg += co2eKg
		if co2eKg > greatestKg {
			greatestKg = co2eKg
			greatestFlight = struct{ src, dst, date string }{
				src:  srcAirport,
				dst:  dstAirport,
				date: departureDate.Format(time.DateOnly),
			}
		}
	}

	flightFootprint.With(prometheus.Labels{"year": strconv.Itoa(year)}).Set(totalKg)
	slog.InfoContext(ctx, "greatest flight", "flight", greatestFlight)

	return nil
}

func distanceBetweenAirportsKm(ctx context.Context, src, dst string) (float64, error) {
	byIata, err := loadAirports(ctx)
	if err != nil {
		return 0, terrors.Augment(err, "failed to load airports", nil)
	}
	srcAirport, ok := byIata[src]
	if !ok {
		return 0, terrors.NotFound("airport", "unknown src airport", map[string]string{"code": src})
	}
	dstAirport, ok := byIata[dst]
	if !ok {
		return 0, terrors.NotFound("airport", "unknown dst airport", map[string]string{"code": dst})
	}
	return haversineKm(srcAirport.Lat, srcAirport.Lon, dstAirport.Lat, dstAirport.Lon), nil
}

const earthRadiusKm = 6371.0

// haversineKm calculates great circle distance
// https://en.wikipedia.org/wiki/Haversine_formula
func haversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	dLat := (lat2 - lat1) * math.Pi / 180
	dLon := (lon2 - lon1) * math.Pi / 180
	lat1r := lat1 * math.Pi / 180
	lat2r := lat2 * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1r)*math.Cos(lat2r)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return earthRadiusKm * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

// flightKmToCO2e estimates CO2e emissions (kg) for one passenger on a one-way flight,
// given the great-circle distance in km.
//
// Methodology: DESNZ/DEFRA 2024 GHG Conversion Factors
//   - 8% distance uplift for indirect routing
//   - Short-haul (<3700 km): 0.158 kg CO2e/km (economy, with radiative forcing)
//   - Long-haul (>=3700 km): 0.11704 kg CO2e/km (economy, with radiative forcing)
//
// Source: https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2024
func flightKmToCO2e(greatCircleKm float64) (kg float64) {
	const (
		distanceUplift  = 1.08
		shortHaulFactor = 0.158   // kg CO2e per km, economy with RF
		longHaulFactor  = 0.11704 // kg CO2e per km, economy with RF
		shortHaulCutoff = 3700.0  // km
	)

	actualKm := greatCircleKm * distanceUplift

	factor := longHaulFactor
	if greatCircleKm < shortHaulCutoff {
		factor = shortHaulFactor
	}

	return actualKm * factor
}
func refreshFlights(ctx context.Context, db *sql.DB) error {
	query := `select count(*) from "s-rpc-flights".flight`
	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return terrors.Augment(err, "failed to query flights", nil)
	}
	defer rows.Close()
	var counted int64
	for rows.Next() {
		err = rows.Scan(&counted)
		if err != nil {
			return terrors.Augment(err, "failed to scan flights query result", nil)
		}
	}
	flightsStat.Set(float64(counted))
	return nil
}

func totalAirports(ctx context.Context, db *sql.DB) error {
	query := `
with total as (select *
               from (select src_airport as airport from "s-rpc-flights".flight) as fa
               union
               (select dst_airport as airport from "s-rpc-flights".flight))

select count(*)
from total;`

	rows, err := db.QueryContext(ctx, query)
	if err != nil {
		return terrors.Augment(err, "failed to query airports", nil)
	}
	defer rows.Close()
	var counted int64
	for rows.Next() {
		err = rows.Scan(&counted)
		if err != nil {
			return terrors.Augment(err, "failed to scan airport query result", nil)
		}
	}

	airportsStat.Set(float64(counted))
	return nil
}
