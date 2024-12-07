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


  # name: {
  #    policies -> [string],
  #    ttl -> int,
  # }
  nomad_roles = {
    "nomad-workload-default" = {
      policies = [
        vault_policy.nomad-workloads-base.name,
      ]
      ttl = 10 * 24 * 60 * 60 # 10d
    }

    ###
    # below is for microservices mode only!
    ######

    "service-default" = {
      policies = [
        vault_policy.nomad-workloads-base.name,
        module.workload-role-services-db-rw-default.policy_name,
        vault_policy.service-self-secrets-read.name,

      ]
      ttl = 48 * 60 * 60 # 48h
    }

    "s-rpc-vault" = {
      policies = [
        vault_policy.nomad-workloads-base.name,
        module.workload-role-services-db-rw-default.policy_name,
        vault_policy.service-self-secrets-read.name,
        vault_policy.vault-backup-maker.name,
      ]
      ttl = 48 * 60 * 60 # 48h
    }

    "s-web-github-webhook" = {
      policies = [
        vault_policy.nomad-workloads-base.name,
        vault_policy.gcp-bigquery-dataviewer.name,
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
  token_policies = concat(each.value.policies, [])
  // token_period means that as long as Nomad renews it, the token is chilling
  // this is necessary as otherwise the token will expire altogether and the task will fail
  token_period           = each.value.ttl
  token_explicit_max_ttl = 0
  backend                = vault_jwt_auth_backend.jwt-nomad.path
}


locals {

  # new services with non-default vault privileges should be added here,
  # and the role will be used by services-go
  services-go-modules = [
    "s-rpc-vault",
    "s-web-github-webhook",
  ]
}

// takes all the roles in local.services-go-modules
// and makes a role that has the policies of all those roles
resource "vault_jwt_auth_backend_role" "nomad_workloads_role_services-go" {
  role_name               = "services-go"
  role_type               = "jwt"
  bound_audiences = ["vault.io"]
  user_claim              = "/nomad_job_id"
  user_claim_json_pointer = true
  claim_mappings = tomap({
    nomad_namespace = "nomad_namespace"
    nomad_job_id    = "nomad_job_id"
    nomad_task      = "nomad_task"
  })
  token_type = "service"
  token_policies = toset(
    concat(
      flatten([for role in local.services-go-modules : local.nomad_roles[role]["policies"]]),
      [
        # other than that, services-go is unique as it must be able to read all other services' secrets,
        # not just self (since self name does not match others' secrets)
        vault_policy.services-all-secrets-read.name
      ],
    )
  )
  token_period           = 12 * 60 * 60
  token_explicit_max_ttl = 0
  backend                = vault_jwt_auth_backend.jwt-nomad.path
}