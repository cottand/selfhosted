package module

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/config"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/farcaller/gonix"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
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

	dryRunEnabled, _ := config.Get(ctx, "deploy/dryRunEnabled").Bool()
	if dryRunEnabled {
		return &emptypb.Empty{}, nil
	}

	writeOptions := (&nomad.WriteOptions{}).WithContext(ctx)
	res, _, err := h.nomadClient.Jobs().Register(rendered, writeOptions)
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
	longSha := job.GetCommit()
	jobName := job.GetName()

	errParams := map[string]string{
		"job": jobName,
	}

	slog.DebugContext(ctx, "resolved commit", "sha", longSha, "job", jobName)

	jobJSON, err := evalNixJobJSON(ctx, jobName, longSha, errParams)
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

func evalNixJobJSON(ctx context.Context, jobName string, repoSha string, errParams map[string]string) (string, error) {
	tracer := bedrock.GetTracer(ctx)
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
		  builtins.toJSON (builtins.getFlake "github:cottand/selfhosted/%s").legacyPackages.x86_64-linux.nomadJobs.%s
	`, repoSha, jobName)

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
