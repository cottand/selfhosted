package main

import (
	"context"
	"github.com/monzo/terrors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"log"
	"net/http"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

func main() {
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)
	defer shutdown(ctx)

	root, err := bedrock.NixAssetsDir()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	mux := http.NewServeMux()

	fs := http.FileServer(http.Dir(root + "/srv"))

	mux.Handle("/static/", otelhttp.WithRouteTag("/static/", fs))
	mux.Handle("/", otelhttp.WithRouteTag("/", http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		req.URL.Path = "/"
		fs.ServeHTTP(rw, req)
	})))

	bedrock.Serve(ctx, mux)
}
