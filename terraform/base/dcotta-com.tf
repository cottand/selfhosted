variable "com_zone_id" {
  type = string
}


module "node_miki_com" {
  cf_zone_id  = var.com_zone_id
  source      = "../modules/node"
  name        = "miki"
  ip4_mesh    = local.mesh_ip4.miki
  ip4_pub     = var.pub_ip4.miki
  ip6_pub     = var.pub_ip6.miki
  is_web_ipv4 = true
  is_web_ipv6 = true
}

resource "cloudflare_record" "nico-cname-web-com" {
  zone_id = var.com_zone_id
  name    = "nico"
  type    = "CNAME"
  value   = "miki.vps.dcotta.com"
  ttl     = 1
  comment = "tf managed"
  proxied = true
}
