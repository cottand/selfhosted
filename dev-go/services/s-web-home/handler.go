package module

import (
	"log/slog"
	"net/http"

	"github.com/gsxhq/gsx"
	"github.com/monzo/terrors"
)

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(writer http.ResponseWriter, request *http.Request) {
		render(writer, request, Home())
	})
	return mux
}

func render(writer http.ResponseWriter, request *http.Request, node gsx.Node) {
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	err := node.Render(request.Context(), writer)
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to render page", "err", terrors.Propagate(err))
	}
}
