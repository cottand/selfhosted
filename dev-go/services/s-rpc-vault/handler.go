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
	slog.Info("vault snapshot uploaded successfully")
	return &emptypb.Empty{}, terrors.Augment(err, "failed to upload snapshot", nil)
}
