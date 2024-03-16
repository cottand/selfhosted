variable "size" {
  type    = number
  default = 512
}

// var "alt_names" {
  // type = string
  // default = ""
// }

variable common_name_tls {
  type = string
  default = "roach.service.nomad"
}

job "roach" {
  datacenters = ["*"]
  update {
    max_parallel = 1
    stagger      = "12s"
  }
  group "roach" {
connect {
  enabled = true
}
    constraint {
      distinct_hosts = true
    }
    count = 1
    constraint {
      attribute = "${meta.box}"
      operator  = "regexp"
      # We need static IPs for master servers
      value = "^miki|cosmo|maco$"
    }

    // TODO HOST VOL

    network {
      port "db" {
        // static       = 26257
        host_network = "wg-mesh"
      }
      port "http" {
        to           = 8080
        host_network = "wg-mesh"
      }
      port "rpc" {
        static       = 26257
        host_network = "wg-mesh"
      }
    }

    task "roach" {
      vault {
        role = "workload-cert-issuer"
      }
      driver = "docker"
      config {
        image = "cockroachdb/cockroach:latest-v23.1"
        args = [
          "start",
          "--certs-dir=/secrets",
          "--advertise-addr=${NOMAD_IP_rpc}",
          // "--join=<node1 address>,<node2 address>,<node3 address>",
          # peers must match constraint above
          "--join=10.10.4.1:${NOMAD_PORT_rpc},10.10.2.1:${NOMAD_PORT_rpc},10.10.0.1:${NOMAD_PORT_rpc}",
          "--listen=0.0.0.0:${NOMAD_PORT_rpc}",
          "--cache=.25",
          "--max-sql-memory=.75",
          // "--cert-principal-map=${var.common_name_tls}:node",
          "--insecure",
          "--sql-addr=${NOMAD_PORT_db}"
        ]
      }
      service {
        name     = "roach-db"
        port     = "db"
      }
      service {
        name     = "roach-http"
        port     = "http"
      }


      resources {
        cpu        = 200
        memory     = 400
        memory_max = 400
      }
    }
  }
}