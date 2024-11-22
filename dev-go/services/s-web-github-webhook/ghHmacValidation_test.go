package module

import (
	"context"
	"github.com/monzo/terrors"
	"testing"
)

// TestValidateGhHmac is a Go version of https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries#testing-the-webhook-payload-validation
func TestValidateGhHmac(t *testing.T) {
	nerr := terrors.BadRequest("aa", "asdasd", map[string]string{"this": "param"})

	slog.Info("some message", "err", nerr)

	payload := []byte("Hello, World!")
	secret := "It's a Secret to Everybody"
	digestGh256 := "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"
	err := validateWebhookHmac(context.Background(), payload, secret, digestGh256)
	if err != nil {
		t.Errorf("error validating webhook hmac: %v", err)
	}
}
