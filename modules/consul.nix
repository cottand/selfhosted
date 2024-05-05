{ lib, config, name, meta, ... }:
with lib;
let
  cfg = config.consulNode;
in
{
  options.consulNode = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    server = mkOption {
      type = types.bool;
      default = false;
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
    };
  };

  config =
    mkIf cfg.enable
      {
        vaultSecrets =
          let
            destDir = "/opt/consul/tls";
            secretPath = "consul/infra/tls";
          in
          {
            "consul.key.rsa" = { inherit destDir secretPath; field = "key"; };
            "consul.crt.pem" = { inherit destDir secretPath; field = "chain"; };
            "consul.ca.pem" = { inherit destDir secretPath; field = "ca"; };
          };


        deployment.tags = mkIf cfg.server [ "consul-server" ];
        systemd.services.consul = {
          serviceConfig.Environment = "HOME=/root";
          after = [ "wg-quick-wg-mesh.service" ];
        };

        services.consul = {
          dropPrivileges = false;
          enable = true;
          webUi = true;
          # interface.bind = "{{GetInterfaceIP \"wg-mesh\"}}";
          interface.bind = "wg-mesh";
          forceAddrFamily = "ipv4";

          extraConfig = {

            retry_join = with meta.ip.mesh; [ miki cosmo maco ];

            datacenter = "dc1";
            data_dir = "/opt/consul";
            log_level = "INFO";
            node_name = name;

            server = cfg.server;
            auto_encrypt.allow_tls = cfg.server && true;

            telemetry = {
              disable_hostname = true;
              enable_host_metrics = true;
              prometheus_retention_time = "1h";
            };

            # TODO FIX DNS!
            ui_config = {
              enabled = true;
              # metrics_provider = "prometheus";
              # metrics_proxy.base_url = "https://mimir-http.traefik/prometheus";
              # metrics_proxy.path_allowlist = ["/prometheus/api/v1/query_range" "/prometheus/api/v1/query"];
            };

            client_addr = ''{{ GetInterfaceIP "wg-mesh" }} {{ GetAllInterfaces | include "flags" "loopback" | join "address" " " }}'';

            connect.enabled = true;
            # ports.http = -1;
            ports.https = 8501;
            ports.grpc = 8502;
            ports.grpc_tls = 8503;
            tls = {
              defaults = {
                verify_incoming = false;
                verify_outgoing = true;
                verify_server_hostname = true;

                ca_file = config.vaultSecrets."consul.ca.pem".path;
                cert_file = config.vaultSecrets."consul.crt.pem".path;
                key_file = config.vaultSecrets."consul.key.rsa".path;
              };
              internal_rpc.verify_server_hostname = true;
              grpc.use_auto_cert = false;
            };

            acl = {
              enabled = true;
              default_policy = "allow";
              enable_token_persistence = true;
            };
          };
        } // cfg.extraConfig;
      };

}
