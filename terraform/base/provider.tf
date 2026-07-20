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
      version = "0.23.0"
    }
      b2 = {
        source  = "Backblaze/b2"
        version = "~> 0.13"
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

data "bitwarden-secrets_secret" "b2-access" {
  id = "eb3a4c55-862c-4258-8e4d-b48c00d79177"
}
provider "b2" {
  application_key_id = jsondecode(data.bitwarden-secrets_secret.b2-access.value)["keyID"]
  application_key = jsondecode(data.bitwarden-secrets_secret.b2-access.value)["applicationKey"]
}

provider "vault" {
  address         = var.vault_addr
  #skip_tls_verify = true
}

provider "nomad" {
  address     = "https://nomad.mesh.dcotta.eu:4646"
  skip_verify = true
}

data "bitwarden-secrets_secret" "cloudflareToken" {
  id = "cb61fe49-b13d-412c-919e-ae6ed6866a78"
}

provider "cloudflare" {
  api_token = data.bitwarden-secrets_secret.cloudflareToken.value
}

data "bitwarden-secrets_secret" "awsTfUser" {
  id = "495fba0d-82a0-46c0-8946-532a7e3e6209"
}

provider "aws" {
  region     = "eu-west-1"
  access_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["access_key"]
  secret_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["secret_key"]
}

// expires often (90d) renew at
// https://console.tailscale.com/admin/settings/keys
// and paste in
// https://vault.bitwarden.com/#/sm/6fbc3b2a-28df-48ba-a6b5-b36b011cf150/projects/853d6833-835b-4f59-b35c-0d56c8443d54/secrets
data "bitwarden-secrets_secret" "tailscale_api" {
  id = "8f760e22-98e2-4a43-b841-502efff0fc16"
}

provider "tailscale" {
  api_key = data.bitwarden-secrets_secret.tailscale_api.value
}
