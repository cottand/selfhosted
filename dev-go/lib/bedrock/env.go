package bedrock

import (
	"bytes"
	"github.com/monzo/terrors"
	"os"
	"strings"
)

func GetRootCa() (string, error) {
	f, err := os.Open("/local/root_ca.crt")
	if err != nil {
		return "", terrors.Augment(err, "failed to open root ca file", nil)
	}
	bs := bytes.NewBufferString("")
	_, err = bs.ReadFrom(f)
	if err != nil {
		return "", terrors.Augment(err, "failed to read root ca file", nil)
	}
	return strings.TrimSpace(bs.String()), nil
}
