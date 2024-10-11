resource "tailscale_tailnet_key" "github_actions" {
  reusable      = true
  ephemeral     = true
  tags          = ["tag:ci/gha"]
  preauthorized = true
}

resource "github_actions_secret" "tailscale_authkey" {
  repository  = "cottand/selfhosted"
  secret_name = "TAILSCALE_AUTHKEY"
  plaintext_value = tailscale_tailnet_key.github_actions.key
}

