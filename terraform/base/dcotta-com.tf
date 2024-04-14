variable "com_zone_id" {
  type = string
}

resource "cloudflare_record" "nico-cname-web" {
  zone_id = var.com_zone_id
  name    = "nico"
  type    = "CNAME"
  value   = "miki.vps.dcotta.eu"
  ttl     = 1
  comment = "tf managed"
  proxied = true
}
