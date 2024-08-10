package main

import (
	"github.com/monzo/terrors"
	"log"
	"net/http"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

func main() {
	bedrock.Init()
	conf, err := bedrock.GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	root, err := bedrock.LocalNixDir()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	fs := http.FileServer(http.Dir(root + "/srv"))
	http.Handle("/", fs)

	err = http.ListenAndServe(conf.HttpBind(), nil)
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to start server", nil).Error())
	}
}
