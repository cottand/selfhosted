
resource "vault_mount" "pki_workload_int" {
  path        = "pki_workload_int"
  type        = "pki"
  description = "Intermediate PKI mount"

  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 157680000
}

resource "vault_pki_secret_backend_intermediate_cert_request" "workload-csr-request" {
  backend     = vault_mount.pki_workload_int.path
  type        = "internal"
  common_name = "dcotta Workloads Intermediate Authority"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "workload_intermediate" {
  backend     = vault_mount.pki.path
  common_name = "dcotta2 workloads intermediate"
  csr         = vault_pki_secret_backend_intermediate_cert_request.workload-csr-request.csr
  format      = "pem_bundle"
  ttl         = 75480000
  issuer_ref  = vault_pki_secret_backend_root_cert.root_2024.issuer_id
}

# step 2.5
# vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

resource "vault_pki_secret_backend_intermediate_set_signed" "workload_intermediate" {
  backend     = vault_mount.pki_workload_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.workload_intermediate.certificate
}

# manage the issuer created for the set signed
resource "vault_pki_secret_backend_issuer" "workloads-intermediate" {
  backend     = vault_mount.pki_workload_int.path
  issuer_ref  = vault_pki_secret_backend_intermediate_set_signed.workload_intermediate.imported_issuers[0]
  issuer_name = "dcotta-dot-workloads-intermediate"
}


resource "vault_pki_secret_backend_role" "intermediate_role-workloads" {
  backend          = vault_mount.pki_workload_int.path
  issuer_ref       = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  name             = "dcotta-dot-eu-workloads"
  ttl              = 1292000
  max_ttl          = 12 * 1292000 # 1 month ish
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["dcotta.eu", "nomad", "traefik", "consul", "dcotta.com", "tfk.nd"]
  allow_wildcard_certificates = true
  allow_subdomains = true
}

resource "vault_pki_secret_backend_cert" "traefik-internal-wildcard-cert" {
  issuer_ref  = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  backend     = vault_mount.pki_workload_int.path
  name        = vault_pki_secret_backend_role.intermediate_role-workloads.name
  common_name = "wildcard-cert-dec-2024.traefik"

  alt_names = [ "*.tfk.nd", "*.dcotta.com", "*.dcotta.eu"]

  ttl    = 6 * 1292000 # 6 months ish
  auto_renew = true
  revoke = true
}


resource "vault_kv_secret_v2" "traefik-internal-wildcard-cert" {
  mount = vault_mount.kv-secret.path
  name  = "/nomad/job/traefik/internal-cert"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.traefik-internal-wildcard-cert.private_key
    chain = "${vault_pki_secret_backend_cert.traefik-internal-wildcard-cert.certificate}\n${vault_pki_secret_backend_cert.traefik-internal-wildcard-cert.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}
