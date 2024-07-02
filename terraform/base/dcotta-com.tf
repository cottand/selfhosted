
resource "cloudflare_record" "nico-cname-web-com" {
  zone_id = local.zoneIds["com"]
  name    = "nico"
  type    = "CNAME"
  value   = "miki.vps.dcotta.com"
  ttl     = 1
  comment = "tf managed"
  proxied = true
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
