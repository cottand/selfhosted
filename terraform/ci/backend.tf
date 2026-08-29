terraform {
  backend "s3" {
    bucket                      = "cottand-selfhosted-tf"
    key                         = "ci"
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
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "2.5.1"
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
      version = "0.16.2"
    }
  }
}
