// Runs s-web-home on its own, without bedrock, for the `gsx dev` loop.
// Calls to other services will fail.
package main

import (
	"log"
	"log/slog"

	s_web_home "github.com/cottand/selfhosted/dev-go/services/s-web-home"
)

func main() {
	_, name, err := s_web_home.InitService()
	if err != nil {
		log.Fatalln(err)
	}
	slog.Info("serving", "service", name, "url", "http://localhost:7004")
	select {}
}
