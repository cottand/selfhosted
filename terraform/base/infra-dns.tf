locals {
  oci-control-machines = toset(jsondecode(file("../metal/oci_control.json")))
}

data "tailscale_device" "oci-control" {
  for_each = local.oci-control-machines
  hostname = each.value
}

resource "cloudflare_record" "tailscale_cnames" {
  for_each = toset(["consul", "nomad", "vault"])
  zone_id = local.zoneIds["com"]
  name    = "${each.value}"
  type    = "CNAME"
  value   = "${each.value}.golden-dace.ts.net"
  ttl     = 60
  comment = "tf managed"
  proxied = false
}

