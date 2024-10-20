# utilities to write Jobs in Nix
{ nixpkgs ? (builtins.getFlake "github:nixos/nixpkgs/0ef93bf")
, ...
}:
let
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
#    {
#      # stringifies attrbutes of reservedPorts
#      path = [ "group" "*" "network" "reservedPorts" ];
#      update = ports: map (builtins.mapAttrs (_: val: toString val)) ports;
#    }
#    {
#      # stringifies attrbutes of reservedPorts
#      path = [ "group" "*" "network" "dynamicPorts" ];
#      update = ports: map (builtins.mapAttrs (_: val: toString val)) ports;
#    }
    # {
    #   path = [ "group" "*" "network" ];
    #   update = replaceIn (setAsHclListWithLabel "label") "port" "reservedPorts";
    # }
    {
      path = [ "group" "*" "service" "*" ];
      update = replaceIn setAsHclList "check" "checks";
    }
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

  mkSidecarResourcesWithFactor = factor: resources@{ cpu, memoryMB, memoryMaxMB ? memoryMB }: with builtins; mapAttrs (_: ceil) {
    cpu = factor * cpu;
    memoryMB = factor * memoryMB;
    memoryMaxMB = factor * memoryMaxMB + 60;
  };

  mkJob = name: job:
    let
      transformed = transformJob job;
      mkLinkSection = name: {
        label = "Grafana for Job";
        url = "https://grafana.tfk.nd/d/de0ri7g2kukn4a/nomad-job?var-client=All&var-job=${name}&var-group=All&var-task=All&var-alloc_id=All";
      };
    in
    transformed // {
      inherit name;
      id = name;
      ui.links = [ (mkLinkSection name) ] ++ (transformed.ui.links or [ ]);
    };

  tailscaleDns = "golden-dace.ts.net";

  defaults.dns.servers = [ "100.100.100.100" ];

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
