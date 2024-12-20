package module

import (
	"bytes"
	"cloud.google.com/go/bigquery"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
	"net/http"
	"time"
)

type WorkflowJobEntity struct {
	HeadBranch string `json:"head_branch"`
	HeadSha    string `json:"head_sha"`
	Status     string `json:"status"`
	Conclusion string `json:"conclusion"`
	Name       string `json:"name"`
}

type WorkflowJobEvent struct {
	Action      string             `json:"action"`
	WorkflowJob *WorkflowJobEntity `json:"workflow_job,omitempty"`
}

var lastApplied = time.Unix(0, 0)
var stagger = 20 * time.Second

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/", s.handlePush)
	return mux
}

func (s *scaffold) handlePush(writer http.ResponseWriter, request *http.Request) {
	defer writer.WriteHeader(http.StatusNoContent)
	ctx := request.Context()
	fullBody := new(bytes.Buffer)
	_, err := fullBody.ReadFrom(request.Body)
	if err != nil {
		slog.WarnContext(ctx, "failed to read request into memory", "err", terrors.Propagate(err))
	}
	ghSecret, err := ghWebhookSecret(ctx)
	if err != nil {
		slog.WarnContext(ctx, "failed to reach Vault to fetch the gh secret - cannot validate event, skipping!", "err", err)
		return
	}
	ghHmac256 := request.Header.Get("X-Hub-Signature-256")
	err = validateWebhookHmac(ctx, fullBody.Bytes(), ghSecret, ghHmac256)
	if err != nil {
		slog.InfoContext(ctx, "skipping invalid push event", "err", err)
		return
	}
	event := WorkflowJobEvent{}
	if err := json.Unmarshal(fullBody.Bytes(), &event); err != nil {
		slog.WarnContext(ctx, "could not parse push event", "err", err)
		return
	}
	go func() {
		// flag for putting events into BQ
		if false {
			ctx = context.WithoutCancel(ctx)
			err = s.reportEvent(ctx, &event)
			if err != nil {
				slog.WarnContext(ctx, "could not report event", "err", err)
			}
		}
	}()
	if lastApplied.Add(stagger).After(time.Now()) {
		return
	}
	defer func() {
		lastApplied = time.Now()
	}()

	if !shouldAcceptEvent(&event) {
		slog.Debug("ignoring non-success push event")
		return
	}
	newCtx := ctx
	go s.deploy(newCtx, event.WorkflowJob.HeadSha)
}

func shouldAcceptEvent(event *WorkflowJobEvent) bool {
	if event.Action != "completed" ||
		event.WorkflowJob == nil ||
		event.WorkflowJob.HeadBranch != "master" ||
		event.WorkflowJob.Name != "build-images" ||
		event.WorkflowJob.Status != "completed" ||
		event.WorkflowJob.Conclusion != "success" {
		return false
	}
	return true
}

func ghWebhookSecret(ctx context.Context) (string, error) {
	secret, err := secretstore.GetString(ctx, "services/s-web-github-webhook/webhook_secret")
	if err != nil {
		return "", terrors.Augment(err, "failed to fetch webhook secret from vault", nil)
	}
	whSecret, ok := secret["value"]
	if !ok {
		return "", terrors.NotFound("missing_secret", "failed to patse webhook secret from vault", nil)
	}
	return whSecret, nil
}

func validateWebhookHmac(ctx context.Context, payloadBody []byte, secret, digestGH256 string) error {
	disabled, _ := config.Get(ctx, "webhook/disableValidation").Bool()
	if disabled {
		slog.WarnContext(ctx, "webhook validation is disabled")
		return nil
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payloadBody)
	actualSignature := "sha256=" + hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(actualSignature), []byte(digestGH256)) {
		return terrors.Forbidden("invalid", "request signatures didn't match", map[string]string{
			"header_expected": digestGH256,
			"actual":          actualSignature,
		})
	}
	slog.InfoContext(ctx, "event validation OK ✅")
	return nil
}

func (s *scaffold) deploy(ctx context.Context, commit string) {

	ctx, span := tracer.Start(ctx, "deployOnPush")
	defer span.End()

	deployRequest := &s_rpc_nomad_api.Job{
		Version:       &s_rpc_nomad_api.Job_Commit{Commit: commit},
		JobPathInRepo: "dev-go/services/job.nix",
	}
	_, err := s.nomad.Deploy(ctx, deployRequest)
	if err != nil {
		slog.Warn("failed to deploy job", "err", err.Error())
	}
}

func (s *scaffold) reportEvent(ctx context.Context, event *WorkflowJobEvent) error {
	q := `
INSERT INTO dcotta-com.default.actions (inserted_at, head_branch, head_sha, status, conclusion, name) values
	(CURRENT_TIMESTAMP(), ?, ?, ?, ?, ?)
`
	query := s.bq.Query(q)
	query.Parameters = []bigquery.QueryParameter{
		{Value: event.WorkflowJob.HeadSha},
		{Value: event.WorkflowJob.HeadBranch},
		{Value: event.WorkflowJob.Status},
		{Value: event.WorkflowJob.Conclusion},
		{Value: event.WorkflowJob.Name},
	}
	_, err := query.Run(ctx)
	if err != nil {
		return terrors.Augment(err, "failed to insert action into bq", nil)
	}
	slog.Debug("successfully submitted BQ query ✅", "head_sha", event.WorkflowJob.HeadSha)
	// check BigQuery dashboard to see if the job succeeded
	return nil
}
