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
