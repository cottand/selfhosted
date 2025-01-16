package bigq

import (
	"cloud.google.com/go/bigquery"
	"context"
	"github.com/cottand/selfhosted/dev-go/lib/bedrock"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"golang.org/x/oauth2"
	"google.golang.org/api/option"
	"time"
)

type vaultOAuthTokenSource struct {
	renew  func() (*secretstore.GCPToken, error)
	latest *secretstore.GCPToken
}

func (s *vaultOAuthTokenSource) Token() (*oauth2.Token, error) {
	if s.latest == nil || s.latest.ExpiresAt.Before(time.Now()) {
		renewed, err := s.renew()
		if err != nil {
			return nil, err
		}
		s.latest = renewed
	}

	a := bedrock.Result[string, string]{}
	return &oauth2.Token{
		AccessToken: s.latest.Token,
		Expiry:      s.latest.ExpiresAt,
	}, nil
}

func NewClient(ctx context.Context, roleset string) (*bigquery.Client, error) {
	ctx = context.WithoutCancel(ctx)
	tSrc := &vaultOAuthTokenSource{
		renew: func() (*secretstore.GCPToken, error) {
			return secretstore.ExchangeGCPToken(ctx, roleset)
		},
	}
	client, err := bigquery.NewClient(ctx, "dcotta-com", option.WithTokenSource(tSrc))
	if err != nil {
		return nil, err
	}
	return client, nil
}
