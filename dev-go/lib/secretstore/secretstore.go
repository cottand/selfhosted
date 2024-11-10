package secretstore

import (
	"context"
	vault "github.com/hashicorp/vault/api"
	"github.com/monzo/terrors"
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
