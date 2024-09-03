package module

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	"github.com/farcaller/gonix"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
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
	logger.Info("successfully registered nomad job", "jobEvalId", res.EvalID, "jobName", rendered.Name)

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
	shaToDeploy := job.GetCommit()
	shortSha := shaToDeploy[:7]

	errParams := map[string]string{
		"file":     jobPath,
		"shortSha": shortSha,
	}

	logger.Info("resolved commit", "sha", shaToDeploy, "shortSha", shortSha)

	f, err := downloadJobFileFor(ctx, jobPath, shortSha)

	if err != nil {
		return nil, terrors.Augment(err, "failed to download job file", errParams)
	}

	jobJSON, err := evalNixJobJSON(ctx, *f, shortSha, errParams)
	if err != nil {
		return nil, terrors.Augment(err, "failed to evaluate job file", errParams)
	}

	parsed := &nomad.Job{}
	err = json.Unmarshal([]byte(jobJSON), parsed)
	if err != nil {
		return nil, terrors.Augment(err, "failed to decode job json", errParams)
	}
}

func downloadJobFileFor(ctx context.Context, jobPath string, commitSha string) (*string, error) {
	jobPath = path.Clean(jobPath)
	get, err := otelhttp.Get(ctx, "https://github.com/Cottand/selfhosted/raw/"+commitSha+"/"+jobPath)
	if err != nil {
		return nil, terrors.Augment(err, "failed to fetch job from GitHub", nil)
	}
	bs := new(bytes.Buffer)
	_, err = bs.ReadFrom(get.Body)
	if err != nil {
		return nil, terrors.Augment(err, "failed to read job file into memory", nil)
	}
	str := bs.String()
	return &str, nil
}

func evalNixJobJSON(ctx context.Context, jobNixStr string, version string, errParams map[string]string) (string, error) {
	ctx, span := tracer.Start(ctx, "evalNixJobJSON")
	defer span.End()

	nixCtx := gonix.NewContext()

	store, err := gonix.NewStore(nixCtx, "/nix/store", errParams)
	if err != nil {
		return "", terrors.Augment(err, "failed to create a store", errParams)
	}
	state := store.NewState(nil)
	jobVal, err := state.EvalExpr(fmt.Sprintf(`builtins.toJSON(( %s ) { version = "%s"; })`, jobNixStr, version), "/")
	if err != nil {
		return "", terrors.Augment(err, "failed to eval job expression", errParams)
	}

	jobJson, err := jobVal.GetString()
	if err != nil {
		return "", terrors.Augment(err, "failed to resolve job json to string", errParams)
	}

	return jobJson, nil

}
