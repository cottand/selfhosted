locals {
  oci-control-machines = toset(jsondecode(file("../metal/oci_control.json")))
}

data "tailscale_device" "oci-control" {
  for_each = local.oci-control-machines
  hostname = each.value
}

resource "cloudflare_record" "vault" {
  for_each = local.oci-control-machines
  zone_id  = local.zoneIds["com"]
  name     = "vault"
  type     = "A"
  content    = data.tailscale_device.oci-control[each.value].addresses[0]
  ttl      = 60
  comment  = "tf managed"
  proxied  = false
}



resource "cloudflare_record" "tailscale_cnames" {
  // we want vault to remain manual
  for_each = toset(["consul", "nomad"])
  zone_id  = local.zoneIds["com"]
  name     = each.value
  type     = "CNAME"
  content    = "${each.value}.golden-dace.ts.net"
  ttl      = 60
  comment  = "tf managed"
  proxied  = false
}

# resource "cloudflare_record" "tailscale_as" {
#   // ts services
#   for_each = { "consul" = "100.65.55.172", "nomad" = "100.104.122.211", "vault" = "100.115.117.202" }
#   zone_id  = local.zoneIds["com"]
#   name     = each.key
#   type     = "A"
#   value    = "${each.value}"
#   ttl      = 60
#   comment  = "tf managed"
#   proxied  = false
# }
#
