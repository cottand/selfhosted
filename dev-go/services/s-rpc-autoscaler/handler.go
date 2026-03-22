package module

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"

	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-autoscaler"
	s_rpc_nomad_api "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-nomad-api"
	nomad "github.com/hashicorp/nomad/api"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
)

var _ pb.AutoscalerServer = &ProtoHandler{}

type ProtoHandler struct {
	pb.UnimplementedAutoscalerServer
	nomad s_rpc_nomad_api.NomadApiClient
	db    *sql.DB
}

func NewHandler() (*ProtoHandler, error) {
	db, err := bedrock.OpenDB()
	if err != nil {
		return nil, terrors.Propagate(err)
	}

	conn, err := bedrock.NewGrpcConn()
	if err != nil {
		return nil, terrors.Propagate(err)
	}

	return &ProtoHandler{
		db:    db,
		nomad: s_rpc_nomad_api.NewNomadApiClient(conn),
	}, nil
}

func (h *ProtoHandler) Close() error {
	if err := h.db.Close(); err != nil {
		return terrors.Augment(err, "failed to close DB", nil)
	}
	return nil
}

func (h *ProtoHandler) EvalAllScalingStatus(ctx context.Context, _ *emptypb.Empty) (*pb.EvalAllScalingStatusResponse, error) {
	defs, err := s_rpc_nomad_api.ListJobDefinitions(ctx, &emptypb.Empty{})
	h.nomad.ListJobDefinitions(ctx, &emptypb.Empty{})
	if err != nil {
		return nil, terrors.Augment(err, "failed to list job definitions", nil)
	}

	for {
		next, err := defs.Recv()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, terrors.Augment(err, "failed to receive flight", nil)
		}

		// ignore stopped jobs for now
		if next.GetStopped() {
			continue
		}

		var nomadJob *nomad.Job
		if err := json.Unmarshal(next.JobDefinitionJson, nomadJob); err != nil {
			return nil, terrors.Augment(err, "failed to unmarshal job definition", nil)
		}

		if err = processJob(ctx, nomadJob); err != nil {
			return nil, terrors.Augment(err, "failed to process job", nil)
		}
	}

	return &pb.EvalAllScalingStatusResponse{}, nil
}
