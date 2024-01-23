
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
  }
}

provider "vault" {
  address = var.vault_addr
  skip_tls_verify =  true
}

provider "nomad" {
  address = "https://nomad.mesh.dcotta.eu:4646"
  skip_verify = true  
}


provider "aws" {
  region                   = "eu-west-1"
  shared_credentials_files = ["../../secret/aws/creds"]
}
  
provider "cloudflare" {
  api_token = file("../../secret/cloudflare/token")
}