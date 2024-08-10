package main

import (
	"github.com/monzo/terrors"
	"log/slog"
	"net/http"
)
import "github.com/cottand/selfhosted/services/lib/bedrock"

func main() {
	bedrock.Init()
	conf, err := bedrock.GetBaseConfig()
	if err != nil {
		slog.Error(err.Error())
		panic(err)
	}

	err = http.ListenAndServe(conf.HttpBind(), nil)
	if err != nil {
		slog.Error(terrors.Augment(err, "failed to start server", nil).Error())
		panic(err)
	}
}
