package module

import (
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"path/filepath"
	"strings"

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
	ctx := request.Context()
	request.Body = http.MaxBytesReader(writer, request.Body, maxUploadBytes)
	file, header, err := request.FormFile("file")
	if maxBytesErr := (*http.MaxBytesError)(nil); errors.As(err, &maxBytesErr) {
		http.Error(writer, fmt.Sprintf("file is too large, the limit is %dMB", maxUploadBytes>>20), http.StatusRequestEntityTooLarge)
		return
	}
	if err != nil {
		http.Error(writer, "expected a spreadsheet in the 'file' field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	if ext := filepath.Ext(header.Filename); !strings.EqualFold(ext, ".xlsx") {
		http.Error(writer, fmt.Sprintf("%q is not an Excel spreadsheet, only .xlsx files are accepted", header.Filename), http.StatusBadRequest)
		return
	}

	content, err := io.ReadAll(file)
	if err != nil {
		slog.ErrorContext(ctx, "failed to read upload", "err", terrors.Propagate(err))
		http.Error(writer, "failed to read uploaded file", http.StatusInternalServerError)
		return
	}

	slog.InfoContext(ctx, "received spreadsheet", "name", header.Filename, "size", header.Size)
	if err := uploadCatalog(ctx, content); err != nil {
		slog.ErrorContext(ctx, "failed to upload catalog to github", "err", terrors.Propagate(err))
		// not a 502, which Cloudflare would replace with its own error page
		http.Error(writer, "failed to upload the spreadsheet to GitHub, try again later", http.StatusInternalServerError)
		return
	}
	writer.WriteHeader(http.StatusOK)
}

func render(writer http.ResponseWriter, request *http.Request, node gsx.Node) {
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	err := node.Render(request.Context(), writer)
	if err != nil {
		slog.ErrorContext(request.Context(), "failed to render page", "err", terrors.Propagate(err))
	}
}
