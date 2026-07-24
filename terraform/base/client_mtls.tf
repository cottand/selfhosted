
resource "cloudflare_mtls_certificate" "dcotta_com_mtls" {
  account_id   = "a0668acd2601331c666d054c71470a40"
  ca           = true
  certificates = file("../../certs/root_2024_ca.crt")
  name         = "dcotta_com_2024_ca"
}

# TODO doesn't work for some reason, do in UI
# resource "cloudflare_certificate_authorities_hostname_associations" "papra_dcotta_com" {
#   zone_id             = local.zoneIds["com"]
#   hostnames           = ["papra.dcotta.com"]
#   mtls_certificate_id = cloudflare_mtls_certificate.dcotta_com_mtls.id
# }
resource "cloudflare_dns_record" "papra-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "papra"
  type    = "CNAME"
  ttl     = 1
  comment = "tf managed"
  proxied = true
  content = "web.dcotta.com"
}

resource "cloudflare_ruleset" "mtls_papra" {
  kind    = "zone"
  name    = "mTLS ruleset"
  phase   = "http_request_firewall_custom"
  zone_id = local.zoneIds["com"]

  rules = [{
    description = "Papra MTLS"
    expression  = "(http.host in {\"papra.dcotta.com\"} and not cf.tls_client_auth.cert_verified)"
    action      = "block"
    ref         = "mtls_papra"
  }]
}


moved {
  from = cloudflare_record.papra-cname-web-com
  to   = cloudflare_dns_record.papra-cname-web-com
}
