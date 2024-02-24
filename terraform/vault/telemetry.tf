resource "vault_policy" "telemetry_ro" {
  name = "telemetry-ro"
  policy = file("policies/telemetry-ro.hcl")
}


# telemetry-ro role
resource "vault_jwt_auth_backend_role" "telemetry_ro" {
  role_name               = "telemetry-ro"
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
  token_policies         = [vault_policy.telemetry_ro.name]
  token_period           = 30 * 60 * 60
  token_explicit_max_ttl = 0
  backend                = vault_jwt_auth_backend.jwt-nomad.path
}