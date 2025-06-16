package bedrock

import "context"

var contextModuleNameKey =  "_context_module_name_key__023eqhfnv90"

func CtxWithModuleName(ctx context.Context, name string) context.Context  {
	return context.WithValue(ctx, contextModuleNameKey, name)
}

func GetModuleName(ctx context.Context) (string, bool)  {
	name, ok := ctx.Value(contextModuleNameKey).(string)
	return name, ok
}

