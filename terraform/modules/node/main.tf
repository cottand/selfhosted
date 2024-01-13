locals {
  dns_comment = "tf managed"
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}


resource "cloudflare_record" "node_mesh" {
  zone_id = var.cf_zone_id
  name    = "${var.name}.mesh"
  type    = "A"
  value   = var.ip4_mesh
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}


resource "cloudflare_record" "node_vps4" {
  count   = var.ip4_pub == null ? 0 : 1
  zone_id = var.cf_zone_id
  name    = "${var.name}.vps"
  type    = "A"
  value   = var.ip4_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}


resource "cloudflare_record" "node_web4" {
  count   = (var.ip4_pub != null && var.is_web_ipv4) ? 1 : 0
  zone_id = var.cf_zone_id
  name    = "web"
  type    = "A"
  value   = var.ip4_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = true
}

resource "cloudflare_record" "node_web6" {
  count   = (var.ip6_pub != null && var.is_web_ipv6) ? 1 : 0
  zone_id = var.cf_zone_id
  name    = "web"
  type    = "AAAA"
  value   = var.ip6_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = true
}

resource "cloudflare_record" "node_vps6" {
  count   = var.ip6_pub == null ? 0 : 1
  zone_id = var.cf_zone_id
  name    = "${var.name}.vps6"
  type    = "AAAA"
  value   = var.ip6_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}
