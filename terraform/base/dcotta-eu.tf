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
  is_web_ipv4 = false
  is_web_ipv6 = false
}
module "node_cosmo" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "cosmo"
  ip4_pub     = local.pubIp["ip4"]["cosmo"]
  ip6_pub     = local.pubIp["ip6"]["cosmo"]
  is_web_ipv4 = false
  is_web_ipv6 = false
}

module "node_elvis" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "elvis"
  ip4_pub     = null
  ip6_pub     = local.pubIp["ip6"]["elvis"]
  is_web_ipv4 = false
  is_web_ipv6 = false
}
module "node_ari" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "ari"
  ip4_pub     = null
  ip6_pub     = local.pubIp["ip6"]["ari"]
  is_web_ipv4 = false
  is_web_ipv6 = false
}
module "node_xps2" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "xps2"
  ip4_pub     = null
  ip6_pub     = local.pubIp["ip6"]["xps2"]
  is_web_ipv4 = false
  is_web_ipv6 = false
}
module "node_ziggy" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "ziggy"
  ip4_pub     = null
  ip6_pub     = local.pubIp["ip6"]["ziggy"]
  is_web_ipv4 = false
  is_web_ipv6 = false
}
module "node_bianco" {
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = "bianco"
  ip4_pub     = null
  ip6_pub     = null
  is_web_ipv4 = false
  is_web_ipv6 = false
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
  is_web_ipv4 = true
  is_web_ipv6 = true
}

# module "nodes_oci_control_pool" {
#   for_each    = data.terraform_remote_state.metal.outputs["oci_control_pool_server_ips"]
#   cf_zone_ids = local.zoneIdsList
#   source      = "../modules/node"
#   name        = each.key
#   ip4_pub     = each.value["ipv4"]
#   ip6_pub     = each.value["ipv6"]
#   is_web_ipv4 = false
#   is_web_ipv6 = false
# }
#

# Websites


# resource "cloudflare_record" "vault-cname-mesh" {
#   zone_id = local.zoneIds["eu"]
#   name    = "vault.mesh"
#   type    = "CNAME"
#   value   = "hez1.mesh.dcotta.eu"
#   ttl     = 1
#   comment = "tf managed"
#   proxied = true
# }

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
