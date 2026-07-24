resource "vault_pki_secret_backend_role" "role_mtls" {
  backend           = vault_mount.pki.path
  issuer_ref        = vault_pki_secret_backend_issuer.root_2024.issuer_ref
  name              = "dcotta-dot-com-mtls"
  ttl               = 60 * 60 * 24 * 365 * 5 # 5 yrs
  max_ttl           = 60 * 60 * 24 * 365 * 5
  allow_ip_sans     = false
  allow_localhost   = false
  enforce_hostnames = false
  ext_key_usage     = ["clientAuth"]
  allowed_domains   = ["mtls.dcotta.com"]
  allow_subdomains  = true
  key_type          = "rsa"
  key_bits          = 4096
}


resource "vault_pki_secret_backend_cert" "client-mtls-cert-personal-m3-v1" {
  issuer_ref  = vault_pki_secret_backend_issuer.root_2024.issuer_ref
  backend     = vault_pki_secret_backend_issuer.root_2024.backend
  name        = vault_pki_secret_backend_role.role_mtls.name
  common_name = "mtls-personal-m3-nico.mtls.dcotta.com"

  alt_names = []

  ttl        = 60 * 60 * 24 * 365 / 2 # 6 months
  auto_renew = true
  revoke     = true
}

#  openssl pkcs12 -export -in ./m3-client-cert.pem -inkey ./m3-client-cert-key.rsa -out cert.pfx
# output "client-mtls-cert-personal-m3-v1-key" {
#   value = vault_pki_secret_backend_cert.client-mtls-cert-personal-m3-v1.private_key
#   sensitive = true
# }
#
# output "client-mtls-cert-personal-m3-v1-cert" {
#   value = "${vault_pki_secret_backend_cert.client-mtls-cert-personal-m3-v1.certificate}\n${vault_pki_secret_backend_cert.client-mtls-cert-personal-m3-v1.ca_chain}"
# }
