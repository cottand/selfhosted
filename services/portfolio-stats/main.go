package main

import "time"

func main() {
	for {
		time.Sleep(3 * time.Second)
		println("hello world from service!")
	}
}
