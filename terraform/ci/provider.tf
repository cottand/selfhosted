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
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.16.2"
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
  address         = local.vault_addr
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

// expires 12 dec '24
data "bitwarden-secrets_secret" "tailscale_api" {
  id = "a3f637ca-58f0-4bf7-b8d4-b1ea0118edd7"
}

provider "tailscale" {
  api_key = data.bitwarden-secrets_secret.tailscale_api.value
}
