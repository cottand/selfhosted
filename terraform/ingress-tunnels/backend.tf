terraform {
  backend "s3" {
    bucket                      = "cottand-selfhosted-tf"
    key                         = "ingress-tunnels"
    region                      = "us-east-005"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    shared_credentials_files = ["../../secret/b2/cottand-selfhosted-tf-rw"]
    use_path_style              = true
    endpoints = {
      s3 = "https://s3.us-east-005.backblazeb2.com"
    }
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.22.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.23.0"
    }
    bitwarden-secrets = {
      source  = "sebastiaan-dev/bitwarden-secrets"
      version = "0.1.2"
    }
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.13"
    }
  }
}