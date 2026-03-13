package module

import (
	"context"
	"math"

	"github.com/monzo/terrors"
)

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
