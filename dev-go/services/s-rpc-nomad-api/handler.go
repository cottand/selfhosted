package module

import (
	"context"
	"encoding/json"
	"fmt"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/farcaller/gonix"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"path"
)

type ProtoHandler struct {
	pb.UnimplementedNomadApiServer
	nomadClient *nomad.Client
}

func (h *ProtoHandler) Deploy(ctx context.Context, job *pb.Job) (*emptypb.Empty, error) {
	rendered, err := jobFileToSpec(ctx, job)
	if err != nil {
		return nil, terrors.Augment(err, "failed to render job", nil)
	}
	res, _, err := h.nomadClient.Jobs().Register(rendered, (&nomad.WriteOptions{}).WithContext(ctx))
	if err != nil {
		return nil, terrors.Augment(err, "failed to register job", nil)
	}
	slog.InfoContext(ctx, "successfully registered nomad job", "jobEvalId", res.EvalID, "jobName", rendered.Name)

	return &emptypb.Empty{}, nil
}

func jobFileToSpec(ctx context.Context, job *pb.Job) (*nomad.Job, error) {
	if job.GetLatest() {
		return nil, terrors.New("not_implemented", "for now only specific commits are supported", nil)
	}
	jobPath := path.Clean(job.JobPathInRepo)
	if path.Ext(jobPath) != ".nix" {
		return nil, terrors.New("not_implemented", "for now only nixmad is supported", nil)
	}
	longSha := job.GetCommit()
	shortSha := longSha[:7]

	errParams := map[string]string{
		"file":     jobPath,
		"shortSha": shortSha,
	}

	slog.DebugContext(ctx, "resolved commit", "sha", longSha, "shortSha", shortSha)

	jobJSON, err := evalNixJobJSON(ctx, jobPath, longSha, shortSha, errParams)
	if err != nil {
		return nil, terrors.Augment(err, "failed to evaluate job file", errParams)
	}

	// trick to support jobs with and without a job: key
	// see https://github.com/hashicorp/nomad/blob/main/command/helpers.go#L399
	eitherJob := struct {
		NestedJob *nomad.Job `json:"Job"`
		nomad.Job
	}{}
	err = json.Unmarshal([]byte(jobJSON), &eitherJob)
	var parsed *nomad.Job
	if eitherJob.NestedJob != nil {
		parsed = eitherJob.NestedJob
	} else {
		parsed = &eitherJob.Job
	}
	if err != nil {
		return nil, terrors.Augment(err, "failed to decode job json", errParams)
	}
	return parsed, nil
}

func evalNixJobJSON(ctx context.Context, jobFilePath string, repoSha string, version string, errParams map[string]string) (string, error) {
	ctx, span := tracer.Start(ctx, "evalNixJobJSON")
	defer span.End()

	nixCtx := gonix.NewContext()
	_ = gonix.SetSetting(nixCtx, "extra-experimental-features", "flakes")

	store, err := gonix.NewStore(nixCtx, "dummy", nil)
	if err != nil {
		span.RecordError(err)
		return "", terrors.Augment(err, "failed to create a store", errParams)
	}
	state := store.NewState(nil)

	evalString := fmt.Sprintf(`
		let 
		  flake = builtins.getFlake "github:cottand/selfhosted/%s";
		  jobFile = import "${flake}/%s";
		  withVersion = jobFile { version = "%s"; };
		in
		  builtins.toJSON withVersion
	`, repoSha, jobFilePath, version)

	jobVal, err := state.EvalExpr(evalString, "/")
	if err != nil {
		span.RecordError(err)
		return "", terrors.Augment(err, "failed to eval job expression", errParams)
	}

	jobJson, err := jobVal.GetString()
	if err != nil {
		span.RecordError(err)
		return "", terrors.Augment(err, "failed to resolve job json to string", errParams)
	}

	return jobJson, nil
}
