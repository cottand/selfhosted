package secretstore

import (
	"context"
	"crypto/tls"
	"encoding/json"
	vault "github.com/hashicorp/vault/api"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"golang.org/x/net/http2"
	"log/slog"
	"net/http"
	"reflect"
	"strconv"
	"time"
)

func NewClient() (*vault.Client, error) {
	vaultConfig := vault.DefaultConfig()
	vaultConfig.Address = "https://vault.dcotta.com:8200"
	vaultConfig.DisableRedirects = false
	transport := http.Transport{
		TLSClientConfig: &tls.Config{
			ServerName: "vault.dcotta.com",
		},
	}
	err := http2.ConfigureTransport(&transport)
	vaultConfig.HttpClient = &http.Client{
		Transport: otelhttp.NewTransport(&transport),
	}
	if err != nil {
		return nil, terrors.Augment(err, "failed to init vault client", nil)
	}
	vaultClient, err := vault.NewClient(vaultConfig)
	if err != nil {
		return nil, terrors.Augment(err, "failed to init vault client", nil)
	}
	return vaultClient, nil
}

func Get(ctx context.Context, path string) (map[string]any, error) {
	v, err := NewClient()
	if err != nil {
		return nil, err
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
	v, err := NewClient()
	if err != nil {
		return nil, terrors.Augment(err, "failed to start vault client", nil)
	}

	req, err := v.Logical().ReadWithContext(ctx, "gcp/roleset/"+roleset+"/token")
	if err != nil {
		return nil, terrors.Augment(err, "failed to get token from vault", nil)
	}
	mapExpiresAt := req.Data["expires_at_seconds"]
	expiresAtS, expiresAtok := mapExpiresAt.(json.Number)
	mapToken := req.Data["token"]
	token, tokenOk := mapToken.(string)

	if !expiresAtok || !tokenOk {
		expireType := reflect.TypeOf(mapExpiresAt)
		tokenType := reflect.TypeOf(mapToken)
		slog.Error("failed to get token from vault (could not parse response)", "token_type", tokenType.String(), "expires_at_type", expireType.String(), "expiresAt", expiresAtS)
		return nil, terrors.New(terrors.ErrPreconditionFailed, "failed to get token from vault (could not parse response)", map[string]string{
			"token_type":      tokenType.String(),
			"expires_at_type": expireType.String(),
			"expiresAt":       string(expiresAtS),
		})
	}

	expiresAtParsed, err := strconv.ParseInt(expiresAtS.String(), 10, 64)
	if err != nil {
		return nil, terrors.Augment(err, "failed to parse token from vault", map[string]string{"expiresAt": string(expiresAtS)})
	}
	return &GCPToken{
		Token:     string(token),
		ExpiresAt: time.Unix(expiresAtParsed, 0),
	}, nil
}
