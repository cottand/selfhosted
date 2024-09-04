package module

import (
	"context"
	"encoding/json"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/monzo/terrors"
	"log/slog"
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
	if lastApplied.Add(stagger).After(time.Now()) {
		return
	}
	defer func() {
		lastApplied = time.Now()
	}()
	event := WorkflowJobEvent{}
	decoder := json.NewDecoder(request.Body)
	err := terrors.Propagate(decoder.Decode(&event))
	if err != nil {
		logger.Warn("could not handle push event", "errorMsg", err.Error())
		return
	}
	if !shouldAcceptEvent(&event) {
		return
	}
	newCtx := context.WithoutCancel(request.Context())
	go s.deploy(newCtx, event.WorkflowJob.HeadSha)
}

func shouldAcceptEvent(event *WorkflowJobEvent) bool {
	if event.Action != "completed" ||
		event.WorkflowJob == nil ||
		event.WorkflowJob.HeadBranch != "master" ||
		event.WorkflowJob.Name != "build-images" ||
		event.WorkflowJob.Status != "complete" ||
		event.WorkflowJob.Conclusion != "success" {
		return false
	}
	return true
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
		slog.Warn("failed to deploy job", "errorMsg", err.Error())
	}
}
