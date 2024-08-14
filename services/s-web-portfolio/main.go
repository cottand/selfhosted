package main

import (
	"context"
	"github.com/monzo/terrors"
	"log"
	"net/http"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

func main() {
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)
	defer shutdown(ctx)

	conf, err := bedrock.GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	root, err := bedrock.NixAssetsDir()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	fs := http.FileServer(http.Dir(root + "/srv"))
	http.Handle("/static/", fs)
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		request.URL.Path = "/"
		fs.ServeHTTP(writer, request)
	})

	err = http.ListenAndServe(conf.HttpBind(), nil)
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to start server", nil).Error())
	}
}
