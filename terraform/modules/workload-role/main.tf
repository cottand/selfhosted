terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">3.23.0"
    }
  }
}

variable "name" {
    type = string
}

variable "vault_backend" {
  type = string
}

variable "vault_policy" {
  type = string
}



resource "vault_policy" "policy" {
  policy = var.vault_policy
  name   = var.name
}

resource "vault_jwt_auth_backend_role" "role" {
  role_name               = var.name
  role_type               = "jwt"
  bound_audiences         = ["vault.io"]
  user_claim              = "/nomad_job_id"
  user_claim_json_pointer = true
  claim_mappings = tomap({
    nomad_namespace = "nomad_namespace"
    nomad_job_id    = "nomad_job_id"
    nomad_task      = "nomad_task"
  })
  token_type             = "service"
  token_policies         = [var.name]
  token_period           = 30 * 60 * 60
  token_explicit_max_ttl = 0
  backend                = var.vault_backend
}

output "policy_name" {
  value = vault_policy.policy.name
}