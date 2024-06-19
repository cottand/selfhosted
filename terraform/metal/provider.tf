
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    bitwarden-secrets = {
      source = "sebastiaan-dev/bitwarden-secrets"
      version = "0.1.2"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}
variable "bitwarden_project_id" {
  type = string
  default = "c8bd3b87-1369-4dfb-b2a0-b18601273dfd"
}

data "external" "keychain-bw-token" {
  program = [ "keychain-get", "bitwarden/secret/m3-cli" ]
}

provider "bitwarden-secrets" {
  access_token = data.external.keychain-bw-token.result.value
}

data "bitwarden-secrets_secret" "cloudflareToken" {
  id = "d3f24d46-b0bd-4b63-99b5-b186013237b4"
}

data "bitwarden-secrets_secret" "hetznerToken" {
  id = "0f9e3a2a-5a27-4f2c-a5b6-b193016a9072"
}
  
provider "cloudflare" {
  api_token = data.bitwarden-secrets_secret.cloudflareToken.value
}
provider "hcloud" {
  token = data.bitwarden-secrets_secret.hetznerToken.value
}

data "bitwarden-secrets_secret" "awsTfUser" {
  id = "29faed54-7b0f-47ce-b233-b186014331e1"
}

provider "aws" {
  region                   = "eu-west-1"
  access_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["access_key"]
  secret_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["secret_key"]
}
