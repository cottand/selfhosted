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


resource "cloudflare_record" "node_vps4" {
  count   = var.ip4_pub == null ? 0 : length(var.cf_zone_ids)
  zone_id = var.cf_zone_ids[count.index]
  name    = "${var.name}.vps"
  type    = "A"
  value   = var.ip4_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}


resource "cloudflare_record" "node_web4" {
  count   = (var.ip4_pub != null && var.is_web_ipv4) ? length(var.cf_zone_ids) : 0
  zone_id = var.cf_zone_ids[count.index]
  name    = "web"
  type    = "A"
  value   = var.ip4_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = true
}

resource "cloudflare_record" "node_web6" {
  count   = (var.ip6_pub != null && var.is_web_ipv6) ? length(var.cf_zone_ids) : 0
  zone_id = var.cf_zone_ids[count.index]
  name    = "web"
  type    = "AAAA"
  value   = var.ip6_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = true
}

resource "cloudflare_record" "node_vps6" {
  count   = var.ip6_pub == null ? 0 : length(var.cf_zone_ids)
  zone_id = var.cf_zone_ids[count.index]
  name    = "${var.name}.vps6"
  type    = "AAAA"
  value   = var.ip6_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}
