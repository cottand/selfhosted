package module

import (
	"context"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/cottand/selfhosted/dev-go/lib/objectstore"
	pb "github.com/cottand/selfhosted/dev-go/lib/proto/s-rpc-vault"
	vault "github.com/hashicorp/vault/api"
	"github.com/monzo/terrors"
	"golang.org/x/sync/errgroup"
	"google.golang.org/protobuf/types/known/emptypb"
	"io"
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
	pr, pw := io.Pipe()
	ctx, cancel := context.WithDeadline(ctx, time.Now().Add(1*time.Minute))
	key := fmt.Sprintf("vault/snapshot/%s-%v.snap", time.Now().Format(time.DateOnly), time.Now().UnixMilli())
	wg, wctx := errgroup.WithContext(ctx)
	wg.Go(func() error {
		_, err2 := b2.PutObject(wctx, &s3.PutObjectInput{
			Bucket: aws.String("services-bu"),
			Body:   pr,
			Key:    aws.String(key),
		})
		if err2 != nil {
			return err2
		}
		return nil
	})
	wg.Go(func() error {
		return h.vaultClient.Sys().RaftSnapshotWithContext(wctx, pw)
	})

	err = wg.Wait()
	cancel()
	if err != nil {
		return nil, terrors.Augment(err, "failed to upload snapshot", nil)
	}
	return &emptypb.Empty{}, nil
}
