// Runs s-web-upload-slotcars on its own, without bedrock, for the `gsx dev` loop.
package main

import (
	"log"
	"log/slog"

	s_web_upload_slotcars "github.com/cottand/selfhosted/dev-go/services/s-web-upload-slotcars"
)

func main() {
	_, name, err := s_web_upload_slotcars.InitService()
	if err != nil {
		log.Fatalln(err)
	}
	slog.Info("serving", "service", name, "url", "http://localhost:7005")
	select {}
}
