package module

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

type fakeGitHub struct {
	mu    sync.Mutex
	files map[string]string
	calls []string
}

func (f *fakeGitHub) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	path := strings.TrimPrefix(request.URL.Path, "/")
	f.calls = append(f.calls, request.Method+" "+path)

	switch request.Method {
	case http.MethodGet:
		if sha, ok := f.files[path]; ok {
			_ = json.NewEncoder(writer).Encode(ghEntry{Name: filepath.Base(path), Path: path, SHA: sha, Type: "file"})
			return
		}
		var entries []ghEntry
		for name, sha := range f.files {
			if filepath.Dir(name) == path {
				entries = append(entries, ghEntry{Name: filepath.Base(name), Path: name, SHA: sha, Type: "file"})
			}
		}
		if entries == nil {
			http.NotFound(writer, request)
			return
		}
		_ = json.NewEncoder(writer).Encode(entries)
	case http.MethodPut:
		_, exists := f.files[path]
		f.files[path] = "sha-" + path
		if exists {
			writer.WriteHeader(http.StatusOK)
		} else {
			writer.WriteHeader(http.StatusCreated)
		}
	case http.MethodDelete:
		var body struct {
			SHA string `json:"sha"`
		}
		_ = json.NewDecoder(request.Body).Decode(&body)
		if f.files[path] != body.SHA {
			http.Error(writer, "sha mismatch", http.StatusConflict)
			return
		}
		delete(f.files, path)
	}
}

func withFakeGitHub(t *testing.T, files map[string]string) *fakeGitHub {
	fake := &fakeGitHub{files: files}
	srv := httptest.NewServer(fake)
	t.Cleanup(srv.Close)
	previous := contentsURL
	contentsURL = srv.URL + "/"
	t.Cleanup(func() { contentsURL = previous })
	return fake
}

func TestReplaceFileDeletesOtherExtensionsOfSameKind(t *testing.T) {
	fake := withFakeGitHub(t, map[string]string{
		"assets/car/slot.jpg": "sha-old-slot",
		"assets/car/real.jpg": "sha-real",
	})

	err := replaceFile(context.Background(), "token", "assets/car/slot.png", []byte("img"), isKind("slot"))

	assert.NoError(t, err)
	assert.Equal(t, map[string]string{
		"assets/car/slot.png": "sha-assets/car/slot.png",
		"assets/car/real.jpg": "sha-real",
	}, fake.files)
	assert.Equal(t, "DELETE assets/car/slot.jpg", fake.calls[len(fake.calls)-1], "superseded file is deleted after the upload")
}

func TestReplaceFileSameNameDoesNotDelete(t *testing.T) {
	fake := withFakeGitHub(t, map[string]string{"assets/car/slot.png": "sha-old"})

	err := replaceFile(context.Background(), "token", "assets/car/slot.png", []byte("img"), isKind("slot"))

	assert.NoError(t, err)
	assert.Equal(t, map[string]string{"assets/car/slot.png": "sha-assets/car/slot.png"}, fake.files)
}

func TestReplaceFileNewDirectory(t *testing.T) {
	fake := withFakeGitHub(t, map[string]string{})

	err := replaceFile(context.Background(), "token", "assets/new/real.webp", []byte("img"), isKind("real"))

	assert.NoError(t, err)
	assert.Equal(t, map[string]string{"assets/new/real.webp": "sha-assets/new/real.webp"}, fake.files)
}

func TestReplaceFileWithoutSupersedesSkipsListing(t *testing.T) {
	fake := withFakeGitHub(t, map[string]string{"catalog.xlsx": "sha-old"})

	err := replaceFile(context.Background(), "token", "catalog.xlsx", []byte("xlsx"), nil)

	assert.NoError(t, err)
	assert.Equal(t, []string{"GET catalog.xlsx", "PUT catalog.xlsx"}, fake.calls)
}

func TestRemoveFilesDeletesEveryExtensionOfKind(t *testing.T) {
	fake := withFakeGitHub(t, map[string]string{
		"assets/car/slot.jpg": "sha-slot-jpg",
		"assets/car/slot.png": "sha-slot-png",
		"assets/car/real.jpg": "sha-real",
	})

	deleted, err := removeFiles(context.Background(), "token", "assets/car", isKind("slot"))

	assert.NoError(t, err)
	assert.ElementsMatch(t, []string{"assets/car/slot.jpg", "assets/car/slot.png"}, deleted)
	assert.Equal(t, map[string]string{"assets/car/real.jpg": "sha-real"}, fake.files)
}

func TestRemoveFilesMissingDirectory(t *testing.T) {
	withFakeGitHub(t, map[string]string{})

	deleted, err := removeFiles(context.Background(), "token", "assets/none", isKind("slot"))

	assert.NoError(t, err)
	assert.Empty(t, deleted)
}
