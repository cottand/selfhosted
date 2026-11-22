package module

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

const (
	contentsURL       = "https://api.github.com/repos/cottand/slotcars/contents/"
	commitMsg         = "s-web-upload-slotcars: automated upload"
	ghTokenSecretPath = "services/s-web-upload-slotcars/gh/slotcars-contents-rw"
)

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

// uploadFile creates or replaces the file at path in cottand/slotcars with content
func uploadFile(ctx context.Context, path string, content []byte) error {
	token, err := ghToken(ctx)
	if err != nil {
		return err
	}

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
