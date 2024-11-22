terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    bitwarden-secrets = {
      source  = "sebastiaan-dev/bitwarden-secrets"
      version = "0.1.2"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    oci = {
      source  = "oracle/oci"
      version = "6.12.0"
    }
    google = {
      source = "hashicorp/google"
      version = "6.11.2"
    }
  }
}
variable "bitwarden_project_id" {
  type    = string
  default = "c8bd3b87-1369-4dfb-b2a0-b18601273dfd"
}

data "external" "keychain-bw-token" {
  program = ["keychain-get", "bitwarden/secret/m3-cli"]
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

locals {
  ociUser   = jsondecode(data.bitwarden-secrets_secret.ociTfPrivateKey.value)
  awsTfUser = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)
  ociRoot   = local.ociUser["ocid"]
}

provider "aws" {
  region     = "eu-west-1"
  access_key = local.awsTfUser["access_key"]
  secret_key = local.awsTfUser["secret_key"]
}

data "bitwarden-secrets_secret" "ociTfPrivateKey" {
  id = "e5f873c0-b496-4d86-9ed2-b1e60129b263"
}

provider "oci" {
  private_key  = local.ociUser["private_key"]
  tenancy_ocid = local.ociUser["ocid"]
  user_ocid    = local.ociUser["user_ocid"]
  fingerprint  = local.ociUser["fingerprint"]

  region = "eu-frankfurt-1"
}

data "bitwarden-secrets_secret" "zoneIds" {
  id = "90566b46-9de6-486a-a1b5-b186013d4406"
}

# followed https://developer.hashicorp.com/terraform/tutorials/gcp-get-started
provider "google" {
  project = "dcotta-com"
  region = "europe-west3"
}
