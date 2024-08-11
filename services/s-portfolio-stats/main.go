package main

import (
	"github.com/cottand/selfhosted/services/lib/bedrock"
	proto "github.com/cottand/selfhosted/services/lib/proto/s-portfolio-stats"
	"github.com/monzo/terrors"
	"log"
	"net/http"
)

func main() {
	bedrock.Init()
	conf, err := bedrock.GetBaseConfig()
	if err != nil {
		log.Fatalf(terrors.Propagate(err).Error())
	}

	_ = proto.AddressBook{People: nil}

	err = http.ListenAndServe(conf.HttpBind(), nil)
	if err != nil {
		log.Fatalf(terrors.Augment(err, "failed to start server", nil).Error())
	}
}
