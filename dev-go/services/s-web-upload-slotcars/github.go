package module

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

const (
	commitMsg         = "s-web-upload-slotcars: automated upload"
	ghTokenSecretPath = "services/s-web-upload-slotcars/gh/slotcars-contents-rw"
)

var contentsURL = "https://api.github.com/repos/cottand/slotcars/contents/"

var ghClient = &http.Client{
	Timeout:   30 * time.Second,
	Transport: otelhttp.NewTransport(http.DefaultTransport),
}

func ghToken(ctx context.Context) (string, error) {
	secret, err := secretstore.GetString(ctx, ghTokenSecretPath)
	if err != nil {
		return "", terrors.Augment(err, "failed to fetch github token from vault", nil)
	}
	token, ok := secret["token"]
	if !ok {
		return "", terrors.NotFound("missing_secret", "missing 'token' key in github token secret", nil)
	}
	return token, nil
}

// uploadFile creates or replaces the file at filePath in cottand/slotcars with content. If supersedes
// is not nil, files in the same directory whose name it matches are deleted once the upload succeeds
func uploadFile(ctx context.Context, filePath string, content []byte, supersedes func(name string) bool) error {
	token, err := ghToken(ctx)
	if err != nil {
		return err
	}
	return replaceFile(ctx, token, filePath, content, supersedes)
}

func replaceFile(ctx context.Context, token, filePath string, content []byte, supersedes func(name string) bool) error {
	var superseded []ghEntry
	if supersedes != nil {
		siblings, err := listDir(ctx, token, path.Dir(filePath))
		if err != nil {
			return err
		}
		for _, entry := range siblings {
			if entry.Type == "file" && entry.Path != filePath && supersedes(entry.Name) {
				superseded = append(superseded, entry)
			}
		}
	}

	if err := putFile(ctx, token, filePath, content); err != nil {
		return err
	}
	for _, entry := range superseded {
		if err := deleteFile(ctx, token, entry); err != nil {
			return terrors.Augment(err, "uploaded file but failed to delete the file it supersedes", map[string]string{"superseded": entry.Path})
		}
	}
	return nil
}

func putFile(ctx context.Context, token, path string, content []byte) error {
	sha, err := fileSHA(ctx, token, path)
	if err != nil {
		return err
	}

	body, err := json.Marshal(struct {
		Message string `json:"message"`
		Content string `json:"content"`
		SHA     string `json:"sha,omitempty"`
	}{
		Message: commitMsg,
		Content: base64.StdEncoding.EncodeToString(content),
		SHA:     sha,
	})
	if err != nil {
		return terrors.Augment(err, "failed to marshal github request", nil)
	}

	response, err := ghDo(ctx, token, http.MethodPut, path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK && response.StatusCode != http.StatusCreated {
		return ghError(response)
	}
	return nil
}

func deleteFile(ctx context.Context, token string, entry ghEntry) error {
	body, err := json.Marshal(struct {
		Message string `json:"message"`
		SHA     string `json:"sha"`
	}{
		Message: commitMsg,
		SHA:     entry.SHA,
	})
	if err != nil {
		return terrors.Augment(err, "failed to marshal github request", nil)
	}

	response, err := ghDo(ctx, token, http.MethodDelete, entry.Path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return ghError(response)
	}
	return nil
}

type ghEntry struct {
	Name string `json:"name"`
	Path string `json:"path"`
	SHA  string `json:"sha"`
	Type string `json:"type"`
}

// listDir returns the entries of the directory at path, or none if it does not exist yet
func listDir(ctx context.Context, token, path string) ([]ghEntry, error) {
	response, err := ghDo(ctx, token, http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusNotFound {
		return nil, nil
	}
	if response.StatusCode != http.StatusOK {
		return nil, ghError(response)
	}

	var entries []ghEntry
	if err := json.NewDecoder(response.Body).Decode(&entries); err != nil {
		return nil, terrors.Augment(err, "failed to decode github directory listing", map[string]string{"path": path})
	}
	return entries, nil
}

// fileSHA returns the blob SHA of the file currently at path, which GitHub requires in order to
// replace it, or an empty string if there is none yet
func fileSHA(ctx context.Context, token, path string) (string, error) {
	response, err := ghDo(ctx, token, http.MethodGet, path, nil)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusNotFound {
		return "", nil
	}
	if response.StatusCode != http.StatusOK {
		return "", ghError(response)
	}

	var existing struct {
		SHA string `json:"sha"`
	}
	if err := json.NewDecoder(response.Body).Decode(&existing); err != nil {
		return "", terrors.Augment(err, "failed to decode github contents response", nil)
	}
	return existing.SHA, nil
}

func ghDo(ctx context.Context, token, method, path string, body io.Reader) (*http.Response, error) {
	request, err := http.NewRequestWithContext(ctx, method, contentsURL+path, body)
	if err != nil {
		return nil, terrors.Augment(err, "failed to build github request", nil)
	}
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}

	response, err := ghClient.Do(request)
	if err != nil {
		return nil, terrors.Augment(err, "failed to call github", map[string]string{"method": method, "path": path})
	}
	return response, nil
}

func ghError(response *http.Response) error {
	msg, _ := io.ReadAll(io.LimitReader(response.Body, 4<<10))
	return terrors.New("github_error", fmt.Sprintf("unexpected github response %d: %s", response.StatusCode, msg), map[string]string{
		"method": response.Request.Method,
		"path":   response.Request.URL.Path,
		"status": response.Status,
	})
}
