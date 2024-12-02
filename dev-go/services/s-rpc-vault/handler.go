package module

import (
	"bytes"
	"context"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/cottand/selfhosted/dev-go/lib/objectstore"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	vault "github.com/hashicorp/vault/api"
	"github.com/monzo/terrors"
	"google.golang.org/protobuf/types/known/emptypb"
	"time"
)

type ProtoHandler struct {
	pb.UnimplementedVaultApiServer
	vaultClient *vault.Client
}

func (h *ProtoHandler) Snapshot(ctx context.Context, _ *emptypb.Empty) (*emptypb.Empty, error) {
	// find the leader
	status, err := h.vaultClient.Sys().HAStatus()
	//h.vaultClient.SetClientTimeout(5 * time.Minute) // TODO config
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

	b2, err := objectstore.B2Client()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithDeadline(ctx, time.Now().Add(1*time.Minute))
	defer cancel()
	key := fmt.Sprintf("vault/snapshot/%s-%v.snap", time.Now().Format(time.DateOnly), time.Now().UnixMilli())
	buffer := bytes.NewBuffer(nil)
	err = h.vaultClient.Sys().RaftSnapshotWithContext(ctx, buffer)
	if err != nil {
		return nil, terrors.Augment(err, "failed to snapshot raft snapshot", nil)
	}
	cLength := int64(buffer.Len())
	_, err = b2.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String("services-bu"),
		Body:          buffer,
		ContentLength: &cLength,
		Key:           aws.String(key),
	})
	if err != nil {
		return nil, terrors.Augment(err, "failed to upload snapshot", nil)
	}
	return &emptypb.Empty{}, nil
}
