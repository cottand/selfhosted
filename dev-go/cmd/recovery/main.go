package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"golang.org/x/sync/semaphore"
)

type filerEntry struct {
	FullPath string      `json:"FullPath"`
	Chunks   []any       `json:"chunks"`
	Mode     fs.FileMode `json:"Mode"`
}

func (e filerEntry) isDirectory() bool {
	return e.Mode.IsDir()
}

type filerListing struct {
	Path                  string       `json:"Path"`
	Entries               []filerEntry `json:"Entries"`
	LastFileName          string       `json:"LastFileName"`
	ShouldDisplayLoadMore bool         `json:"ShouldDisplayLoadMore"`
}

type stats struct {
	scanned  int
	healthy  int
	restored int
	missing  int
	errors   int
}

func main() {
	basePath := flag.String("base-path", "/buckets/documents", "filer path to walk")
	filerURL := flag.String("filer-url", "https://seaweed-filer-http.tfk.nd", "filer root URL")
	dryRun := flag.Bool("dry-run", false, "log what would happen without writing")
	bucket := flag.String("bucket", "seaweedfs-bu", "B2 bucket name")
	flag.Parse()

	keyID := os.Getenv("B2_KEY_ID")
	secretKey := os.Getenv("B2_SECRET_KEY")
	if keyID == "" || secretKey == "" {
		slog.Error("B2_KEY_ID and B2_SECRET_KEY environment variables are required")
		os.Exit(1)
	}

	s3Client := s3.NewFromConfig(aws.Config{
		BaseEndpoint: aws.String("https://s3.us-east-005.backblazeb2.com"),
		Region:       "us-east-005",
		Credentials: aws.CredentialsProviderFunc(func(ctx context.Context) (aws.Credentials, error) {
			return aws.Credentials{
				AccessKeyID:     keyID,
				SecretAccessKey: secretKey,
			}, nil
		}),
	})

	httpClient := &http.Client{}
	ctx := context.Background()

	slog.Info("starting recovery", "basePath", *basePath, "filerURL", *filerURL, "dryRun", *dryRun, "bucket", *bucket)

	s := walkAndRecover(ctx, httpClient, s3Client, *filerURL, *basePath, *bucket, *dryRun)

	slog.Info("recovery complete",
		"scanned", s.scanned,
		"healthy", s.healthy,
		"restored", s.restored,
		"missing", s.missing,
		"errors", s.errors,
	)
}

func walkAndRecover(ctx context.Context, httpClient *http.Client, s3Client *s3.Client, filerURL, dirPath, bucket string, dryRun bool) stats {
	var s stats
	var lastFileName string

	for {
		listing, err := listDirectory(ctx, httpClient, filerURL, dirPath, lastFileName)
		if err != nil {
			slog.Error("failed to list directory", "path", dirPath, "err", err)
			s.errors++
			return s
		}

		wg := sync.WaitGroup{}
		sema := semaphore.NewWeighted(10)

		for _, entry := range listing.Entries {
			wg.Go(func() {
				if err := sema.Acquire(ctx, 1); err != nil {
					slog.Error("failed to acquire semaphore", "err", err)
					return
				}
				defer sema.Release(1)
				if entry.isDirectory() {
					sub := walkAndRecover(ctx, httpClient, s3Client, filerURL, entry.FullPath, bucket, dryRun)
					s.scanned += sub.scanned
					s.healthy += sub.healthy
					s.restored += sub.restored
					s.missing += sub.missing
					s.errors += sub.errors
				} else if strings.HasSuffix(entry.FullPath, ".missing_7jun26") {
					slog.Debug("skipping already-marked file", "path", entry.FullPath)
				} else {
					checkAndRecover(ctx, httpClient, s3Client, filerURL, entry.FullPath, bucket, dryRun, &s)
				}
			})
		}
		wg.Wait()

		if !listing.ShouldDisplayLoadMore {
			break
		}
		lastFileName = listing.LastFileName
	}

	return s
}

func listDirectory(ctx context.Context, httpClient *http.Client, filerURL, dirPath, lastFileName string) (*filerListing, error) {
	u := filerURL + dirPath + "/"
	if lastFileName != "" {
		u += "?lastFileName=" + url.QueryEscape(lastFileName)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("requesting directory listing: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status %d for %s", resp.StatusCode, u)
	}

	var listing filerListing
	if err := json.NewDecoder(resp.Body).Decode(&listing); err != nil {
		return nil, fmt.Errorf("decoding listing: %w", err)
	}
	return &listing, nil
}

func checkAndRecover(ctx context.Context, httpClient *http.Client, s3Client *s3.Client, filerURL, filePath, bucket string, dryRun bool, s *stats) {
	s.scanned++

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, filerURL+filePath, nil)
	if err != nil {
		slog.Error("creating check request", "path", filePath, "err", err)
		s.errors++
		return
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		slog.Error("checking file", "path", filePath, "err", err)
		s.errors++
		return
	}
	resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		slog.Debug("healthy", "path", filePath)
		s.healthy++
		return
	}

	if resp.StatusCode != http.StatusInternalServerError {
		slog.Warn("unexpected status", "path", filePath, "status", resp.StatusCode)
		s.errors++
		return
	}

	slog.Warn("data loss detected", "path", filePath)

	if tryRestore(ctx, httpClient, s3Client, filerURL, filePath, bucket, dryRun) {
		slog.Info("restored", "path", filePath, "dryRun", dryRun)
		s.restored++
	} else {
		markMissing(ctx, httpClient, filerURL, filePath, dryRun)
		slog.Warn("marked as missing", "path", filePath)
		s.missing++
	}
}

func tryRestore(ctx context.Context, httpClient *http.Client, s3Client *s3.Client, filerURL, filePath, bucket string, dryRun bool) bool {
	relPath := strings.TrimPrefix(filePath, "/")
	prefixes := []string{"snapshot2/", "snapshot/"}

	for _, prefix := range prefixes {
		key := prefix + relPath
		out, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(key),
		})
		if err != nil {
			slog.Debug("backup not found", "key", key, "err", err)
			continue
		}

		if dryRun {
			out.Body.Close()
			slog.Info("[dry-run] would restore from backup", "key", key, "path", filePath)
			return true
		}

		err = uploadToFiler(ctx, httpClient, filerURL, filePath, out.Body)
		out.Body.Close()
		if err != nil {
			slog.Error("failed to upload restored file", "path", filePath, "key", key, "err", err)
			continue
		}
		return true
	}
	return false
}

func uploadToFiler(ctx context.Context, httpClient *http.Client, filerURL, filePath string, body io.Reader) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, filerURL+filePath, body)
	if err != nil {
		return fmt.Errorf("creating upload request: %w", err)
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("uploading to filer: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("filer upload returned status %d", resp.StatusCode)
	}
	return nil
}

func markMissing(ctx context.Context, httpClient *http.Client, filerURL, filePath string, dryRun bool) {
	newPath := filePath + ".missing_7jun26"
	if dryRun {
		slog.Info("[dry-run] would rename", "from", filePath, "to", newPath)
		return
	}

	u := filerURL + newPath + "?mv.from=" + url.QueryEscape(filePath)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, u, nil)
	if err != nil {
		slog.Error("creating rename request", "path", filePath, "err", err)
		return
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		slog.Error("renaming file", "path", filePath, "err", err)
		return
	}
	resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		slog.Error("rename failed", "path", filePath, "status", resp.StatusCode)
	}
}
