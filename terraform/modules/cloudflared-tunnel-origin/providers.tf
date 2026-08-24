terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>5"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~>3"
    }
  }
}
