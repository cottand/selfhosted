
terraform {
  required_providers {
  }
}


provider "nomad" {
  address = "https://nomad.mesh.dcotta.eu:4646"
  skip_verify = true  
}