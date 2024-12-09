terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "3.10.0"
    }
    oci = {
      source  = "oracle/oci"
      version = "6.12.0"
    }
    bitwarden-secrets = {
      source  = "sebastiaan-dev/bitwarden-secrets"
      version = "0.1.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2.0"
    }
  }
}

data "external" "keychain-bw-token" {
  program = ["keychain-get", "bitwarden/secret/m3-cli"]
}

provider "vault" {
  address         = local.vault_addr
}

provider "bitwarden-secrets" {
  access_token = data.external.keychain-bw-token.result.value
}
provider "grafana" {
  url = "https://grafana.tfk.nd/"
  #   auth = var.grafana_auth
}

data "bitwarden-secrets_secret" "ociTfPrivateKey" {
  id = "e5f873c0-b496-4d86-9ed2-b1e60129b263"
}

locals {
  ociUser = jsondecode(data.bitwarden-secrets_secret.ociTfPrivateKey.value)
  ociRoot = local.ociUser["ocid"]
  ociTenancyOcid = local.ociUser["ocid"]
}

provider "oci" {
  private_key  = local.ociUser["private_key"]
  tenancy_ocid = local.ociUser["ocid"]
  user_ocid    = local.ociUser["user_ocid"]
  fingerprint  = local.ociUser["fingerprint"]

  region = "eu-frankfurt-1"
}
