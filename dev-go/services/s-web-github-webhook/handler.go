package module

import (
	"context"
	"encoding/json"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/monzo/terrors"
	"io"
	"log/slog"
	"net/http"
	"time"
)

type PushEvent struct {
	Ref   string `json:"ref"`
	After string `json:"after"`
}

var lastApplied = time.Unix(0, 0)
var stagger = 20 * time.Second

func (s *scaffold) MakeHTTPHandler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/", s.handlePush)
	return mux
}

func (s *scaffold) handlePush(writer http.ResponseWriter, request *http.Request) {
	newCtx := context.WithoutCancel(request.Context())
	go s.deploy(newCtx, request.Clone(newCtx).Body)
	writer.WriteHeader(http.StatusNoContent)
}

func (s *scaffold) deploy(ctx context.Context, body io.ReadCloser) {
	defer func() {
		_ = body.Close()
	}()

	ctx, span := tracer.Start(ctx, "deployOnPush")
	defer span.End()

	if lastApplied.Add(stagger).After(time.Now()) {
		return
	}
	defer func() {
		lastApplied = time.Now()
	}()

	pushEvent := PushEvent{}
	decoder := json.NewDecoder(body)
	err := terrors.Propagate(decoder.Decode(&pushEvent))
	if err != nil {
		span.RecordError(err)
		logger.Warn("could not handle push event", "errorMsg", err.Error())
	}

	if pushEvent.Ref != "refs/heads/master" {
		logger.Info("push event is not master branch, baling", "ref", pushEvent.Ref)
		return
	}

	deployRequest := &s_rpc_nomad_api.Job{
		Version:       &s_rpc_nomad_api.Job_Commit{Commit: pushEvent.After},
		JobPathInRepo: "dev-go/services/job.nix",
	}
	_, err = s.nomad.Deploy(ctx, deployRequest)
	if err != nil {
		slog.Warn("failed to deploy job", "errorMsg", err.Error())
	}
}
