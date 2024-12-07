locals {
  oci-control-machines = toset(jsondecode(file("../metal/oci_control.json")))
}

data "tailscale_device" "oci-control" {
  for_each = local.oci-control-machines
  hostname = each.value
}

resource "cloudflare_record" "vault" {
  for_each = local.oci-control-machines
  name    = "vault"
  type    = "A"
  zone_id = local.zoneIds["com"]
  value = data.tailscale_device.oci-control[each.value].addresses[0]
}

resource "cloudflare_record" "nomad" {
  for_each = local.oci-control-machines
  name    = "nomad"
  type    = "A"
  zone_id = local.zoneIds["com"]
  value = data.tailscale_device.oci-control[each.value].addresses[0]
}
