package module

import (
	"context"
	"net/http"
)

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/geomap.json", s.geoMap)
	return mux
}

func (s *scaffold) geoMap(writer http.ResponseWriter, request *http.Request) {
	str, err := constructGeoMap(request.Context())
	if err != nil {
		writer.WriteHeader(http.StatusInternalServerError)
		return
	}
	writer.Header().Set("Content-Type", "application/json")
	_, _ = writer.Write([]byte(str))
}

func constructGeoMap(ctx context.Context) (string, error) {
	return "", nil
}
