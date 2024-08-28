package main

import "github.com/cottand/selfhosted/services/mono"
import a1 "github.com/cottand/selfhosted/services/s-rpc-portfolio-stats"
import a2 "github.com/cottand/selfhosted/services/s-web-portfolio"

func main() {
	a1.InitService()
	a2.InitService()
	mono.RunRegistered()
}
