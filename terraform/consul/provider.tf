terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "2.20.0"
    }
  }
}

provider "consul" {
  address        = "https://consul.traefik"
  insecure_https = false
  scheme         = "https"
  datacenter     = "dc1"
}