
# resource "cloudflare_record" "nico-cname-web-com" {
#   zone_id = local.zoneIds["com"]
#   name    = "nico"
#   type    = "CNAME"
#   value   = "web.dcotta.com"
#   ttl     = 1
#   comment = "tf managed"
#   proxied = true
# }








# resource "cloudflare_load_balancer" "web-dcotta-com" {
#   default_pool_ids = []
#   fallback_pool_id = ""
#   name             = "web"
#   zone_id          = local.zoneIds["com"]
# }
#
# resource "cloudflare_load_balancer_pool" "hetzner-origins" {
#   account_id = l
#   name       = ""
# }
# cloudflare cannot do 2-level deep subdomains, so we cannot do a wildcard like *.web.dcotta.com
resource "cloudflare_dns_record" "immich-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "immich"
  type    = "CNAME"
  ttl     = 1
  comment = "tf managed"
  proxied = true
  content = "web.dcotta.com"
}

moved {
  from = cloudflare_record.immich-cname-web-com
  to   = cloudflare_dns_record.immich-cname-web-com
}

resource "cloudflare_dns_record" "ente-locker-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "ente-locker"
  type    = "CNAME"
  ttl     = 1
  comment = "tf managed"
  proxied = true
  content = "web.dcotta.com"
}

moved {
  from = cloudflare_record.ente-locker-cname-web-com
  to   = cloudflare_dns_record.ente-locker-cname-web-com
}

resource "cloudflare_dns_record" "ente-api-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "ente-api"
  type    = "CNAME"
  ttl     = 1
  comment = "tf managed"
  proxied = true
  content = "web.dcotta.com"
}

moved {
  from = cloudflare_record.ente-api-cname-web-com
  to   = cloudflare_dns_record.ente-api-cname-web-com
}

resource "cloudflare_dns_record" "fish-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "fish"
  type    = "CNAME"
  ttl     = 1
  comment = "tf managed"
  proxied = true
  content = "web.dcotta.com"
}

moved {
  from = cloudflare_record.fish-cname-web-com
  to   = cloudflare_dns_record.fish-cname-web-com
}

resource "cloudflare_dns_record" "wildcard-sh-com-1" {
  zone_id = local.zoneIds["com"]
  name    = "*.sh"
  type    = "A"
  ttl     = 60
  comment = "tf managed"
  proxied = false
  content = "100.82.72.56"
}

moved {
  from = cloudflare_record.wildcard-sh-com-1
  to   = cloudflare_dns_record.wildcard-sh-com-1
}

resource "cloudflare_dns_record" "wildcard-sh-com-2" {
  zone_id = local.zoneIds["com"]
  name    = "*.sh"
  type    = "A"
  ttl     = 60
  comment = "tf managed"
  proxied = false
  content = "100.92.69.51"
}

moved {
  from = cloudflare_record.wildcard-sh-com-2
  to   = cloudflare_dns_record.wildcard-sh-com-2
}

resource "cloudflare_dns_record" "google-indexing-proof" {
  zone_id = local.zoneIds["com"]
  name    = "nico"
  type    = "TXT"
  ttl     = 60
  comment = "tf managed"
  proxied = false
  content = "google-site-verification=3DytB_MQQoFUCGGA1OqjcHyg9ir5DDWDcok4YRAA5zU"
}

moved {
  from = cloudflare_record.google-indexing-proof
  to   = cloudflare_dns_record.google-indexing-proof
}
