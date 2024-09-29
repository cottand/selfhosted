terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2.0"
    }
  }
}

provider "nomad" {
  address = "https://nomad.mesh.dcotta.eu:4646"
}

provider "vault" {
  address = var.vault_addr
}