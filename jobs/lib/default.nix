# utilities to write Jobs in Nix
let
  nixpkgs = builtins.getFlake "github:nixos/nixpkgs/0ef93bf";
  lib = nixpkgs.legacyPackages.${builtins.currentSystem}.lib;
  check = have: expected:
    if have != expected then (throw "assertion failed: got ${builtins.toJSON have} but expected ${builtins.toJSON expected}") else "ok";
in
rec {
  seconds = 1000000000;
  minutes = 60 * seconds;
  hours = 60 * minutes;

  kiB = 1024;

  localhost = "127.0.0.1";

  mkNetworks =
    { mode ? "bridge"
    , port ? { }
    ,
    }: [{
      inherit mode;
      ports = setAsHclList port;
    }];

  setAsHclList = setAsHclListWithLabel "name";

  setAsHclListWithLabel = nameLabel: set: with builtins;
    attrValues (mapAttrs (name: attrs: { ${nameLabel} = name; } // attrs) set);

  replaceIn = transform: oldName: newName: set: if !(builtins.hasAttr oldName set) then set else
  let
    removed = builtins.removeAttrs set [ oldName ];
    transformed = transform set.${oldName};
  in
  removed // { ${newName} = transformed; };

  resolveGlob = path: set: with builtins;
    let
      fst = head path;
      cleanNonTerminals = filter (list: !(elem "_._REM!" list));
    in
    if (length path) == 0 then [ [ ] ] else

    if fst != "*" && (hasAttr fst set) then map (p: [ fst ] ++ p) (resolveGlob (tail path) set.${fst}) else
    if fst != "*" && !(hasAttr fst set) then [ [ "_._REM!" ] ] else
    cleanNonTerminals
      (concatLists
        (map (new: map (p: [ new ] ++ p) (resolveGlob (tail path) set.${new})) (attrNames set)))
  ;

  updateManyWithGlob = ts: toTransform: with builtins; let
    unglobTransformation = set: map (newPath: set // { path = newPath; }) (resolveGlob set.path toTransform);
    unglobbedTs = concatLists (map unglobTransformation ts);
  in
  lib.attrsets.updateManyAttrsByPath unglobbedTs toTransform;

  transformJob = updateManyWithGlob [
    {
      path = [ ];
      update = replaceIn setAsHclList "group" "taskGroups";
    }
    {
      path = [ "group" "*" "service" "*" "connect" ];
      update = replaceIn (id: id) "sidecar_service" "sidecarService";
    }
    {
      path = [ "group" "*" "service" "*" "connect" "sidecarService" "proxy" ];
      update = replaceIn (setAsHclListWithLabel "destinationName") "upstream" "upstreams";
    }
    {
      path = [ "group" "*" "task" "*" "template" ];
      update = replaceIn (id: id) "data" "embeddedTmpl";
    }
    {
      path = [ "group" "*" "task" "*" ];
      update = replaceIn (setAsHclListWithLabel "destPath") "template" "templates";
    }
    {
      path = [ "group" "*" ];
      update = replaceIn (id: id) "restart" "restartPolicy";
    }
    # {
    #   path = [ "group" "*" "network" ];
    #   update = replaceIn (setAsHclListWithLabel "label") "port" "reservedPorts";
    # }
    {
      path = [ "group" "*" "service" "*" ];
      update = replaceIn (port: if !(builtins.isString port) then toString port else port) "port" "portLabel";
    }
    {
      path = [ "group" "*" "task" "*" ];
      update = replaceIn setAsHclList "service" "services";
    }
    {
      path = [ "group" "*" ];
      update = replaceIn (old: [ old ]) "network" "networks";
    }
    {
      path = [ "group" "*" ];
      update = replaceIn setAsHclList "task" "tasks";
    }
    {
      path = [ "group" "*" ];
      update = replaceIn setAsHclList "service" "services";
    }
  ];

  mkEnvoyProxyConfig = import ./mkEnvoyProxyConfig.nix;

  mkJob = name: job: {
    job = (transformJob job) // {
      inherit name;
      id = name;
    };
  };

  mkServiceJob =
    args@{ name
    , cpu
    , memMb
      /**
      * see https://developer.hashicorp.com/nomad/docs/job-specification/upstreams#upstreams-parameters
      * for example:
      * { name = <name>; localBindPort = <port>; }
      */
    , upstream
    , version
    , ports
    , httpTags ? [ ]
    , count ? 1
    , env ? { }
    ,
    }:
    let
      ports = assert (args.ports ? "http") ; (args.ports // { otlp = 9001; });
      sidecarResources = with builtins; mapAttrs (_: ceil) {
        cpu = 0.20 * cpu;
        memoryMB = 0.25 * memMb;
        memoryMaxMB = 0.25 * memMb + 100;
      };
    in
    mkJob name {
      update = {
        maxParallel = 1;
        autoRevert = true;
        autoPromote = true;
        canary = 1;
      };

      group.${name} = {
        inherit count;
        network = {
          mode = "bridge";
          dynamicPorts = [
            { label = "metrics"; }
          ];
          reservedPorts = [ ];
        };
        service = {
          "${name}-http" = rec {
            connect = {
              sidecarService.proxy = {
                upstream = upstream // {
                  "tempo-otlp-grpc-mesh".localBindPort = ports.otlp;
                };

                config = mkEnvoyProxyConfig {
                  otlpService = "proxy-${name}-http";
                  otlpUpstreamPort = ports.otlp;
                  protocol = "http";
                };
              };
              sidecarTask.resources = sidecarResources;
            };
            # TODO implement http healthcheck
            port = toString ports.http;
            meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
            meta.metrics_path = "/metrics";
            checks = [{
              expose = true;
              name = "metrics";
              portLabel = "metrics";
              type = "http";
              path = meta.metrics_path;
              interval = 10 * seconds;
              timeout = 3 * seconds;
            }];
            tags = httpTags;
          };
        } // (if ports ? "grpc" then {
          "${name}-grpc" = {
            connect = {
              sidecarService.proxy.config = mkEnvoyProxyConfig {
                otlpService = "proxy-${name}-grpc";
                otlpUpstreamPort = ports.otlp;
                protocol = "grpc";
              };
              sidecarTask.resources = sidecarResources;
            };
            port = toString ports.grpc;
          };
        } else { });

        task.${name} = {
          driver = "docker";
          vault = { };

          config = {
            image = "ghcr.io/cottand/selfhosted/${name}:${version}";
          };
          env = env // ({
            HTTP_HOST = localhost;
            HTTP_PORT = toString ports.http;
            OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:${toString ports.otlp}";
            OTEL_SERVICE_NAME = name;
          }) // (if ports ? "grpc" then { GRPC_PORT = toString ports.grpc; } else { });
          resources = {
            cpu = cpu;
            memoryMb = memMb;
            memoryMaxMb = builtins.ceil (2 * memMb);
          };
        };
      };
    };


  cosmo.ip = "10.10.0.1";
  elvis.ip = "10.10.1.1";
  maco.ip = "10.10.2.1";
  ari.ip = "10.10.3.1";
  miki.ip = "10.10.4.1";
  ziggy.ip = "10.10.5.1";
  xps2.ip = "10.10.6.1";
  bianco.ip = "10.10.0.2";
  hez1.ip = "10.10.11.1";
  hez2.ip = "10.10.12.1";
  hez3.ip = "10.10.13.1";


  tests = {
    asHclList = check (setAsHclList { lol = { a = 1; }; }) [{ name = "lol"; a = 1; }];

    mapsJobs = check (transformJob { group."lmao" = { }; }) { taskGroups = [{ name = "lmao"; }]; };

    mapsTasks = check (transformJob { group."lmao".task."do" = { }; }) {
      taskGroups = [{
        name = "lmao";
        tasks = [{ name = "do"; }];
      }];
    };
    mapsPorts = check (transformJob { group."lmao".network."port".http = { }; }) {
      taskGroups = [{
        name = "lmao";
        networks = [{
          dynamicPorts = [{ label = "http"; }];
        }];
      }];
    };
  };
}
