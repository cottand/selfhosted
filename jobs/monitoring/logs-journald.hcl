job "logs" {
  datacenters = ["dc1"]
  # system job, runs on all nodes
  type     = "system"
  priority = 1
  update {
    min_healthy_time  = "10s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }
  group "vector" {
    count = 1
    restart {
      attempts = 3
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }
    network {
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
      }
    }
    # docker socket volume
    volume "docker-sock" {
      type      = "host"
      source    = "docker-sock-ro"
      read_only = true
    }
    volume "journald" {
      type      = "host"
      source    = "journald-ro"
      read_only = true
    }
    volume "machineid" {
      type      = "host"
      source    = "machineid-ro"
      read_only = true
    }
    ephemeral_disk {
      size   = 500
      sticky = true
    }
    task "vector" {
      driver = "docker"
      config {
        image = "timberio/vector:0.31.0-debian"
        ports = ["http"]
      }
      # docker socket volume mount
      volume_mount {
        volume      = "docker-sock"
        destination = "/var/run/docker.sock"
        read_only   = true
      }
      volume_mount {
        volume      = "journald"
        destination = "/var/log/journal"
        read_only   = true
      }
      volume_mount {
        volume      = "machineid"
        destination = "/etc/machine-id"
        read_only   = true
      }
      # Vector won't start unless the sinks(backends) configured are healthy
      env {
        VECTOR_CONFIG          = "local/vector.toml"
        VECTOR_REQUIRE_HEALTHY = "true"
      }
      # resource limits are a good idea because you don't want your log collection to consume all resources available
      resources {
        cpu    = 200
        memory = 256
        # Update the Scheduler Configuration to allow oversubscription.
        memory_max = 1024
      }
      # template with Vector's configuration
      template {
        destination = "local/vector.toml"
        change_mode = "restart"
        # overriding the delimiters to [[ ]] to avoid conflicts with Vector's native templating, which also uses {{ }}
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<EOH
        data_dir = "alloc/data/"
          [api]
            enabled = true
            address = "0.0.0.0:[[ env "NOMAD_PORT_http" ]]"
            playground = true
          [sources.logs]
            type = "docker_logs"
          [sources.host_journald_logs]
            type = "journald"
            current_boot_only = true
            since_now = true
            include_units = [ "nomad", "wg-quick-wg0" ]
#             Warning and above
             include_matches.PRIORITY = [ "0", "1", "2", "3", "4" ]

#          [sinks.out]
#            type = "console"
#            inputs = [ "logs" ]
#            encoding.codec = "json"
          [sinks.loki]
            type = "loki"
            inputs = ["logs", "host_journald_logs"]
            endpoint = "http://[[ range nomadService "loki" ]][[ .Address ]]:[[ .Port ]][[ end ]]"
            encoding.codec = "json"
            healthcheck.enabled = true
            # since . is used by Vector to denote a parent-child relationship, and Nomad's Docker labels contain ".",
            # we need to escape them twice, once for TOML, once for Vector
            labels.task  = "{{ label.\"com.hashicorp.nomad.task_name\" }}"
            labels.job   = "{{ label.\"com.hashicorp.nomad.job_name\" }}"
            labels.alloc = "{{ label.\"com.hashicorp.nomad.alloc_id\" }}"
            labels.node  = "{{ label.\"com.hashicorp.nomad.node_name\" }}"
#            labels.group = "{{ label.com\\.hashicorp\\.nomad\\.task_group_name }}"
#            labels.namespace = "{{ label.com\\.hashicorp\\.nomad\\.namespace }}"
            # remove fields that have been converted to labels to avoid having the field twice
            remove_label_fields = true
        EOH
      }
      #            service {
      #                name = "vector"
      #                provider = "nomad"
      #                check {
      #                    port     = "http"
      #                    type     = "http"
      #                    path     = "/health"
      #                    interval = "30s"
      #                    timeout  = "5s"
      #                }
      #            }
      #            kill_timeout = "30s"
    }
  }
}