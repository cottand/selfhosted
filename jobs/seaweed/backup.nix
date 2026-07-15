{ util, time, ... }:
let
  version = "4.31";
  cpu = 150;
  mem = 120;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
in
{
  job."seaweedfs-backup" = {
    group."backup" = {
      count = 1;
      network = {
        mode = "bridge";
        port."metrics" = { };
      };
      restart = {
        interval = 10 * time.minute;
        attempts = 5;
        delay = 15 * time.second;
        mode = "delay";
      };
      service."seaweed-backup" = {
        port = "metrics";
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "seaweed-filer-http"; localBindPort = 8888; }
              { destinationName = "seaweed-filer-grpc"; localBindPort = 18888; }
            ];
          };
        };
        connect.sidecarTask.resources = sidecarResources;
      };
      task."backup" = {
        driver = "docker";
        config = {
          image = "chrislusf/seaweedfs:${version}";
          args = [
            "-logtostderr"
            "filer.backup"
            "-filer=localhost:8888.18888"
          ];
          mounts = [{
            type = "bind";
            source = "local";
            target = "/etc/seaweedfs/";
          }];
        };
        resources = {
          cpu = cpu;
          memory = mem;
        };
        templates = [{
          destination = "local/replication.toml";
          changeMode = "restart";
          data = ''
            [sink.s3]
            enabled = true
            {{ with nomadVar "secret/buckets/seaweedfs-bu" }}
            aws_access_key_id     = "{{ .keyId }}"
            aws_secret_access_key = "{{ .secretAccessKey }}"
            bucket = "{{ .bucketName }}"
            endpoint = "https://{{ .endpoint }}"
            {{ end }}
            region = "us-east-005"
            directory = "/snapshot3/"
            is_incremental = false
          '';
        }];
      };
    };
  };
}
