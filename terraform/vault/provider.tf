
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2.0"
    }
    bitwarden-secrets = {
      source = "sebastiaan-dev/bitwarden-secrets"
      version = "0.1.2"
    }
    google = {
      source = "hashicorp/google"
      version = "6.11.2"
    }
  }
}

variable "vault_addr" {
  type    = string
  default = "https://vault.dcotta.com:8200"
}
provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = true
}

provider "nomad" {
  address     = "https://nomad.mesh.dcotta.eu:4646"
  skip_verify = true
}

data "external" "keychain-bw-token" {
  program = [ "keychain-get", "bitwarden/secret/m3-cli" ]
}

provider "bitwarden-secrets" {
  access_token = data.external.keychain-bw-token.result.value
}

data "bitwarden-secrets_secret" "awsTfUser" {
  id = "29faed54-7b0f-47ce-b233-b186014331e1"
}

provider "aws" {
  region                   = "eu-west-1"
  access_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["access_key"]
  secret_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["secret_key"]
}
# followed https://developer.hashicorp.com/terraform/tutorials/gcp-get-started
provider "google" {
  project = local.gcp.project
  region = local.gcp.region
}
