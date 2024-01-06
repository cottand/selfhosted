
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.23.0"
    }
  }
}

provider "vault" {
  address = var.vault_addr
  # Configuration options
  # ca_cert_file = ".../../secret/pki/vault.bk/ca.pem"
}

provider "nomad" {
  address = "https://nomad.mesh.dcotta.eu:4646"
}


provider "aws" {
  region                   = "eu-west-1"
  shared_credentials_files = ["../secret/aws/creds"]
}