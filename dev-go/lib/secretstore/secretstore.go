package secretstore

import (
	"context"
	vault "github.com/hashicorp/vault/api"
	"github.com/monzo/terrors"
	"strconv"
	"time"
)

func Get(ctx context.Context, path string) (map[string]any, error) {
	config := vault.DefaultConfig()
	v, err := vault.NewClient(config)
	if err != nil {
		return nil, terrors.Augment(err, "failed to start vault client", nil)
	}

	secret, err := v.KVv2("secret").Get(ctx, path)
	if err != nil {
		return nil, terrors.Augment(err, "failed to get secret from vault", nil)
	}
	return secret.Data, nil
}

func GetString(ctx context.Context, path string) (map[string]string, error) {
	underlying, err := Get(ctx, path)
	second := make(map[string]string, len(underlying))
	if err != nil {
		return nil, err
	}

	for key, value := range underlying {
		if asStr, ok := value.(string); ok {
			second[key] = asStr
		} else {
			return nil, terrors.New(terrors.ErrPreconditionFailed, "unexpected non string value in secret", map[string]string{"path": path})
		}
	}
	return second, nil
}

type GCPToken struct {
	Token     string
	ExpiresAt time.Time
}

func ExchangeGCPToken(ctx context.Context, roleset string) (*GCPToken, error) {
	config := vault.DefaultConfig()
	v, err := vault.NewClient(config)
	if err != nil {
		return nil, terrors.Augment(err, "failed to start vault client", nil)
	}

	req, err := v.Logical().ReadWithContext(ctx, "gcp/roleset/"+roleset+"/token")
	if err != nil {
		return nil, terrors.Augment(err, "failed to get token from vault", nil)
	}
	expiresAtS, expiresAtok := req.Data["expires_at_seconds"].(string)
	token, tokenOk := req.Data["token"].(string)

	if !expiresAtok || !tokenOk {
		return nil, terrors.New(terrors.ErrPreconditionFailed, "failed to get token from vault (could not parse response)", nil)
	}

	expiresAtParsed, err := strconv.ParseInt(expiresAtS, 10, 64)
	if err != nil {
		return nil, terrors.Augment(err, "failed to parse token from vault", map[string]string{"expiresAt": expiresAtS})
	}
	return &GCPToken{
		Token:     token,
		ExpiresAt: time.Unix(expiresAtParsed, 0),
	}, nil
}
