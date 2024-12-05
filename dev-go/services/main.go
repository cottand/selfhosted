package main

import (
	"github.com/cottand/selfhosted/dev-go/lib/mono"
	a3 "github.com/cottand/selfhosted/dev-go/services/s-rpc-nomad-api"
	a1 "github.com/cottand/selfhosted/dev-go/services/s-rpc-portfolio-stats"
	a2 "github.com/cottand/selfhosted/dev-go/services/s-web-github-webhook"
	a4 "github.com/cottand/selfhosted/dev-go/services/s-web-portfolio"
)

func main() {
	a1.InitService()
	a2.InitService()
	a3.InitService()
	a4.InitService()
	mono.RunRegistered()
}
