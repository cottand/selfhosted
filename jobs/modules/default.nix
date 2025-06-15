{ config, lib, ... }:
# this file defines some transformations that are applied to all jobs
# most are aesthetic ('network = {}' vs 'networks = [ {} ]')
let
  nomadTypes = config._module.types;
  types = lib.types;
  attrsToList = transform: attrSet: builtins.attrValues (builtins.mapAttrs transform attrSet);

  setNetworksAsNetwork = { config, options, ... }: {
    _module.types.TaskGroup = types.submodule ({ name, config, ... }: {
      options.network = lib.mkOption {
        type = nomadTypes.NetworkResource;
        default = { };
      };
      config.networks = if config.network != { } then [ config.network ] else [ ];
    });
  };

  setServiceAsServices = { config, options, ... }: {
    _module.types.TaskGroup = types.submodule ({ name, config, ... }: {
      options.service = lib.mkOption {
        type = types.attrsOf (nomadTypes.Service);
        default = { };
      };
      config.services = attrsToList (name: body: body // { inherit name; }) config.service;
    });
  };

  setConsulUpstreamsAsUpstream = { config, options, ... }: {
    _module.types.ConsulProxy = types.submodule ({ name, config, ... }: {
      options.upstream = lib.mkOption {
        type = types.attrsOf (nomadTypes.ConsulUpstream);
        default = { };
      };
      config.upstreams = (attrsToList (name: body: (body // { destinationName = name; })) config.upstream);
    });
  };

  # adds links to Grafana and Consul to every job
  # jobs can define their own links too, which will get merged to this list
  addDefaultLinks = { config, options, ... }: {
    _module.types.Job = types.submodule ({ name, config, ... }: {
      options.addDefaultLinks = lib.mkOption {
        type = types.bool;
        default = true;
      };
      config.ui.links = lib.mkIf config.addDefaultLinks [
        {
          label = "Grafana for Job";
          url = "https://grafana.tfk.nd/d/de0ri7g2kukn4a/nomad-job?var-client=All&var-job=${config.name}&var-group=All&var-task=All&var-alloc_id=All";
        }
        {
          label = "Consul services";
          url = "https://consul.traefik/ui/dc1/services?filter=${config.name}";
        }
      ];
    });
  };

  addDefaultTaskEnv = { config, options, ... }: {
    _module.types.Task = types.submodule ({ name, config, ... }: {
      options.addDefaultEnv = lib.mkOption {
        type = types.bool;
        default = true;
      };
      config.env = lib.mkIf config.addDefaultEnv {
        DCOTTA_COM_NODE_CONSUL_IP = "\${attr.consul.dns.addr}";
      };
    });
  };

  # mounts ca-certificates into all tasks as read-only into /etc/ssl/certs
  addCaCertificatesVolumeMount = { ... }: {
    _module.types.TaskGroup = types.submodule {
      config.volume."ca-certificates" = rec {
        name = "ca-certificates";
        type = "host";
        readOnly = true;
        source = name;
      };
    };
    _module.types.Task = types.submodule {
      config.volumeMounts = [{
        volume = "ca-certificates";
        destination = "/etc/ssl/certs";
        readOnly = true;
        propagationMode = "host-to-task";
      }];
    };
  };

in
{

  imports = [
    # breaks because upstreams are actually defined twice because of setServiceAsServices
    #    setConsulUpstreamsAsUpstream
    setNetworksAsNetwork
    setServiceAsServices
    addDefaultLinks
    addDefaultTaskEnv
    addCaCertificatesVolumeMount
    ({ ... }: {
      _module.args.util = (import ./jobsUtil.nix { });
      # defaults is not actually set for every job, but it is given in the module arguments
      # and is opt-in
      _module.args.defaults = {
        dns.servers = [ "100.100.100.100" ];
      };
    })
  ];

}
