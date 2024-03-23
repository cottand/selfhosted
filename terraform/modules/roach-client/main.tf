
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.23.0"
    }
  }
}

variable "vault_mount" {
  type = string
}

variable "name" {
  type = string
}

variable "vault_issuer_ref" {
  type = string
}
variable "vault_backend" {
  type = string
}

variable "vault_role_name" {
  type = string
}

variable "alt_names" {
  type = list(string)
  default = [ ]
}

data "vault_pki_secret_backend_root_cert" "root_2023" {
  
  
}


resource "vault_pki_secret_backend_cert" "cockroachdb-cert" {
  issuer_ref  = var.vault_issuer_ref
  backend     = var.vault_backend
  name        = var.vault_role_name
  common_name = var.name

  ttl    = 72200000
  revoke = true
}

resource "vault_kv_secret_v2" "cockroachdb-user" {
  mount      = vault_mount.kv-secret.path
  name       = "/nomad/job/roach/users/${name}"
  data_json = jsonencode({
    key = vault_pki_secret_backend_cert.cockroachdb-cert.private_key
    chain = "${vault_pki_secret_backend_cert.cockroachdb-cert.certificate}\n${vault_pki_secret_backend_cert.cockroachdb-cert.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2023.certificate
  })
}
