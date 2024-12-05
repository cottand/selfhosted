package objectstore

//import "github.com/aws/aws-sdk-go-v2/config"
import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log/slog"
	"net/http"
)

// TODO fetch creds via vault client at "secret/data/services/db-rw-default"

func credentialsProvider() aws.CredentialsProvider {
	f := aws.CredentialsProviderFunc(func(ctx context.Context) (creds aws.Credentials, err error) {
		defer func() {
			if err != nil {
				slog.Error("Error getting AWS credentials", "err", err.Error())
			}
		}()
		credsPath := "services/s-rpc-vault/b2-services-bu"
		errParams := map[string]string{"secretPath": credsPath}
		secret, err := secretstore.GetString(ctx, credsPath)
		if err != nil {
			return creds, terrors.Augment(err, "could not load B2 credentials", errParams)
		}
		keyId, keyOk := secret["keyId"]
		secretKey, secretOk := secret["secretKey"]

		if !keyOk || !secretOk {
			return creds, terrors.NotFound("", "could not find B2 credentials", errParams)
		}
		creds.AccessKeyID = keyId
		creds.SecretAccessKey = secretKey
		return creds, err
	})
	return aws.NewCredentialsCache(f)
}

func B2Client() (*s3.Client, error) {
	config := aws.Config{
		BaseEndpoint: aws.String("https://s3.us-east-005.backblazeb2.com"),
		Region:       "us-east-005",
		Credentials:  credentialsProvider(),
		HTTPClient:   &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)},
	}
	client := s3.NewFromConfig(config)
	return client, nil
}
