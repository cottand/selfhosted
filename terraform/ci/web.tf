resource "tailscale_tailnet_key" "github_actions" {
  reusable      = true
  ephemeral     = true
#   tags          = ["tag:ci"]
  preauthorized = true
}


resource "github_actions_secret" "tailscale_authkey" {
  repository  = "selfhosted"
  secret_name = "TAILSCALE_AUTHKEY"
  plaintext_value = tailscale_tailnet_key.github_actions.key
}

resource "github_actions_secret" "root_ca" {
  repository  = "selfhosted"
  secret_name = "DCOTTA_ROOT_CA"
  plaintext_value = base64encode(file("../../certs/root_2024_ca.crt"))
}