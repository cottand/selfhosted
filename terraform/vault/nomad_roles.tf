
module "workload-role-workload-cert-issuer" {
  source        = "../modules/workload-role"
  name          = "workload-cert-issuer"
  vault_backend = vault_jwt_auth_backend.jwt-nomad.path
  vault_policy  = file("policies/workload-cert-issuer.hcl")
}

module "workload-role-workload-telemetry-ro" {
  source        = "../modules/workload-role"
  name          = "telemetry-ro"
  vault_backend = vault_jwt_auth_backend.jwt-nomad.path
  vault_policy  = file("policies/telemetry-ro.hcl")
}

