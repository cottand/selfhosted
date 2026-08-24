package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"golang.org/x/sync/semaphore"

	"github.com/cottand/selfhosted/dev-go/lib/macoskeychain"
)

const apiBase = "/api/v4"

const keychainIdentityLabel = "mtls-personal-m3-nico.mtls.dcotta.com"

const simpleUploadMaxBytes int64 = 50 * 1024 * 1024

type cloudreveResponse struct {
	Code int             `json:"code"`
	Msg  string          `json:"msg"`
	Data json.RawMessage `json:"data"`
}

type uploadSession struct {
	SessionID string `json:"session_id"`
	ChunkSize int64  `json:"chunk_size"`
}

type stats struct {
	uploaded atomic.Int64
	skipped  atomic.Int64
	errors   atomic.Int64
}

/*
	go run ./dev-go/cmd/s3-to-cloudreve \
	    --s3-uri s3://my-bucket/some/prefix \
	    --target-dir /photos/backup \
	    --dry-run
*/
func main() {
	s3URI := flag.String("s3-uri", "", "S3 source URI (e.g., s3://bucket/prefix)")
	targetDir := flag.String("target-dir", "/s3-import", "Cloudreve destination directory path (e.g., /photos/backup)")
	cloudreveURL := flag.String("cloudreve-url", "https://files.dcotta.com", "Cloudreve base URL")
	concurrency := flag.Int64("concurrency", 5, "max concurrent uploads")
	dryRun := flag.Bool("dry-run", false, "list objects without uploading")
	flag.Parse()

	if *s3URI == "" {
		slog.Error("--s3-uri is required")
		os.Exit(1)
	}

	cloudreveTargetDir := "cloudreve://my" + *targetDir

	bucket, prefix, err := parseS3URI(*s3URI)
	if err != nil {
		slog.Error("invalid S3 URI", "uri", *s3URI, "err", err)
		os.Exit(1)
	}

	s3Endpoint := os.Getenv("AWS_ENDPOINT_URL_S3")
	if s3Endpoint == "" {
		slog.Error("AWS_ENDPOINT_URL_S3 environment variable is required")
		os.Exit(1)
	}

	s3Region := os.Getenv("AWS_REGION")
	if s3Region == "" {
		s3Region = "us-east-1"
	}

	keyID := os.Getenv("AWS_ACCESS_KEY_ID")
	secretKey := os.Getenv("AWS_SECRET_ACCESS_KEY")
	if keyID == "" || secretKey == "" {
		slog.Error("AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables are required")
		os.Exit(1)
	}

	cloudreveToken := os.Getenv("CLOUDREVE_BEARER_TOKEN")
	if cloudreveToken == "" {
		slog.Error("CLOUDREVE_BEARER_TOKEN environment variable is required")
		os.Exit(1)
	}

	s3Client := s3.NewFromConfig(aws.Config{
		BaseEndpoint: aws.String(s3Endpoint),
		Region:       s3Region,
		Credentials: aws.CredentialsProviderFunc(func(ctx context.Context) (aws.Credentials, error) {
			return aws.Credentials{
				AccessKeyID:     keyID,
				SecretAccessKey: secretKey,
			}, nil
		}),
	})

	identity, err := macoskeychain.LoadIdentity(keychainIdentityLabel)
	if err != nil {
		slog.Error("loading keychain identity", "label", keychainIdentityLabel, "err", err)
		os.Exit(1)
	}
	slog.Info("loaded mTLS client certificate", "label", keychainIdentityLabel)

	httpClient := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				Certificates: []tls.Certificate{identity},
			},
		},
	}
	ctx := context.Background()

	slog.Info("starting copy",
		"bucket", bucket,
		"prefix", prefix,
		"cloudreveURL", *cloudreveURL,
		"targetDir", cloudreveTargetDir,
		"dryRun", *dryRun,
	)

	var st stats
	copyAll(ctx, s3Client, httpClient, bucket, prefix,
		*cloudreveURL, cloudreveToken, cloudreveTargetDir, *concurrency, *dryRun, &st)

	slog.Info("copy complete",
		"uploaded", st.uploaded.Load(),
		"skipped", st.skipped.Load(),
		"errors", st.errors.Load(),
	)
}

