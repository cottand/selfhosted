{ config, lib, ... }:
let
  nomadTypes = config._module.types;
  types = lib.types;
  attrsToList = transform: attrSet: builtins.attrValues (builtins.mapAttrs transform attrSet);

  setNetworksAsNetwork = { config, options, ... }: {
    _module.types.TaskGroup = types.submodule ({ name, config, ... }: {
      options.network = lib.mkOption {
        type = (types.nullOr nomadTypes.NetworkResource);
        default = null;
      };
      config.networks = [ config.network ];
    });
  };

  setServiceAsServices = { config, options, ... }: {
    _module.types.TaskGroup = types.submodule ({ name, config, ... }: {
      options.service = lib.mkOption {
        type = types.attrsOf (nomadTypes.Service);
        default = {};
      };
      config.services = with builtins; attrValues (mapAttrs (name: body: body // { inherit name; }) config.service);
    });
  };

  setConsulUpstreamsAsUpstream = { config, options, ... }: {
    _module.types.ConsulProxy = types.submodule ({ name, config, ... }: {
      options.upstream = lib.mkOption {
        type = types.attrsOf (nomadTypes.ConsulUpstream);
        default = {};
      };
      config.upstreams = attrsToList (name: body: body // { destinationName = name; }) config.upstream;
    });
  };
in
{

  imports = [
    setNetworksAsNetwork
    setServiceAsServices
    setConsulUpstreamsAsUpstream
  ];


}
