// data github secret for tailscale oauth client are clickops'd
// client-id: kQwBcpvRPk11CNTRL
// in TAILSCALE_OAUTH_CLIENTID, TAILSCALE_OAUTH_CLIENTSECRET


resource "github_actions_secret" "root_ca" {
  repository  = "selfhosted"
  secret_name = "DCOTTA_ROOT_CA"
  plaintext_value = base64encode(file("../../certs/root_2024_ca.crt"))
}