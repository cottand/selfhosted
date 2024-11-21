package bigq

import (
	"cloud.google.com/go/bigquery"
	"context"
)

func NewClient(ctx context.Context) (*bigquery.Client, error) {
	client, err := bigquery.NewClient(ctx, "dcotta.com")
	if err != nil {
		return nil, err
	}
	return client, nil
}
