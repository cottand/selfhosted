package module

import (
	"context"
	"errors"
	"io"
	"net/http"

	s_rpc_flights "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-flights"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"

	"github.com/golang/geo/s2"
	geojson "github.com/paulmach/go.geojson"
)

const geojsonContentType = "application/geo+json"

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/geomap.geojson", s.geoMap)
	mux.HandleFunc("/geomap-arcs.geojson", s.geoMapWithArcs)
	return mux
}

func addHeaders(writer http.ResponseWriter) {
	writer.Header().Set("Content-Type", geojsonContentType)
	writer.Header().Set("Access-Control-Allow-Origin", "*")
}

func (s *scaffold) geoMap(writer http.ResponseWriter, request *http.Request) {
	str, err := s.constructGeoMap(request.Context(), false)
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		return
	}

	addHeaders(writer)
	_, _ = writer.Write(str)
}

func (s *scaffold) geoMapWithArcs(writer http.ResponseWriter, request *http.Request) {
	str, err := s.constructGeoMap(request.Context(), true)
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		return
	}

	addHeaders(writer)
	_, _ = writer.Write(str)
}

func (s *scaffold) constructGeoMap(ctx context.Context, doArcs bool) ([]byte, error) {
	all, err := s.flights.ListAll(ctx, &emptypb.Empty{})
	if err != nil {
		return nil, terrors.Augment(err, "failed to list flights", nil)
	}

	j := geojson.NewFeatureCollection()

	for {
		next, err := all.Recv()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, terrors.Augment(err, "failed to receive flight", nil)
		}

		j.AddFeature(line(next, doArcs))
	}

	str, err := j.MarshalJSON()
	if err != nil {
		return nil, terrors.Augment(err, "failed to marshal geojson", nil)
	}
	return str, nil
}

func line(flight *s_rpc_flights.Flight, doArcs bool) *geojson.Feature {
	if !doArcs {
		return geojson.NewLineStringFeature([][]float64{
			{
				flight.Src.Lon,
				flight.Src.Lat,
			},
			{
				flight.Dst.Lon,
				flight.Dst.Lat,
			},
		})
	}

	a := s2.PointFromLatLng(s2.LatLngFromDegrees(flight.Src.Lat, flight.Src.Lon))
	b := s2.PointFromLatLng(s2.LatLngFromDegrees(flight.Dst.Lat, flight.Dst.Lon))

	n := 100 // number of intermediate points
	coords := make([][]float64, n+1)
	for i := 0; i <= n; i++ {
		t := float64(i) / float64(n)
		p := s2.Point{Vector: a.Vector.Mul(1 - t).Add(b.Vector.Mul(t)).Normalize()}
		ll := s2.LatLngFromPoint(p)
		coords[i] = []float64{ll.Lng.Degrees(), ll.Lat.Degrees()}
	}

	return geojson.NewLineStringFeature(coords)

}
