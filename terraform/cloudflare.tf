# nico.dcotta.eu

variable "zone_id" {
  type    = string
}

variable "pub_ip4" {
  type = map(string)
}



resource "cloudflare_record" "nico-miki" {
  zone_id = var.zone_id
  name    = "nico"
  type    = "A"
  value   = var.pub_ip4.miki
  ttl     = 1
  comment = "tf managed"
  proxied = true
}
resource "cloudflare_record" "nico-cosmo" {
  zone_id = var.zone_id
  name    = "nico"
  type    = "A"
  value   = var.pub_ip4.cosmo
  ttl     = 1
  comment = "tf managed"
  proxied = true
}
resource "cloudflare_record" "nico-maco" {
  zone_id = var.zone_id
  name    = "nico"
  type    = "A"
  value   = var.pub_ip4.maco
  ttl     = 1
  comment = "tf managed"
  proxied = true
}


resource "cloudflare_record" "lemmy-miki" {
  zone_id = var.zone_id
  name    = "r"
  type    = "A"
  value   = var.pub_ip4.miki
  ttl     = 1
  comment = "tf managed"
  proxied = true
}
resource "cloudflare_record" "lemmy-maco" {
  zone_id = var.zone_id
  name    = "r"
  type    = "A"
  value   = var.pub_ip4.maco
  ttl     = 1
  comment = "tf managed"
  proxied = true
}