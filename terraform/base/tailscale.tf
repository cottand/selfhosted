resource "tailscale_tailnet_key" "default" {
  reusable      = true
  ephemeral     = false
  tags          = ["tag:workernode"]
  preauthorized = true
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
  domain      = each.value
}
