terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "2.20.0"
    }
  }
}

provider "consul" {
  address        = "10.10.4.1:8501"
  insecure_https = true
  scheme         = "https"
  datacenter     = "dc1"
}