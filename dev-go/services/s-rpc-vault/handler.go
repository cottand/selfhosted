package module

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/cottand/selfhosted/dev-go/lib/objectstore"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	vault "github.com/hashicorp/vault/api"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"io"
)

type ProtoHandler struct {
	pb.UnimplementedVaultApiServer
	vaultClient *vault.Client
}

func (h *ProtoHandler) Snapshot(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	// find the leader
	status, err := h.vaultClient.Sys().HAStatus()
	if err != nil {
		return nil, terrors.Augment(err, "failed to call vault status", nil)
	}
	var leader *vault.HANode
	for _, node := range status.Nodes {
		if node.ActiveNode {
			leader = &node
		}
	}
	if leader == nil {
		return nil, terrors.PreconditionFailed("no_leader", "failed to find a vault leader", nil)
	}
	err = h.vaultClient.SetAddress(leader.APIAddress)
	if err != nil {
		return nil, terrors.Augment(err, "failed to set vault address", nil)
	}
	
	b2, err := objectstore.B2Client(ctx)
	if err != nil {
		return nil, err
	}
	pr, pw := io.Pipe()
	defer pw.Close()
	errChan := make(chan error)
	go func() {
		_, err2 := b2.PutObject(ctx, &s3.PutObjectInput{Body: pr})
		if err2 != nil {
			errChan <- err
		}
	}()
	err = h.vaultClient.Sys().RaftSnapshotWithContext(ctx, pw)

	select {
	case e := <-errChan:
		return nil, terrors.Augment(e, "failed to upload snapshot", nil)
	default:
	}
	if err != nil {
		return &emptypb.Empty{}, terrors.Augment(err, "failed to upload snapshot", nil)
	}
	slog.Info("vault snapshot uploaded successfully")
	return &emptypb.Empty{}, nil
}
