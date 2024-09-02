package nix

import (
	"github.com/farcaller/gonix"
	"github.com/monzo/terrors"
	"path"
)

func EvalJson(expr, evalPath string) (string, error) {
	evalPath = path.Clean(evalPath)
	errParams := map[string]string{"evalPath": evalPath}

	ctx := gonix.NewContext()
	store, err := gonix.NewStore(ctx, "dummy", nil)
	if err != nil {
		return "", terrors.Augment(err, "failed to create a store", errParams)
	}
	state := store.NewState(nil)

	val, err := state.EvalExpr("builtins.toJSON ("+expr+")", evalPath)
	if err != nil {
		return "", terrors.Augment(err, "failed to eval expression", errParams)
	}

	strVal, err := val.GetString()
	if err != nil {
		return "", terrors.Augment(err, "failed to convert evaluated to string", errParams)
	}

	return strVal, nil
}
