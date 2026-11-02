resource "tailscale_tailnet_key" "default" {
  reusable      = true
  ephemeral     = false
  tags          = ["tag:workernode"]
  preauthorized = true
}


import {
  id = "698639a7-d836-4986-9b5a-82125ce751cb"
  to = bitwarden-secrets_secret.ts_authkey_default
}

resource "bitwarden-secrets_secret" "ts_authkey_default" {
  key        = "tailscale/authkey/default"
  value      = tailscale_tailnet_key.default.key
  project_id = var.bitwarden_project_id
}

// used in nix secret
output "tailscale_authtoken_default_bw_secret_id" {
  value = bitwarden-secrets_secret.ts_authkey_default.id
}

// sidecar nodes of the traefik job, which do not outlive their allocation
resource "tailscale_tailnet_key" "traefik" {
  reusable            = true
  ephemeral           = true
  tags                = ["tag:workercontainer"]
  preauthorized       = true
  recreate_if_invalid = "always"
}

resource "vault_kv_secret_v2" "traefik_ts_authkey" {
  mount = "secret"
  name  = "/nomad/job/traefik/tailscale"
  data_json = jsonencode({
    authkey = tailscale_tailnet_key.traefik.key
  })
  custom_metadata {
    data = {
      "tf_managed" = "true"
    }
  }
}

resource "tailscale_dns_split_nameservers" "leng_seach_paths" {
  for_each = toset([
    "traefik",
    "nomad",
    "tfk.nd",
    #     "com",
    #     "net"
  ])
  nameservers = [
    "100.92.69.51",
    "100.82.72.56",
    "100.98.28.95",
  ]
  domain = each.value
}

resource "tailscale_dns_split_nameservers" "consul_search_path" {
  nameservers = [ for oci-machine in local.oci-control-machines : data.tailscale_device.oci-control[oci-machine].addresses[0]]
  domain = "consul"
}

# Tailscale looks at port 53 but consul uses 8600
# resource "tailscale_dns_split_nameservers" "consul_search_paths" {
#   for_each = toset([
#     "service.consul",
#   ])
#   nameservers = [
#     # hez
#     "100.92.69.51",
#     "100.82.72.56",
#     "100.98.28.95",
#     # oci
#     "100.120.133.44",
#     "100.101.229.73",
#     "100.72.17.90",
#   ]
#   domain      = each.value
# }
