package module

import (
	"log/slog"
	"net/http"

	"github.com/gsxhq/gsx"
	"github.com/monzo/terrors"
)

const maxUploadBytes = 32 << 20

func MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", index)
	mux.HandleFunc("POST /upload", upload)
	return mux
}

func index(writer http.ResponseWriter, request *http.Request) {
	render(writer, request, Upload())
}

func upload(writer http.ResponseWriter, request *http.Request) {
	request.Body = http.MaxBytesReader(writer, request.Body, maxUploadBytes)
	file, header, err := request.FormFile("file")
	if err != nil {
		http.Error(writer, "expected a spreadsheet in the 'file' field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	slog.InfoContext(request.Context(), "received spreadsheet", "name", header.Filename, "size", header.Size)
	// TODO process the uploaded spreadsheet
	writer.WriteHeader(http.StatusOK)
}

func render(writer http.ResponseWriter, request *http.Request, node gsx.Node) {
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	err := node.Render(request.Context(), writer)
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to render page", "err", terrors.Propagate(err))
	}
}
