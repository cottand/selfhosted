package module

import (
	"strings"
	"testing"
)

const sampleCSV = `ident,type,name,elevation_ft,continent,iso_country,iso_region,municipality,icao_code,iata_code,gps_code,local_code,coordinates
00A,heliport,Total RF Heliport,11,NA,US,US-PA,Bensalem,,,K00A,00A,"40.070985, -74.933689"
00AA,small_airport,Aero B Ranch Airport,3435,NA,US,US-KS,Leoti,,,00AA,00AA,"38.704022, -101.473911"
00AK,small_airport,Lowell Field,450,NA,US,US-AK,Anchor Point,,,00AK,00AK,"59.947733, -151.692524"
`

func TestParseAirportsCSV(t *testing.T) {
	result, err := parseAirportsCSV(strings.NewReader(sampleCSV))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(result) != 0 {
		t.Fatalf("expected 0 airports (none have iata_code), got %d", len(result))
	}
}

const sampleCSVWithIata = `ident,type,name,elevation_ft,continent,iso_country,iso_region,municipality,icao_code,iata_code,gps_code,local_code,coordinates
EGLL,large_airport,London Heathrow Airport,83,EU,GB,GB-ENG,London,EGLL,LHR,EGLL,,"51.4706, -0.461941"
LEMD,large_airport,Adolfo Suárez Madrid–Barajas Airport,1998,EU,ES,ES-MD,Madrid,LEMD,MAD,LEMD,,"40.471926, -3.56264"
00A,heliport,Total RF Heliport,11,NA,US,US-PA,Bensalem,,,K00A,00A,"40.070985, -74.933689"
`

func TestParseAirportsCSVWithIata(t *testing.T) {
	result, err := parseAirportsCSV(strings.NewReader(sampleCSVWithIata))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(result) != 2 {
		t.Fatalf("expected 2 airports, got %d", len(result))
	}

	lhr := result["LHR"]
	if lhr.Name != "London Heathrow Airport" {
		t.Errorf("expected name 'London Heathrow Airport', got %q", lhr.Name)
	}
	if lhr.Country != "GB" {
		t.Errorf("expected country 'GB', got %q", lhr.Country)
	}
	if lhr.Lat != 51.4706 {
		t.Errorf("expected lat 51.4706, got %f", lhr.Lat)
	}
	if lhr.Lon != -0.461941 {
		t.Errorf("expected lon -0.461941, got %f", lhr.Lon)
	}

	mad := result["MAD"]
	if mad.Name != "Adolfo Suárez Madrid–Barajas Airport" {
		t.Errorf("expected name 'Adolfo Suárez Madrid–Barajas Airport', got %q", mad.Name)
	}
	if mad.Country != "ES" {
		t.Errorf("expected country 'ES', got %q", mad.Country)
	}

	if _, ok := result["00A"]; ok {
		t.Error("expected heliport without iata_code to be excluded")
	}
}
