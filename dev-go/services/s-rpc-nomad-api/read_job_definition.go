package module

import (
	"context"
	"encoding/json"

	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
)

func (h *ProtoHandler) ReadJobDefinition(ctx context.Context, job *pb.ReadJobDefinitionRequest) (*pb.ReadJobDefinitionResponse, error) {
	opts := (&nomad.QueryOptions{}).WithContext(ctx)
	jobInfo, _, err := h.nomadClient.Jobs().Info(job.JobId, opts)
	if err != nil {
		return nil, terrors.Augment(err, "failed to get latest jobInfo", nil)
	}
	asJson, err := json.Marshal(jobInfo)
	if err != nil {
		return nil, terrors.Augment(err, "failed to marshal jobInfo", nil)
	}
	return &pb.ReadJobDefinitionResponse{
		JobDefinitionJson: asJson,
	}, nil
}

func (h *ProtoHandler) ListJobDefinitions(_ *emptypb.Empty, stream grpc.ServerStreamingServer[pb.ListJobsResponse]) error {
	opts := (&nomad.QueryOptions{}).WithContext(stream.Context())
	listRsp, _, err := h.nomadClient.Jobs().List(opts)
	if err != nil {
		return terrors.Augment(err, "failed to list jobs", nil)
	}
	for _, job := range listRsp {
		errParams := map[string]string{"jobName": job.Name}

		info, _, err := h.nomadClient.Jobs().Info(job.Name, opts)
		if err != nil {
			return terrors.Augment(err, "failed to get job info", errParams)
		}

		asJson, err := json.Marshal(info)

		err = stream.Send(&pb.ListJobsResponse{
			JobDefinitionJson: asJson,
			Stopped:           job.Stop,
		})
		if err != nil {
			return terrors.Augment(err, "failed to send job info", errParams)
		}
	}
	return nil
}
