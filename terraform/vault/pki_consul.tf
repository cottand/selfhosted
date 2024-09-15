locals {
  tsDomain = "golden-dace.ts.net"
}

resource "vault_pki_secret_backend_role" "intermediate_role-consul-dc1" {
  backend          = vault_mount.pki_workload_int.path
  issuer_ref       = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  name             = "dcotta-consul-dc1"
  ttl              = 12920000
  max_ttl = 12920000 # 10 months ish
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["dc1.consul", "traefik", "mesh.dcotta.com", local.tsDomain]
  allow_subdomains = true
  generate_lease   = true
}


resource "vault_pki_secret_backend_cert" "server-dc1-consul" {
  issuer_ref  = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.intermediate_role-consul-dc1.backend
  name        = vault_pki_secret_backend_role.intermediate_role-consul-dc1.name
  common_name = "server.dc1.consul"

  alt_names = [
    "14sep-1.server.dc1.consul",
    "consul.traefik",
    "hez1.${local.tsDomain}",
    "hez2.${local.tsDomain}",
    "hez3.${local.tsDomain}",
  ]
  ip_sans = [
    "127.0.0.1",
    "10.10.4.1",
    "10.10.11.1",
    "10.10.12.1",
    "10.10.13.1",
  ]

  ttl    = 12920000
  revoke = true
}


resource "vault_kv_secret_v2" "consul-pub-cert" {
  mount     = vault_mount.kv-secret.path
  name      = "/consul/infra/tls"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.server-dc1-consul.private_key
    chain = "${vault_pki_secret_backend_cert.server-dc1-consul.certificate}\n${vault_pki_secret_backend_cert.server-dc1-consul.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}
