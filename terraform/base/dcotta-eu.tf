locals {
  zoneIds     = jsondecode(data.bitwarden-secrets_secret.zoneIds.value)
  zoneIdsList = [local.zoneIds["eu"], local.zoneIds["com"]]
  pubIp       = jsondecode(data.bitwarden-secrets_secret.pubIps.value)
}


## Discovery

module "node_miki" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "miki"
  ip4_pub     = local.pubIp["ip4"]["miki"]
  ip6_pub     = local.pubIp["ip6"]["miki"]

  do_ip4_pub = true
  do_ip6_pub = true
}
module "node_cosmo" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "cosmo"
  ip4_pub     = local.pubIp["ip4"]["cosmo"]
  ip6_pub     = local.pubIp["ip6"]["cosmo"]
  do_ip4_pub = true
  do_ip6_pub = true
}

module "node_ari" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "ari"
  ip4_pub     = null
  ip6_pub     = local.pubIp["ip6"]["ari"]

  do_ip4_pub = false
  do_ip6_pub = true
}
module "node_xps2" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "xps2"
  ip4_pub     = null
  ip6_pub     = local.pubIp["ip6"]["xps2"]

  do_ip4_pub = false
  do_ip6_pub = true
}

module "node_bianco" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "bianco"
  ip4_pub     = null
  ip6_pub     = null
  do_ip4_pub = false
  do_ip6_pub = false
}

module "nodes_hz" {
  for_each = {
    for name in ["hez1", "hez2", "hez3"] : name => data.terraform_remote_state.metal.outputs["hez_server_ips"][name]
  }
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = each.key
  ip4_pub     = each.value["ipv4"]
  ip6_pub     = each.value["ipv6"]

  do_ip4_pub = true
  do_ip6_pub = true
}

resource "cloudflare_record" "nico-cname-web" {
  zone_id = local.zoneIds["eu"]
  name    = "nico"
  type    = "CNAME"
  value   = "hez1.vps.dcotta.eu"
  ttl     = 1
  comment = "tf managed"
  proxied = true
}

resource "cloudflare_record" "lemmy-cname-web" {
  zone_id = local.zoneIds["eu"]
  name    = "r"
  type    = "CNAME"
  value   = "web.dcotta.eu"
  ttl     = 1
  comment = "tf managed"
  proxied = true
}
