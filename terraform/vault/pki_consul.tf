
resource "vault_pki_secret_backend_role" "intermediate_role-consul-dc1" {
  backend          = vault_mount.pki_workload_int.path
  issuer_ref       = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  name             = "dcotta-dot-eu-consul-dc1"
  ttl              = 12920000
  max_ttl          = 12920000 # 10 months ish
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["dc1.consul", "traefik"]
  allow_subdomains = true
  generate_lease   = true
}


resource "vault_pki_secret_backend_cert" "server-dc1-consul" {
  issuer_ref  = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  backend     = vault_pki_secret_backend_role.intermediate_role-consul-dc1.backend
  name        = vault_pki_secret_backend_role.intermediate_role-consul-dc1.name
  common_name = "server.dc1.consul"

  alt_names = [
    "13mar.server.dc1.consul",
    "consul.traefik",
  ]
  ip_sans = [
    "127.0.0.1",
    "10.10.4.1",
  ]

  ttl    = 12920000
  revoke = true
}


# resource "local_sensitive_file" "server-dc1-consul_private_key" {
#   content  = vault_pki_secret_backend_cert.server-dc1-consul.private_key
#   filename = "../../secret/pki/consul/key.rsa"
# }

# resource "local_file" "server-dc1-consul_cert-chain" {
#   content  = "${vault_pki_secret_backend_cert.server-dc1-consul.certificate}\n${vault_pki_secret_backend_cert.server-dc1-consul.ca_chain}"
#   filename = "../../secret/pki/consul/cert-chain.pem"
# }

resource "vault_kv_secret_v2" "consul-pub-cert" {
  mount = vault_mount.kv-secret.path
  name  = "/consul/infra/tls"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.server-dc1-consul.private_key
    chain = "${vault_pki_secret_backend_cert.server-dc1-consul.certificate}\n${vault_pki_secret_backend_cert.server-dc1-consul.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2023.certificate
  })
}
