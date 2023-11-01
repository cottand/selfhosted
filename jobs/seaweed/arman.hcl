
variable "seaweedfs_version" {
  type    = string
  default = "3.58"
}


job "seaweedfs-arman" {
  group "seaweedfs-arman" {
    restart {
      interval = "10m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    ephemeral_disk {
      size    = 1024 # MB
      migrate = true
      sticky  = true
    }

    network {
      mode = "bridge"
      dns {
        servers = [
          "10.10.0.1",
          "10.10.2.1",
          "10.10.1.1",
          "10.10.4.1",
        ]
      }

      port "webdav" {
        host_network = "wg-mesh"
      }
    }

    task "seaweedfs-webdav-arman" {
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:${var.seaweedfs_version}"
        ports = ["webdav"]
        args = [
          "-logtostderr",
          "-v=3",
          "webdav",
          "-collection=arman",
          "-replication=010",
          "-port=${NOMAD_PORT_webdav}",
          "-filer=seaweedfs-filer-http.nomad:8888.18888",
          "-filer.path=/buckets/arman",
          "-cacheDir=/alloc/data/",
          "-cacheCapacityMB=1024",
        ]
      }
      service {
        name     = "seaweedfs-webdav-arman"
        port     = "webdav"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "webdav"
          interval = "20s"
          timeout  = "2s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web,websecure,web_public,websecure_public",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
    }
  }
}