func parseS3URI(uri string) (bucket, prefix string, err error) {
	if !strings.HasPrefix(uri, "s3://") {
		return "", "", fmt.Errorf("URI must start with s3://")
	}
	rest := strings.TrimPrefix(uri, "s3://")
	parts := strings.SplitN(rest, "/", 2)
	bucket = parts[0]
	if bucket == "" {
		return "", "", fmt.Errorf("empty bucket name")
	}
	if len(parts) > 1 {
		prefix = parts[1]
	}
	return bucket, prefix, nil
}

func copyAll(ctx context.Context, s3Client *s3.Client, httpClient *http.Client,
	bucket, prefix, cloudreveURL, token, cloudreveTargetDir string, concurrency int64,
	dryRun bool, st *stats) {

	var continuationToken *string
	wg := sync.WaitGroup{}
	sema := semaphore.NewWeighted(concurrency)

	for {
		out, err := s3Client.ListObjectsV2(ctx, &s3.ListObjectsV2Input{
			Bucket:            aws.String(bucket),
			Prefix:            aws.String(prefix),
			ContinuationToken: continuationToken,
		})
		if err != nil {
			slog.Error("listing S3 objects", "err", err)
			st.errors.Add(1)
			return
		}

		for _, obj := range out.Contents {
			key := aws.ToString(obj.Key)
			size := aws.ToInt64(obj.Size)

			if strings.HasSuffix(key, "/") {
				st.skipped.Add(1)
				continue
			}

			wg.Go(func() {
				if err := sema.Acquire(ctx, 1); err != nil {
					slog.Error("acquiring semaphore", "err", err)
					return
				}
				defer sema.Release(1)

				relativePath := strings.TrimPrefix(key, prefix)
				relativePath = strings.TrimPrefix(relativePath, "/")
				targetURI := cloudreveTargetDir + "/" + relativePath

				if dryRun {
					slog.Info("[dry-run] would copy", "key", key, "size", size, "target", targetURI)
					return
				}

				exists, err := fileExistsInCloudreve(ctx, httpClient, cloudreveURL, token, targetURI)
				if err != nil {
					slog.Warn("failed to check if file exists, uploading anyway", "target", targetURI, "err", err)
				} else if exists {
					slog.Debug("already exists, skipping", "target", targetURI)
					st.skipped.Add(1)
					return
				}

				if err := copyObject(ctx, s3Client, httpClient,
					bucket, key, size, cloudreveURL, token, targetURI); err != nil {
					slog.Error("copying object", "key", key, "err", err)
					st.errors.Add(1)
					return
				}

				slog.Info("copied", "key", key, "size", size, "target", targetURI)
				st.uploaded.Add(1)
			})
		}

		if !aws.ToBool(out.IsTruncated) {
			break
		}
		continuationToken = out.NextContinuationToken
	}

	wg.Wait()
}

func fileExistsInCloudreve(ctx context.Context, httpClient *http.Client,
	cloudreveURL, token, targetURI string) (bool, error) {

	endpoint := cloudreveURL + apiBase + "/file/info?uri=" + url.QueryEscape(targetURI)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return false, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := httpClient.Do(req)
	if err != nil {
		return false, fmt.Errorf("checking file info: %w", err)
	}
	defer resp.Body.Close()

	var cr cloudreveResponse
	if err := json.NewDecoder(resp.Body).Decode(&cr); err != nil {
		body := bytes.NewBuffer(nil)
		_, _ = body.ReadFrom(resp.Body)
		return false, fmt.Errorf("decoding response: %w, for body %s", err, body.String())
	}
	return cr.Code == 0, nil
}

