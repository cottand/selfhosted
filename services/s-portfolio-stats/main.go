package main

import (
	"context"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	"net/http"
)

func main() {
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)

	defer shutdown(ctx)

	mux := http.NewServeMux()
	bedrock.Serve(ctx, mux)
}
