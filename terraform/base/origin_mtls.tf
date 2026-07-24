resource "cloudflare_authenticated_origin_pulls" "dcotta-com" {
  zone_id = local.zoneIds["com"]
  config =[{

  }]
}

resource "cloudflare_authenticated_origin_pulls_certificate" "vault-issued-cloudflare-client" {
  certificate = ""
  private_key = ""
  zone_id     = ""
}

resource "cloudflare_authenticated_origin_pulls_settings" "zone-wide-config" {
  zone_id = local.zoneIds["com"]
  enabled     = false
}

resource "vault_pki_secret_backend_cert" "" {
  backend     = ""
  common_name = ""
  name        = ""
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