func copyObject(ctx context.Context, s3Client *s3.Client, httpClient *http.Client,
	bucket, key string, size int64, cloudreveURL, token, targetURI string) error {

	getOut, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("getting S3 object: %w", err)
	}
	defer getOut.Body.Close()

	if size < simpleUploadMaxBytes {
		return simpleUpload(ctx, httpClient, cloudreveURL, token, targetURI, size, getOut.Body)
	}
	return chunkedUpload(ctx, httpClient, cloudreveURL, token, targetURI, size, getOut.Body)
}

func simpleUpload(ctx context.Context, httpClient *http.Client,
	cloudreveURL, token, targetURI string, size int64, body io.Reader) error {

	endpoint := cloudreveURL + apiBase + "/file/content?uri=" + url.QueryEscape(targetURI)

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpoint, body)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/octet-stream")
	req.ContentLength = size

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("uploading: %w", err)
	}
	defer resp.Body.Close()

	return checkCloudreveResponse(resp)
}

func chunkedUpload(ctx context.Context, httpClient *http.Client,
	cloudreveURL, token, targetURI string, size int64, body io.Reader) error {

	session, err := createUploadSession(ctx, httpClient, cloudreveURL, token, targetURI, size)
	if err != nil {
		return fmt.Errorf("creating upload session: %w", err)
	}

	chunkSize := session.ChunkSize
	if chunkSize <= 0 {
		chunkSize = size
	}

	var index int
	remaining := size

	for remaining > 0 {
		thisChunk := chunkSize
		if remaining < thisChunk {
			thisChunk = remaining
		}

		chunkReader := io.LimitReader(body, thisChunk)
		if err := uploadChunk(ctx, httpClient, cloudreveURL, token,
			session.SessionID, index, thisChunk, chunkReader); err != nil {
			return fmt.Errorf("uploading chunk %d: %w", index, err)
		}

		remaining -= thisChunk
		index++
	}

	return nil
}

func createUploadSession(ctx context.Context, httpClient *http.Client,
	cloudreveURL, token, targetURI string, size int64) (*uploadSession, error) {

	endpoint := cloudreveURL + apiBase + "/file/upload"

	payload := map[string]any{
		"uri":  targetURI,
		"size": size,
	}
	jsonBody, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshaling session request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpoint, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("creating session request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("creating session: %w", err)
	}
	defer resp.Body.Close()

	var cr cloudreveResponse
	if err := json.NewDecoder(resp.Body).Decode(&cr); err != nil {
		return nil, fmt.Errorf("decoding session response: %w", err)
	}
	if cr.Code != 0 {
		return nil, fmt.Errorf("session creation failed: code=%d msg=%s", cr.Code, cr.Msg)
	}

	var session uploadSession
	if err := json.Unmarshal(cr.Data, &session); err != nil {
		return nil, fmt.Errorf("decoding session data: %w", err)
	}
	return &session, nil
}

func uploadChunk(ctx context.Context, httpClient *http.Client,
	cloudreveURL, token, sessionID string, index int, size int64, body io.Reader) error {

	endpoint := fmt.Sprintf("%s%s/file/upload/%s/%d", cloudreveURL, apiBase, sessionID, index)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, body)
	if err != nil {
		return fmt.Errorf("creating chunk request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/octet-stream")
	req.ContentLength = size

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("uploading chunk: %w", err)
	}
	defer resp.Body.Close()

	return checkCloudreveResponse(resp)
}

func checkCloudreveResponse(resp *http.Response) error {
	var cr cloudreveResponse
	if err := json.NewDecoder(resp.Body).Decode(&cr); err != nil {
		return fmt.Errorf("decoding response (status %d): %w", resp.StatusCode, err)
	}
	if cr.Code != 0 {
		return fmt.Errorf("API error: code=%d msg=%s", cr.Code, cr.Msg)
	}
	return nil
}
