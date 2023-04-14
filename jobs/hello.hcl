job "hello" {
  datacenters = ["dc1"]

  group "example" {
    network {
      port "http" {
        to = "5678"
#        static = "5678"
        host_network = "vpn"
      }

    }
    task "server" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        ports = ["http"]
        args = [
          "-listen",
          ":5678",
          "-text",
          "hello world!!",
        ]
      }
    }
  }
}