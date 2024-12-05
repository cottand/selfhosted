module "workload-role-workload-cert-issuer" {
  source        = "../modules/workload-role"
  name          = "workload-cert-issuer"
  vault_backend = vault_jwt_auth_backend.jwt-nomad.path
  vault_policy = file("policies/workload-cert-issuer.hcl")
}

module "workload-role-workload-telemetry-ro" {
  source        = "../modules/workload-role"
  name          = "telemetry-ro"
  vault_backend = vault_jwt_auth_backend.jwt-nomad.path
  vault_policy = file("policies/telemetry-ro.hcl")
}

module "workload-role-services-db-rw-default" {
  source        = "../modules/workload-role"
  name          = "service-db-rw-default"
  vault_backend = vault_jwt_auth_backend.jwt-nomad.path
  vault_policy  = "${file("policies/nomad-workloads.hcl")}\n${file("policies/service-db-rw-default.hcl")}"
}


locals {
  # name -> [ policies ]
  nomad_roles = {
    "bigquery-dataviewer" = {
      policies = [vault_policy.gcp-bigquery-dataviewer.name]
      ttl = 30 * 60 * 60
    }

    "services-go" = {
      policies = [
        vault_policy.gcp-bigquery-querier-editor.name,
        vault_policy.services-all-secrets-ro.name,
        vault_policy.vault-backup-maker.name,
        module.workload-role-services-db-rw-default.policy_name,
      ]
      ttl = 10 * 60 * 60 # 10h
    }

    ###
    # below is for microservices mode only!
    ######

    "service-default" = {
      policies = [
        module.workload-role-services-db-rw-default.policy_name,
        vault_policy.service-self-secrets-read.name,
      ]
      ttl = 48 * 60 * 60 # 48h
    }

    "s-rpc-vault" = {
      policies = [
        module.workload-role-services-db-rw-default.policy_name,
        vault_policy.service-self-secrets-read.name,
        vault_policy.vault-backup-maker.name,
      ]
      ttl = 48 * 60 * 60 # 48h
    }
  }
}


resource "vault_jwt_auth_backend_role" "nomad_workloads_role" {
  for_each                = local.nomad_roles
  role_name               = each.key
  role_type               = "jwt"
  bound_audiences = ["vault.io"]
  user_claim              = "/nomad_job_id"
  user_claim_json_pointer = true
  claim_mappings = tomap({
    nomad_namespace = "nomad_namespace"
    nomad_job_id    = "nomad_job_id"
    nomad_task      = "nomad_task"
  })
  token_type             = "service"
  token_policies = concat(each.value.policies, [vault_policy.nomad-workloads-base.name])
  token_max_ttl          = each.value.ttl
  token_explicit_max_ttl = 0
  backend                = vault_jwt_auth_backend.jwt-nomad.path
}