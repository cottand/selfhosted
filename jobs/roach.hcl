variable "cache" {
  type    = string
  default = "80MB"
}
variable "maxSqlMem" {
  type    = string
  default = "200MB"
}
variable "cpu" {
  type    = number
  default = 200
}
variable "mem" {
  type    = number
  default = 400
}

variable common_name_tls {
  type    = string
  default = "roach.service.nomad"
}

job "roach" {
  datacenters = ["*"]
  update {
    max_parallel = 1
    stagger      = "12s"
  }

  group "miki-roach" {
    count = 1
    constraint {
      attribute = "${meta.box}"
      value     = "miki"
    }
    volume "roach" {
      type      = "host"
      read_only = false
      source    = "roach"
    }
    network {
      mode = "bridge"
      port "db" { host_network = "wg-mesh" }
      port "http" { host_network = "wg-mesh" }
      port "rpc" {
        static       = 26257
        host_network = "wg-mesh"
      }
    }

    service {
      name = "roach-db"
      port = "db"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "roach-http"
      port = "http"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "roach-rpc"
      port = "rpc"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "miki-roach-rpc"
      port = "rpc"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "maco-roach-rpc"
              local_bind_port  = 8001
            }
            upstreams {
              destination_name = "cosmo-roach-rpc"
              local_bind_port  = 8002
            }
          }
        }
      }
    }


    task "roach" {
      volume_mount {
        volume      = "roach"
        destination = "/roach"
        read_only   = false
      }
      driver = "docker"
      config {
        image = "cockroachdb/cockroach:latest-v23.2"
        args = [
          "start",
          "--certs-dir=/secrets",
          "--advertise-addr=${NOMAD_IP_rpc}",
          # peers must match constraint above
          "--join=${NOMAD_UPSTREAM_ADDR_cosmo_roach_rpc},${NOMAD_UPSTREAM_ADDR_maco_roach_rpc}",
          "--listen-addr=0.0.0.0:${NOMAD_PORT_rpc}",
          "--cache=${var.cache}",
          "--max-sql-memory=${var.maxSqlMem}",
          "--insecure",
          "--sql-addr=0.0.0.0:${NOMAD_PORT_db}",
          "--advertise-sql-addr=${NOMAD_IP_db}:${NOMAD_PORT_db}",
          "--http-addr=0.0.0.0:${NOMAD_PORT_http}",
          "--store=/roach",
        ]
      }
      resources {
        cpu        = var.cpu
        memory     = var.mem
        memory_max = var.mem + 100
      }
    }
  }

  group "maco-roach" {
    count = 1
    constraint {
      attribute = "${meta.box}"
      value     = "maco"
    }
    volume "roach" {
      type      = "host"
      read_only = false
      source    = "roach"
    }
    network {
      mode = "bridge"
      port "db" { host_network = "wg-mesh" }
      port "http" { host_network = "wg-mesh" }
      port "rpc" {
        static       = 26257
        host_network = "wg-mesh"
      }
    }

    service {
      name = "roach-db"
      port = "db"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "roach-http"
      port = "http"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "roach-rpc"
      port = "rpc"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "maco-roach-rpc"
      port = "rpc"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "miki-roach-rpc"
              local_bind_port  = 8001
            }
            upstreams {
              destination_name = "cosmo-roach-rpc"
              local_bind_port  = 8002
            }
          }
        }
      }
    }


    task "roach" {
      volume_mount {
        volume      = "roach"
        destination = "/roach"
        read_only   = false
      }
        driver = "docker"
        config {
          image = "cockroachdb/cockroach:latest-v23.2"
          args = [
            "start",
            "--certs-dir=/secrets",
            "--advertise-addr=${NOMAD_IP_rpc}",
            # peers must match constraint above
            "--join=${NOMAD_UPSTREAM_ADDR_cosmo_roach_rpc},${NOMAD_UPSTREAM_ADDR_miki_roach_rpc}",
            "--listen-addr=0.0.0.0:${NOMAD_PORT_rpc}",
            "--cache=${var.cache}",
            "--max-sql-memory=${var.maxSqlMem}",
            "--insecure",
            "--sql-addr=0.0.0.0:${NOMAD_PORT_db}",
            "--advertise-sql-addr=${NOMAD_IP_db}:${NOMAD_PORT_db}",
            "--http-addr=0.0.0.0:${NOMAD_PORT_http}",
          "--store=/roach",
          ]
        }
        resources {
          cpu        = var.cpu
          memory     = var.mem
          memory_max = var.mem + 100
        }
      }
  }

  group "cosmo-roach" {
    count = 1
    constraint {
      attribute = "${meta.box}"
      value     = "cosmo"
    }
    volume "roach" {
      type      = "host"
      read_only = false
      source    = "roach"
    }
    network {
      mode = "bridge"
      port "db" { host_network = "wg-mesh" }
      port "http" { host_network = "wg-mesh" }
      port "rpc" {
        static       = 26257
        host_network = "wg-mesh"
      }
    }

    service {
      name = "roach-db"
      port = "db"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "roach-http"
      port = "http"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "roach-rpc"
      port = "rpc"
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "cosmo-roach-rpc"
      port = "rpc"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "miki-roach-rpc"
              local_bind_port  = 8001
            }
            upstreams {
              destination_name = "maco-roach-rpc"
              local_bind_port  = 8002
            }
          }
        }
      }
    }

    task "roach" {
      volume_mount {
        volume      = "roach"
        destination = "/roach"
        read_only   = false
      }
      driver = "docker"
      config {
        image = "cockroachdb/cockroach:latest-v23.2"
        args = [
          "start",
          "--certs-dir=/secrets",
          "--advertise-addr=${NOMAD_IP_rpc}",
          # peers must match constraint above
          "--join=${NOMAD_UPSTREAM_ADDR_miki_roach_rpc},${NOMAD_UPSTREAM_ADDR_maco_roach_rpc}",
          "--listen-addr=0.0.0.0:${NOMAD_PORT_rpc}",
          "--cache=${var.cache}",
          "--max-sql-memory=${var.maxSqlMem}",
          "--insecure",
          "--sql-addr=0.0.0.0:${NOMAD_PORT_db}",
          "--advertise-sql-addr=${NOMAD_IP_db}:${NOMAD_PORT_db}",
          "--http-addr=0.0.0.0:${NOMAD_PORT_http}",
          "--store=/roach",
        ]
      }
      resources {
        cpu        = var.cpu
        memory     = var.mem
        memory_max = var.mem + 100
      }
    }
  }
}