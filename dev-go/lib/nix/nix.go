package nix

import (
	"github.com/farcaller/gonix"
	"github.com/monzo/terrors"
	"path"
)

func Eval(expr, evalPath, nixStore string) (*gonix.Value, error) {
	evalPath = path.Clean(evalPath)
	errParams := map[string]string{"evalPath": evalPath}

	ctx := gonix.NewContext()
	store, err := gonix.NewStore(ctx, nixStore, nil)
	if err != nil {
		return nil, terrors.Augment(err, "failed to create a store", errParams)
	}
	state := store.NewState(nil)

	val, err := state.EvalExpr(expr, evalPath)
	if err != nil {
		return nil, terrors.Augment(err, "failed to eval expression", errParams)
	}
	return val, nil
}

func EvalJson(expr, evalPath, nixStore string) (string, error) {
	withJson := "builtins.toJSON ( " + expr + " )"
	val, err := Eval(withJson, evalPath, nixStore)
	if err != nil {
		return "", terrors.Propagate(err)
	}

	strVal, err := val.GetString()
	if err != nil {
		return "", terrors.Augment(err, "failed to convert evaluated JSON to string", nil)
	}

	return strVal, nil
}
