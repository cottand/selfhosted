
## Secret KV

resource "vault_mount" "kv-secret" {
  path    = "secret"
  type    = "kv"
  options = { version = "2" }

  description = "Key-vaule v2 for ad-hoc secrets"
}

resource "vault_kv_secret_backend_v2" "kv" {
  mount        = vault_mount.kv-secret.path
  max_versions = 5
}


## PKI

resource "vault_pki_secret_backend_role" "nomad_intermediate_role" {
  backend            = vault_mount.pki_int.path
  issuer_ref         = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  name               = "nomad-dcotta-dot-eu"
  max_ttl            = 25920000
  ttl                = 25920000
  allow_ip_sans      = true
  key_type           = "rsa"
  key_bits           = 4096
  allowed_domains    = ["*.mesh.dcotta.eu", "nomad.traefik", "server.global.nomad", "client.global.nomad"]
  allow_subdomains   = true
  allow_glob_domains = true
  allow_bare_domains = true
}

# new cert
resource "vault_pki_secret_backend_cert" "nomad-dcotta-dot-eu" {
  issuer_ref  = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.nomad_intermediate_role.backend
  name        = vault_pki_secret_backend_role.nomad_intermediate_role.name
  common_name = "server.global.nomad"

  ip_sans = [
    "10.10.0.1",
    "10.10.0.2",
    "10.10.1.1",
    "10.10.2.1",
    "10.10.3.1",
    "10.10.4.1",
    "10.10.5.1",
    "10.10.6.1",
  ]
  alt_names = [ "nomad.traefik", "client.global.nomad", "*.mesh.dcotta.eu", "meta1.mesh.dcotta.eu"]
  ttl       = 8640000
  revoke    = true
}

# Put new cert in KV
resource "vault_kv_secret_v2" "nomad-mtls" {
  depends_on = [vault_pki_secret_backend_cert.nomad-dcotta-dot-eu]
  mount      = vault_mount.kv-secret.path
  name       = "/nomad/infra/tls"
  data_json = jsonencode({
    private_key = "${vault_pki_secret_backend_cert.nomad-dcotta-dot-eu.private_key}"
    cert        = "${vault_pki_secret_backend_cert.nomad-dcotta-dot-eu.certificate}\n${vault_pki_secret_backend_cert.nomad-dcotta-dot-eu.ca_chain}"
    ca          = "${vault_pki_secret_backend_root_cert.root_2023.certificate}"
  })
}

resource "vault_kv_secret_v2" "nomad-pub-cert" {
  depends_on = [vault_pki_secret_backend_cert.nomad-dcotta-dot-eu]
  mount      = vault_mount.kv-secret.path
  name       = "/nomad/infra/root_ca"
  data_json = jsonencode({
    value = "${vault_pki_secret_backend_root_cert.root_2023.certificate}"
  })
}


resource "vault_jwt_auth_backend" "jwt-nomad" {
  type               = "jwt"
  path               = "jwt-nomad"
  jwks_url           = "https://nomad.mesh.dcotta.eu:4646/.well-known/jwks.json"
  jwt_supported_algs = ["RS256", "EdDSA"]
  default_role       = "nomad-workloads"
}

# nomad-workloads role
resource "vault_jwt_auth_backend_role" "nomad-workloads" {
  role_name               = "nomad-workloads"
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
  token_policies         = ["nomad-workloads"] # matches policy in /nomad/vault_policy.nomad-workloads.name
  token_period           = 30 * 60 * 60
  token_explicit_max_ttl = 0
  backend                = vault_jwt_auth_backend.jwt-nomad.path
}

resource "vault_policy" "nomad-workloads" {
  policy = file("policies/nomad-workloads.hcl")
  name   = "nomad-workloads"
}
