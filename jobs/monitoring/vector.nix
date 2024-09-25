let
  lib = (import ../lib) { };
  version = "0.32.X-debian";
  cpu = 120;
  mem = 200;
  ports = {
    http = 8080;
    upLoki = 9002;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
  journalPath = "/var/log/journal";

in
lib.mkJob "vector" {

  type = "system";
  nodePool = "all";

  group."vector" = {
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        {
          label = "health";
          hostNetwork = "ts";
        }
      ];
    };
    volumes."docker-sock" = {
      type = "host";
      source = "docker-sock-ro";
      readOnly = true;
    };
    volumes."journald-ro" = {
      type = "host";
      source = "journald-ro";
      readOnly = true;
    };
    ephemeralDisk = {
      size = 500;
      sticky = true;
    };

    service."vector" = {
      port = ports.http;
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."loki-http".localBindPort = ports.upLoki;
          #          upstream."seaweed-filer-s3".localBindPort = ports.upS3;

          config = lib.mkEnvoyProxyConfig {
            otlpUpstreamPort = otlpPort;
            otlpService = "vector-proxy";
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      # TODO implement http healthcheck
      #      port = toString ports.http;
      #      check = {
      #        name = "alive";
      #        type = "tcp";
      #        port = "http";
      #        interval = "20s";
      #        timeout = "2s";
      #      };
    };
    task."vector" = {
      driver = "docker";
      vault = { };

      config = {
        image = "timberio/vector:${version}";
      };
      volumeMounts = [
        {
          volume = "docker-sock";
          destination = "/var/run/docker.sock";
          readOnly = true;
        }
        {
          volume = "journald-ro";
          destination = journalPath;
          readOnly = true;
        }
      ];
      # Vector won't start unless the sinks(backends) configured are healthy
      env = {
        VECTOR_CONFIG = "/local/vector.toml";
        VECTOR_REQUIRE_HEALTHY = "true";
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      template."local/vector.toml" = {
        changeMode = "restart";
        leftDelim = "[[";
        rightDelim = "]]";
        embeddedTmpl = ''
          data_dir = "/alloc/data/"
          [api]
            enabled = true
            address = "${bind}:${toString ports.http}"
            playground = true
          [sources.journald]
            type = "journald"
            journal_directory = "${journalPath}"
            exclude_units = []
            # Info and above
            include_matches.PRIORITY = [ "0", "1", "2", "3", "4", "5", "6" ]
          [transforms.journald_cleaned]
            type = "remap"
            inputs = ["journald"]
            source = ''''
                del(._MACHINE_ID)
                del(._SYSTEMD_INVOCATION_ID)
                del(._SYSTEMD_CGROUP)
                del(._MACHINE_ID)
                del(._CMDLINE)
                del(._SYSTEMD_SLICE)
                del(._EXE)
                .systemd_scope = del(._RUNTIME_SCOPE)
                .systemd_unit = del(._SYSTEMD_UNIT)
                .syslog_id = del(._SYSLOG_IDENTIFIER)
                .transport = del(._TRANSPORT)
                .pid = del(._pid)
                .uid = del(._uid)
            ''''
          [sources.docker]
            type = "docker_logs"
          [transforms.docker_cleaned]
            type = "remap"
            inputs = ["docker"]
            source = ''''
                del(.label.description)
                del(.label."io.k8s.description")
                del(.label."io.k8s.display_name")
                del(.label.url)
                del(.label.summary)
                del(.label.vendor)
                del(.label."org.opencontainers.image.description")
                del(.label."vcs.ref")
            ''''
            #del(.username)
          [sinks.loki_docker]
            type = "loki"
            inputs = ["docker_cleaned"]
            endpoint = "http://localhost:${toString ports.upLoki}"
            encoding.codec = "json"
            healthcheck.enabled = true
            # since . is used by Vector to denote a parent-child relationship, and Nomad's Docker labels contain ".",
            # we need to escape them twice, once for TOML, once for Vector
            labels.task  = "{{ label.\"com.hashicorp.nomad.task_name\" }}"
            labels.job   = "{{ label.\"com.hashicorp.nomad.job_name\" }}"
            labels.alloc = "{{ label.\"com.hashicorp.nomad.alloc_id\" }}"
            labels.node  =      "{{ label.\"com.hashicorp.nomad.node_name\" }}"
            labels.task_group = "{{ label.\"com.hashicorp.nomad.task_group_name\" }}"
            labels.source_type = "nomad_docker"
            # labels.group = "{{ label.com\\.hashicorp\\.nomad\\.task_group_name }}"
            # labels.namespace = "{{ label.com\\.hashicorp\\.nomad\\.namespace }}"
            # remove fields that have been converted to labels to avoid having the field twice
            remove_label_fields = true
          [sinks.loki_journald]
            type = "loki"
            inputs = ["journald_cleaned"]
            endpoint = "http://localhost:${toString ports.upLoki}"
            encoding.codec = "json"
            healthcheck.enabled = true
            labels.host = "{{ host }}"
            labels.systemd_unit = "{{ systemd_unit }}"
            labels.source_type = "journald"
            remove_label_fields = true
        '';
      };
    };
  };
}
