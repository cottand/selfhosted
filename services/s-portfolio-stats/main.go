package main

import "time"
import "github.com/cottand/selfhosted/services/lib/bedrock"

func main() {
	bedrock.Init()
	for {
		time.Sleep(3 * time.Second)
		println("hello world from service!")
	}
}
