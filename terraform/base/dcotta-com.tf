
# resource "cloudflare_record" "nico-cname-web-com" {
#   zone_id = local.zoneIds["com"]
#   name    = "nico"
#   type    = "CNAME"
#   value   = "web.dcotta.com"
#   ttl     = 1
#   comment = "tf managed"
#   proxied = true
# }

# cloudflare cannot do 2-level deep subdomains, so we cannot do a wildcard like *.web.dcotta.com
resource "cloudflare_record" "immich-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "immich"
  type    = "CNAME"
  value   = "web.dcotta.com"
  ttl     = 1
  comment = "tf managed"
  proxied = true
}

resource "cloudflare_record" "fish-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "fish"
  type    = "CNAME"
  value   = "web.dcotta.com"
  ttl     = 1
  comment = "tf managed"
  proxied = true
}


resource "cloudflare_record" "wildcard-sh-com-1" {
  zone_id = local.zoneIds["com"]
  name    = "*.sh"
  type    = "A"
  value   = "100.82.72.56"
  ttl     = 60
  comment = "tf managed"
  proxied = false
}

resource "cloudflare_record" "wildcard-sh-com-2" {
  zone_id = local.zoneIds["com"]
  name    = "*.sh"
  type    = "A"
  value   = "100.92.69.51"
  ttl     = 60
  comment = "tf managed"
  proxied = false
}

resource "cloudflare_record" "google-indexing-proof" {
  zone_id = local.zoneIds["com"]
  name    = "nico"
  type    = "TXT"
  value   = "google-site-verification=3DytB_MQQoFUCGGA1OqjcHyg9ir5DDWDcok4YRAA5zU"
  ttl     = 60
  comment = "tf managed"
  proxied = false
}

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