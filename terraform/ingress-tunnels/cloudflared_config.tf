
locals {
  # The strings of this list make up the subdomain part (_.dcotta.com)
  # of domains that use cloudflare tunnels for ingress.
  #
  # Each of these needs a corresponding traefik router that does
  # Host(`_.dcotta.com`) and uses the `cloudflared` entrypoint
  dcotta_com_subdomains_ingress_via_cloudflared = toset([
    "papra",
    "immich",
    "files",
    "fish",
  ])
}

# Creates the CNAME record that routes Papra to the tunnel
resource "cloudflare_dns_record" "http_app" {
  zone_id  = local.zoneIds["com"]
  for_each = local.dcotta_com_subdomains_ingress_via_cloudflared
  name     = each.value
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.traefik.id}.cfargotunnel.com"
  type     = "CNAME"
  ttl      = 1
  proxied  = true
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "traefik-config" {
  account_id = local.cloudflare.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.traefik.id
  config = {
    ingress = concat(
      # for each subdomain, create a rule
      [for subdomain in local.dcotta_com_subdomains_ingress_via_cloudflared :
        {
          hostname = "${subdomain}.dcotta.com"
          # cloudflared port defined in traefik/job.nix
          service = "https://localhost:8888"
          origin_request = {
            no_tls_verify = true
            http2_origin  = true
          }
      }],
      [{ service = "http_status:404" }]
    )
  }
}
