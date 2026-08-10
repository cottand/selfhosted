resource "cloudflare_mtls_certificate" "dcotta_com_mtls" {
  account_id   = local.cloudflare.account_id
  ca           = true
  certificates = file("../../certs/root_2024_ca.crt")
  name         = "dcotta_com_2024_ca"
}

locals {
  # The strings of this list make up the subdomain part (_.dcotta.com)
  # of domains that use client-side mTLS auth (via the public internet)
  #
  # Each of these needs to be accessible through cloudflare (entrypoints websecure_public or cloudflared)
  # and have a traefik host rule for `_.dcotta.com`.
  subdomains_requiring_client_mtls = toset([
    "papra",
    "immich",
  ])


  # do not edit
  full_domains_list = [for subdomain in local.subdomains_requiring_client_mtls : "${subdomain}.dcotta.com"]
}

# TODO doesn't work for some reason, do in UI
resource "cloudflare_certificate_authorities_hostname_associations" "mtls_hostnames" {
  zone_id             = local.zoneIds["com"]
  hostnames           = concat(local.full_domains_list, ["files.dcotta.com"])
  mtls_certificate_id = cloudflare_mtls_certificate.dcotta_com_mtls.id
}

resource "cloudflare_ruleset" "ingress-ruleset" {
  kind    = "zone"
  name    = "mTLS ruleset"
  phase   = "http_request_firewall_custom"
  zone_id = local.zoneIds["com"]

  rules = [
    {
      description = "Client MTLS for ${join(", ", local.subdomains_requiring_client_mtls)}"
      expression  = format("(http.host in { %s } and not cf.tls_client_auth.cert_verified)", join(" ", [for host in local.full_domains_list : "\"${host}\""]))
      action      = "block"
      ref         = "mtls_single_domain"
    },
    {

      description = "Client MTLS for safebucket (except for share paths)"
      expression  = format( <<EOT
       (http.host in { "files.dcotta.com" }
and not cf.tls_client_auth.cert_verified
and not http.request.uri.path wildcard "/assets/*"
and not http.request.uri.path wildcard "/api/v1/shares/*"
and not http.request.uri.path wildcard "/shares/*"
and not http.request.uri.path == "/config.json"
)
        EOT
      )
      action      = "block"
      ref         = "mtls_safebucket"
    }
  ]
}

