locals {
  dns_comment = "tf managed"
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}


resource "cloudflare_dns_record" "node_vps4" {
  count   = !var.do_ip4_pub ? 0 : length(var.cf_zone_ids)
  zone_id = var.cf_zone_ids[count.index]
  name    = "${var.name}.vps"
  type    = "A"
  content   = var.ip4_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}


resource "cloudflare_dns_record" "node_vps6" {
  count   = !var.do_ip6_pub ? 0 : length(var.cf_zone_ids)
  zone_id = var.cf_zone_ids[count.index]
  name    = "${var.name}.vps6"
  type    = "AAAA"
  content   = var.ip6_pub
  ttl     = 1
  comment = local.dns_comment
  proxied = false
}
moved {
  from = cloudflare_record.node_vps4
  to   = cloudflare_dns_record.node_vps4
}
moved {
  from = cloudflare_record.node_vps6
  to   = cloudflare_dns_record.node_vps6
}
