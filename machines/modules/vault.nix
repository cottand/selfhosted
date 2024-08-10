{ name, config, pkgs, secretPath, lib, meta, ... }:
with lib; let
  bind = meta.ip.mesh."${name}";
  cfg = config.vaultNode;
in
{

  options.vaultNode = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };


  config = mkIf cfg.enable {
    deployment.tags = [ "vault-server" ];
    security.pki.certificateFiles = [
      ./../certs/root_2024_ca.crt
    ];
    systemd.tmpfiles.rules = [ "d /vault/data 1777 root root -" ];
    services.vault = {
      enable = true;
      storageBackend = "raft";

      storageConfig = ''
        # node_id = "node1"
        path = "/vault/data"

        retry_join {
          leader_api_addr         = "https://${meta.ip.mesh.hez1}:8200"
          leader_tls_servername   = "${meta.ip.mesh.hez1}"
          leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
          leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
          leader_client_key_file  = "/opt/vault/tls/vault-key.rsa"
        }
        retry_join {
          leader_api_addr         = "https://${meta.ip.mesh.hez2}:8200"
          leader_tls_servername   = "${meta.ip.mesh.hez2}"
          leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
          leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
          leader_client_key_file  = "/opt/vault/tls/vault-key.rsa"
        }
        retry_join {
          leader_api_addr         = "https://${meta.ip.mesh.hez3}:8200"
          leader_tls_servername   = "${meta.ip.mesh.hez3}"
          leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
          leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
          leader_client_key_file  = "/opt/vault/tls/vault-key.rsa"
        }
      '';
      # for listener tcp
      address = "${bind}:8200";
      extraConfig = ''
        api_addr = "https://${bind}:8200"
        cluster_addr = "https://${bind}:8201"
        ui = true
        disable_mlock = true
        seal "awskms" {
          region     = "eu-west-1"
          # see https://eu-west-1.console.aws.amazon.com/kms/home?region=eu-west-1#/kms/keys
          kms_key_id = "5b6a9397-a8a3-4fb4-b85f-61608ac48411"
        }
        telemetry {
          # at /v1/sys/metrics 
          disable_hostname = true
          prometheus_retention_time = "6h"
        }
        default_max_request_duration = "3600s"
      '';
      package = pkgs.vault-bin;

      tlsKeyFile = "/opt/vault/tls/vault-key.rsa";
      tlsCertFile = "/opt/vault/tls/vault-cert.pem";
      listenerExtraConfig = ''
        # for checking client - not mandatory
        tls_client_ca_file = "/opt/vault/tls/vault-ca.pem"
        cluster_address = "${bind}:8201"
      '';
    };

    # permissions from https://developer.hashicorp.com/vault/tutorials/raft/raft-deployment-guide
    deployment.keys."vault-key.rsa" = {
      keyFile = secretPath + "pki/vault/key.rsa";
      destDir = "/opt/vault/tls";
      user = "root";
      group = "vault";
      permissions = "0640";
    };
    deployment.keys."vault-cert.pem" = {
      keyFile = secretPath + "pki/vault/mesh-cert-chain.pem";
      # keyFile = secretPath + "../certs/mesh-cert-chain.pem";
      destDir = "/opt/vault/tls";
      user = "root";
      group = "root";
      permissions = "0644";
    };
    deployment.keys."vault-ca.pem" = {
      keyFile = secretPath + "pki/vault/mesh-ca.pem";
      # keyFile = secretPath + "../certs/mesh-ca.pem";
      destDir = "/opt/vault/tls";
      user = "root";
      group = "root";
      permissions = "0644";
    };
    deployment.keys."vault-aws.env" = {
      keyCommand = [ "bws-get"  "d9709fc0-8f24-4e51-9435-b186014a5e6b"];
      destDir = "/opt/vault/aws";
      user = "root";
      group = "vault";
      permissions = "0640";
    };
    systemd.services.vault = {
      partOf = [
        "vault-key.pem.service"
        "vault-cert.pem.service"
        "vault-ca.pem.service"
      ];
      after = [ "wg-quick-wg-mesh.service" ];
      # for KMS auto unseal
      serviceConfig.EnvironmentFile = config.deployment.keys."vault-aws.env".path;
    };
  };
}
