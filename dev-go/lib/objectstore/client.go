package objectstore

//import "github.com/aws/aws-sdk-go-v2/config"
import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/cottand/selfhosted/dev-go/lib/secretstore"
	"github.com/monzo/terrors"
)

// TODO fetch creds via vault client at "secret/data/services/db-rw-default"

func credentialsProvider() aws.CredentialsProvider {
	f := aws.CredentialsProviderFunc(func(ctx context.Context) (creds aws.Credentials, err error) {
		credsPath := "services/db-rw-default"
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

func B2Client(ctx context.Context) (*s3.Client, error) {
	config := aws.Config{
		BaseEndpoint: aws.String("https://s3.us-east-005.backblazeb2.com"),
		Credentials:  credentialsProvider(),
	}
	client := s3.NewFromConfig(config)
	return client, nil
}
