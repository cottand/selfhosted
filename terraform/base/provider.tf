terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.23.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    bitwarden-secrets = {
      source  = "sebastiaan-dev/bitwarden-secrets"
      version = "0.1.2"
    }
    github = {
      source  = "integrations/github"
      version = "6.2.3"
    }
  }
}

data "external" "keychain-bw-token" {
  program = ["keychain-get", "bitwarden/secret/m3-cli"]
}

provider "github" {}

provider "bitwarden-secrets" {
  access_token = data.external.keychain-bw-token.result.value
}

provider "vault" {
  address         = var.vault_addr
  skip_tls_verify = true
}

provider "nomad" {
  address     = "https://nomad.mesh.dcotta.eu:4646"
  skip_verify = true
}

data "bitwarden-secrets_secret" "cloudflareToken" {
  id = "d3f24d46-b0bd-4b63-99b5-b186013237b4"
}

provider "cloudflare" {
  api_token = data.bitwarden-secrets_secret.cloudflareToken.value
}

data "bitwarden-secrets_secret" "awsTfUser" {
  id = "29faed54-7b0f-47ce-b233-b186014331e1"
}

provider "aws" {
  region     = "eu-west-1"
  access_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["access_key"]
  secret_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["secret_key"]
}
