package main

import (
	"github.com/cottand/selfhosted/services/lib/mono"
	a1 "github.com/cottand/selfhosted/services/s-rpc-portfolio-stats"
	a2 "github.com/cottand/selfhosted/services/s-web-portfolio"
)

func main() {
	a1.InitService()
	a2.InitService()
	mono.RunRegistered()
}