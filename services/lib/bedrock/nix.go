package bedrock

import (
	"github.com/monzo/terrors"
	"os"
	"path"
)

var assetsNixDir = ""

// AssetsNixDir returns the assets folder added by Nix at runtime.
//
// When running outside of Nix, this simply returns the dir the binary
// is in.
func AssetsNixDir() (string, error) {
	if assetsNixDir != "" {
		return assetsNixDir, nil
	}

	e, err := os.Executable()
	if err != nil {
		return "", terrors.Propagate(err)
	}
	return path.Dir(e), nil
}
