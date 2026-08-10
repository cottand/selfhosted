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

resource "vault_pki_secret_backend_cert" "client-mtls-cert-personal-10a-v1" {
  issuer_ref  = vault_pki_secret_backend_issuer.root_2024.issuer_ref
  backend     = vault_pki_secret_backend_issuer.root_2024.backend
  name        = vault_pki_secret_backend_role.role_mtls.name
  common_name = "mtls-personal-10a-nico.mtls.dcotta.com"

  alt_names = []

  ttl        = 60 * 60 * 24 * 365 # 12 months
  auto_renew = true
  revoke     = true
}

resource "vault_pki_secret_backend_cert" "client-mtls-cert-work-m5-v1" {
  issuer_ref  = vault_pki_secret_backend_issuer.root_2024.issuer_ref
  backend     = vault_pki_secret_backend_issuer.root_2024.backend
  name        = vault_pki_secret_backend_role.role_mtls.name
  common_name = "mtls-personal-10a-nico.mtls.dcotta.com"

  alt_names = []

  ttl        = 60 * 60 * 24 * 365 # 12 months
  auto_renew = true
  revoke     = true
}

resource "vault_pki_secret_backend_cert" "client-mtls-cert-hugo-v1" {
  issuer_ref  = vault_pki_secret_backend_issuer.root_2024.issuer_ref
  backend     = vault_pki_secret_backend_issuer.root_2024.backend
  name        = vault_pki_secret_backend_role.role_mtls.name
  common_name = "mtls-m1-hugo.mtls.dcotta.com"

  alt_names = []

  ttl        = 60 * 60 * 24 * 365 * 2 # 2 yrs
  auto_renew = true
  revoke     = true
}
/*
terraform output --json | jq ".cert.value.cert" -r > cert.pem
terraform output --json | jq '.cert.value.key' -r > key.rsa

openssl pkcs12 -export -in ./cert.pem -inkey ./key.rsa -out cert.pfx

rm cert.pem && rm key.rsa

 */
locals {
  cert_to_export = vault_pki_secret_backend_cert.client-mtls-cert-hugo-v1
}
output "cert" {
  value = {
    cert = "${local.cert_to_export.certificate}\n${local.cert_to_export.ca_chain}"
    key  = local.cert_to_export.private_key
  }
  sensitive = true
}
