resource "vault_pki_secret_backend_role" "intermediate_role-roach-node" {
  backend            = vault_mount.pki_workload_int.path
  issuer_ref         = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  name               = "dcotta-dot-eu-long-workloads"
  ttl                = 72200000
  max_ttl = 72200000 # 100 months ish
  allow_ip_sans      = true
  key_type           = "rsa"
  key_bits           = 4096
  allowed_domains    = ["roach-db.tfk.nd", "roach-web.tfk.nd", "node", local.tsDomain]
  allow_subdomains   = true
  allow_bare_domains = true
  allow_localhost    = false
  allow_wildcard_certificates = true
}


resource "vault_pki_secret_backend_cert" "cockroachdb" {
  issuer_ref  = vault_pki_secret_backend_issuer.intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.intermediate_role-roach-node.backend
  name        = vault_pki_secret_backend_role.intermediate_role-roach-node.name
  common_name = "cockroachdb-2024-dec-08.roach-db.tfk.nd"
  alt_names   = [
    "*.${local.tsDomain}",
    "roach-web.tfk.nd",
    "node",
    "roach-db.tfk.nd",
  ]

  ip_sans = [
    "10.0.1.1",
    "10.0.1.2",
    "10.0.1.3",
  ]

  ttl    = 42200000
  revoke = true
}

resource "vault_kv_secret_v2" "cockroachdb-cert" {
  mount     = vault_mount.kv-secret.path
  name      = "/nomad/job/roach/cert"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.cockroachdb.private_key
    chain = "${vault_pki_secret_backend_cert.cockroachdb.certificate}\n${vault_pki_secret_backend_cert.cockroachdb.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}


### TODO role to provision cockraochdb users _ CHANGE FIELDS
resource "vault_pki_secret_backend_role" "intermediate_role-roach-client" {
  backend           = vault_mount.pki_workload_int.path
  issuer_ref        = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  name              = "dcotta-dot-eu-roach-client"
  ttl               = 72200000
  max_ttl           = 72200000
  allow_ip_sans     = false
  allow_localhost   = false
  enforce_hostnames = false
  allow_any_name    = true
  key_type          = "rsa"
  key_bits          = 4096
}

resource "vault_pki_secret_backend_cert" "cockroachdb-client-root" {
  issuer_ref  = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  backend     = vault_mount.pki_workload_int.path
  name        = vault_pki_secret_backend_role.intermediate_role-roach-client.name
  common_name = "root"

  ttl    = 72200000
  revoke = true
}

resource "vault_kv_secret_v2" "cockroachdb-client-root" {
  mount     = vault_mount.kv-secret.path
  name      = "/nomad/job/roach/users/root"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.cockroachdb-client-root.private_key
    chain = "${vault_pki_secret_backend_cert.cockroachdb-client-root.certificate}\n${vault_pki_secret_backend_cert.cockroachdb-client-root.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}

resource "vault_pki_secret_backend_cert" "cockroachdb-client-grafana" {
  issuer_ref  = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  backend     = vault_mount.pki_workload_int.path
  name        = vault_pki_secret_backend_role.intermediate_role-roach-client.name
  common_name = "grafana"

  ttl    = 72200000
  revoke = true
}

resource "vault_kv_secret_v2" "cockroachdb-client-grafana" {
  mount     = vault_mount.kv-secret.path
  name      = "/nomad/job/roach/users/grafana"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.cockroachdb-client-grafana.private_key
    chain = "${vault_pki_secret_backend_cert.cockroachdb-client-grafana.certificate}\n${vault_pki_secret_backend_cert.cockroachdb-client-grafana.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}