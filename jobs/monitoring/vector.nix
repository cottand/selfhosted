let
  lib = import ../lib;
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
  chunkFactor = 1;
in
lib.mkJob "vector" {

  type = "system";

  group."vector" = {
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
      ];
    };
    volumes."docker-sock" = {
      type = "host";
      source = "docker-sock-ro";
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
            otlpService = "dector-proxy";
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
      volumeMounts = [{
        volume = "docker-sock";
        destination = "/var/run/docker.sock";
        readOnly = true;
      }];
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
          [sources.logs]
            type = "docker_logs"
          [transforms.cleaned]
            type = "remap"
            inputs = ["logs"]
            source = ''''
                del(.label.description)
                del(.label."io.k8s.description")
                del(.label.url)
                del(.label.summary)
                del(.label."org.opencontainers.image.description")
            ''''
            #del(.username)
          [sinks.loki]
            type = "loki"
            inputs = ["cleaned"]
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
            # labels.group = "{{ label.com\\.hashicorp\\.nomad\\.task_group_name }}"
            # labels.namespace = "{{ label.com\\.hashicorp\\.nomad\\.namespace }}"
            # remove fields that have been converted to labels to avoid having the field twice
            remove_label_fields = true
        '';
      };
    };
  };
}
