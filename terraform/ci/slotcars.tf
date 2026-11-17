// cottand/slotcars triggers .github/workflows/slotcars.yml here, which checks
// slotcars out, builds it with nix and deploys it to Cloudflare Pages.

resource "tls_private_key" "slotcars_deploy_key" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "slotcars_selfhosted_ci" {
  repository = "slotcars"
  title      = "cottand/selfhosted CI (read-only)"
  key        = tls_private_key.slotcars_deploy_key.public_key_openssh
  read_only  = true
}

resource "github_actions_secret" "slotcars_deploy_key" {
  repository      = "selfhosted"
  secret_name     = "SLOTCARS_DEPLOY_KEY"
  plaintext_value = tls_private_key.slotcars_deploy_key.private_key_openssh
}

// GitHub has no API to mint personal access tokens, so this one is clickops'd:
// a fine-grained token scoped to cottand/selfhosted with "Actions: Read and write",
// stored in Bitwarden Secrets Manager.
data "bitwarden-secrets_secret" "selfhosted_dispatch_token" {
  id = "839a8866-90a3-4c87-b383-b505015d58c6"
}

resource "github_actions_secret" "slotcars_selfhosted_dispatch_token" {
  repository      = "slotcars"
  secret_name     = "SELFHOSTED_DISPATCH_TOKEN"
  plaintext_value = data.bitwarden-secrets_secret.selfhosted_dispatch_token.value
}
