terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
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
  id = "cb61fe49-b13d-412c-919e-ae6ed6866a78"
}

data "bitwarden-secrets_secret" "hetznerToken" {
  id = "aacaa157-1d09-4d3b-ab09-51dbb11676bf"
}

provider "cloudflare" {
  api_token = data.bitwarden-secrets_secret.cloudflareToken.value
}
provider "hcloud" {
  token = data.bitwarden-secrets_secret.hetznerToken.value
}


data "bitwarden-secrets_secret" "awsTfUser" {
  id = "495fba0d-82a0-46c0-8946-532a7e3e6209"
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
  id = "139da24f-85eb-43a7-9248-58d38a06584e"
}

provider "oci" {
  private_key  = local.ociUser["private_key"]
  tenancy_ocid = local.ociUser["ocid"]
  user_ocid    = local.ociUser["user_ocid"]
  fingerprint  = local.ociUser["fingerprint"]

  region = "eu-frankfurt-1"
}

data "bitwarden-secrets_secret" "zoneIds" {
  id = "f0b0eb57-e7b1-4fae-88b4-eefceaf6b891"
}

# followed https://developer.hashicorp.com/terraform/tutorials/gcp-get-started
provider "google" {
  project = "dcotta-com"
  region = "europe-west3"
}
