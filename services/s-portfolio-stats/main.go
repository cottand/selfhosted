package main

import (
	"context"
	"github.com/cottand/selfhosted/services/lib/bedrock"
	"github.com/monzo/terrors"
	"log"
	"net/http"
)

func main() {
	ctx := context.Background()
	shutdown := bedrock.Init(ctx)

	defer shutdown(ctx)

	conf, err := bedrock.GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	err = http.ListenAndServe(conf.HttpBind(), nil)
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to start server", nil).Error())
	}
}
