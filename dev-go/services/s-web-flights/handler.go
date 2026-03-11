package module

import (
	"context"
	"errors"
	"io"
	"net/http"

	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"

	geojson "github.com/paulmach/go.geojson"
)

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/geomap.json", s.geoMap)
	return mux
}

func (s *scaffold) geoMap(writer http.ResponseWriter, request *http.Request) {
	str, err := s.constructGeoMap(request.Context())
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		return
	}

	writer.Header().Set("Content-Type", "application/json")
	_, _ = writer.Write(str)
}

func (s *scaffold) constructGeoMap(ctx context.Context) ([]byte, error) {
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

		j.AddFeature(geojson.NewLineStringFeature([][]float64{
			{
				next.Src.Lat,
				next.Src.Lon,
			},
			{
				next.Dst.Lat,
				next.Dst.Lon,
			},
		}))

	}

	str, err := j.MarshalJSON()
	if err != nil {
		return nil, terrors.Augment(err, "failed to marshal geojson", nil)
	}
	return str, nil
}
