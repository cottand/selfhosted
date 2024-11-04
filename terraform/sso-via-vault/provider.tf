terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4.0"
    }
  }
}

provider "nomad" {
  address = "https://nomad.mesh.dcotta.eu:4646"
}

provider "vault" {
  address = local.vault_addr
  skip_tls_verify = true
}