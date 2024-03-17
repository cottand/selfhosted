job "debug" {
  group "debug" {
    network {
      mode = "bridge"
    }
      service {
        name     = "debug"
        port = "80"
        connect {
          sidecar_service {
            proxy {
              upstreams {
                destination_name = "web-portfolio-c"
                local_bind_port  = 8001
              }
              upstreams {
                destination_name = "whoami"
                local_bind_port  = 8002
              }
            }
          }
        }
      }
    task "whoami" {
      driver = "docker"

      config {
        image = "nixos/nix"
        command = "bash"
        ports = ["http"]
        args = [
          "-c",
           "sleep 1000000",
          // "--port=${NOMAD_PORT_http}",
        ]
      }

    }
  }
}