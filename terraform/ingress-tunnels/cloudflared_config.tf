
locals {
  # The strings of this list make up the subdomain part (_.dcotta.com)
  # of domains that use cloudflare tunnels for ingress.
  #
  # Each of these needs a corresponding traefik router that does
  # Host(`_.dcotta.com`) and uses the `cloudflared` entrypoint
  tunnels = {
    (cloudflare_zero_trust_tunnel_cloudflared.traefik.id) = {
      domains = [
        "papra",
        "immich",
        "fish",
        "web",
        # "share",
      ]
    }

    (module.tunnel-files.cloudflare_tunnel_id) = {
      domains = ["files"]
    }
  }
}

# Creates the CNAME record that routes Papra to the tunnel
resource "cloudflare_dns_record" "http_app" {
  zone_id  = local.zoneIds["com"]
  for_each = { for par in flatten([for tunnel, domains in local.tunnels : [for domain in domains.domains : ({ "domain" : domain, "tunnel" : tunnel })]]) : "${par.tunnel}-${par.domain}" => par }
  name     = each.value.domain
  content  = "${each.value.tunnel}.cfargotunnel.com"
  type     = "CNAME"
  ttl      = 1
  proxied  = true
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel-config" {
  for_each   = local.tunnels
  account_id = local.cloudflare.account_id
  tunnel_id  = each.key
  config = {
    ingress = concat(
      # for each subdomain, create a rule
      [for subdomain in each.value.domains :
        {
          hostname = "${subdomain}.dcotta.com"
          # cloudflared port defined in traefik/job.nix
          service = "https://localhost:8888"
          origin_request = {
            no_tls_verify     = true
            http2_origin      = true
            match_sn_ito_host = true
          }
      }],
      [{ service = "http_status:404" }]
    )
  }
}
