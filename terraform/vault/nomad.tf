## Secret KV

resource "vault_mount" "kv-secret" {
  path = "secret"
  type = "kv"
  options = { version = "2" }

  description = "Key-vaule v2 for ad-hoc secrets"
}

resource "vault_kv_secret_backend_v2" "kv" {
  mount        = vault_mount.kv-secret.path
  max_versions = 5
}


## PKI

resource "vault_pki_secret_backend_role" "nomad_intermediate_role" {
  backend       = vault_mount.pki_int.path
  issuer_ref    = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  name          = "nomad-dcotta"
  max_ttl       = 25920000
  ttl           = 25920000
  allow_ip_sans = true
  key_type      = "rsa"
  key_bits      = 4096
  allowed_domains = [
    "*.mesh.dcotta.eu",
    "nomad.traefik",
    "nomad.dcotta.com",
    "server.global.nomad",
    "client.global.nomad",
    "*.${local.tsDomain}",
  ]
  allow_subdomains   = true
  allow_glob_domains = true
  allow_bare_domains = true
}

# new cert
resource "vault_pki_secret_backend_cert" "nomad-dcotta" {
  issuer_ref  = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.nomad_intermediate_role.backend
  name        = vault_pki_secret_backend_role.nomad_intermediate_role.name
  common_name = "server.global.nomad"

  ip_sans = []
  alt_names = [
    "nomad.traefik",
    "nomad.dcotta.com",
    "client.global.nomad",
    "*.mesh.dcotta.eu",
    "meta1.mesh.dcotta.eu",
    "*.${local.tsDomain}"
  ]
  ttl    = 8640000
  revoke = true
}

# Put new cert in KV
resource "vault_kv_secret_v2" "nomad-mtls" {
  depends_on = [vault_pki_secret_backend_cert.nomad-dcotta]
  mount = vault_mount.kv-secret.path
  name  = "/nomad/infra/tls"
  data_json = jsonencode({
    private_key = vault_pki_secret_backend_cert.nomad-dcotta.private_key
    cert        = "${vault_pki_secret_backend_cert.nomad-dcotta.certificate}\n${vault_pki_secret_backend_cert.nomad-dcotta.ca_chain}"
    ca          = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}

resource "vault_kv_secret_v2" "nomad-pub-cert" {
  depends_on = [vault_pki_secret_backend_cert.nomad-dcotta]
  mount = vault_mount.kv-secret.path
  name  = "/nomad/infra/root_ca"
  data_json = jsonencode({
    value = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}


resource "vault_jwt_auth_backend" "jwt-nomad" {
  type         = "jwt"
  path = "jwt-nomad"
  # TODO change with nomad.dcotta.com once certs are replaced!
  jwks_url     = "https://nomad.mesh.dcotta.eu:4646/.well-known/jwks.json"
  jwt_supported_algs = ["RS256", "EdDSA"]
  // must match the role below (but tf circular dependency)
  default_role = "nomad-workload-default"
}

# nomad-workloads role
resource "vault_jwt_auth_backend_role" "nomad-workloads-default" {
  role_name               = "nomad-workloads-default"
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
  token_policies = [vault_policy.nomad-workloads-base.name]
  # matches policy in /nomad/vault_policy.nomad-workloads.name
  token_period           = 30 * 60 * 60
  token_explicit_max_ttl = 0
  backend                = vault_jwt_auth_backend.jwt-nomad.path
}
