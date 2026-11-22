package module

import (
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/gsxhq/gsx"
	"github.com/monzo/terrors"
)

const maxUploadBytes = 32 << 20

var (
	imageKinds      = []string{"real", "slot"}
	imageExtensions = []string{".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic", ".avif"}
	imageAccept     = strings.Join(imageExtensions, ",")

	// IDs become a directory under assets/, so they must not be able to escape it
	validID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)
)

func MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", catalogPage)
	mux.HandleFunc("POST /upload", uploadCatalog)
	mux.HandleFunc("GET /image/{id}", imagesPage)
	mux.HandleFunc("POST /image/{id}/{kind}", uploadImage)
	return mux
}

func catalogPage(writer http.ResponseWriter, request *http.Request) {
	render(writer, request, Catalog())
}

func imagesPage(writer http.ResponseWriter, request *http.Request) {
	id := request.PathValue("id")
	if !validID.MatchString(id) {
		http.Error(writer, fmt.Sprintf("%q is not a valid ID", id), http.StatusBadRequest)
		return
	}
	render(writer, request, Images(id, imageKinds))
}

func uploadCatalog(writer http.ResponseWriter, request *http.Request) {
	upload(writer, request, func(filename string) (string, error) {
		if !strings.EqualFold(filepath.Ext(filename), ".xlsx") {
			return "", fmt.Errorf("%q is not an Excel spreadsheet, only .xlsx files are accepted", filename)
		}
		return "catalog.xlsx", nil
	})
}

func uploadImage(writer http.ResponseWriter, request *http.Request) {
	id, kind := request.PathValue("id"), request.PathValue("kind")
	upload(writer, request, func(filename string) (string, error) {
		if !validID.MatchString(id) {
			return "", fmt.Errorf("%q is not a valid ID", id)
		}
		if !slices.Contains(imageKinds, kind) {
			return "", fmt.Errorf("%q is not a known image kind, expected one of %s", kind, strings.Join(imageKinds, ", "))
		}
		ext := filepath.Ext(filename)
		if !slices.Contains(imageExtensions, strings.ToLower(ext)) {
			return "", fmt.Errorf("%q is not a supported image, expected one of %s", filename, imageAccept)
		}
		return "assets/" + id + "/" + kind + ext, nil
	})
}

// upload commits the file uploaded in the 'file' field to the repo path returned by destination,
// which receives the uploaded file's name and may reject it with an error to show the user
func upload(writer http.ResponseWriter, request *http.Request, destination func(filename string) (string, error)) {
	ctx := request.Context()
	request.Body = http.MaxBytesReader(writer, request.Body, maxUploadBytes)
	file, header, err := request.FormFile("file")
	if maxBytesErr := (*http.MaxBytesError)(nil); errors.As(err, &maxBytesErr) {
		http.Error(writer, fmt.Sprintf("file is too large, the limit is %dMB", maxUploadBytes>>20), http.StatusRequestEntityTooLarge)
		return
	}
	if err != nil {
		http.Error(writer, "expected a file in the 'file' field", http.StatusBadRequest)
		return
	}
	defer file.Close()

	path, err := destination(header.Filename)
	if err != nil {
		http.Error(writer, err.Error(), http.StatusBadRequest)
		return
	}

	content, err := io.ReadAll(file)
	if err != nil {
		slog.ErrorContext(ctx, "failed to read upload", "err", terrors.Propagate(err))
		http.Error(writer, "failed to read uploaded file", http.StatusInternalServerError)
		return
	}

	slog.InfoContext(ctx, "received upload", "name", header.Filename, "size", header.Size, "path", path)
	if err := uploadFile(ctx, path, content); err != nil {
		slog.ErrorContext(ctx, "failed to upload file to github", "path", path, "err", terrors.Propagate(err))
		// not a 502, which Cloudflare would replace with its own error page
		http.Error(writer, "failed to upload the file to GitHub, try again later", http.StatusInternalServerError)
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
