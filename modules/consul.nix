{ pkgs, lib, config, name, meta, ... }:
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

        systemd.services.consul.serviceConfig.Environment = "HOME=/root";

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


            # telemetry = {
            #   statsite_address = "127.0.0.1:2180";
            # };

            client_addr = ''{{ GetInterfaceIP "wg-mesh" }} {{ GetAllInterfaces | include "flags" "loopback" | join "address" " " }}'';

            connect.enabled = true;
            ports.https = 8501;
            ports.grpc = 8502;
            ports.grpc_tls = 8503;

            tls.defaults = {
              verify_incoming = false;
              verify_outgoing = true;
              verify_server_hostname = true;

              ca_file = config.vaultSecrets."consul.ca.pem".path;
              cert_file = config.vaultSecrets."consul.crt.pem".path;
              key_file = config.vaultSecrets."consul.key.rsa".path;
            };

            tls.internal_rpc.verify_server_hostname = true;
            tls.grpc.use_auto_cert = false;
          };
        } // cfg.extraConfig;
      };

}
