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