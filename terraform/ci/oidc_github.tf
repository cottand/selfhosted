resource "vault_jwt_auth_backend" "jwt_github" {
  description        = "Github JWT"
  path               = "jwt-github"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}

resource "vault_jwt_auth_backend_role" "github_actions" {
  backend    = vault_jwt_auth_backend.jwt_github.path
  role_name  = "actions-ro"
  user_claim = "actor"
  role_type  = "jwt"
  bound_claims = {
    repository = "cottand/selfhosted"
  }
  bound_audiences = ["https://github.com/cottand", "sigstore"]
  token_policies = [vault_policy.github_actions_ro.name]
  token_max_ttl = 10 * 60
  token_ttl     = 10 * 60
}

resource "vault_policy" "github_actions_ro" {
  name   = "github-actions-ro"
  policy = data.vault_policy_document.github_actions_ro.hcl
}

data "vault_policy_document" "github_actions_ro" {
  rule {
    description = "Read secrets in github-actions/"
    path        = "secret/data/github-actions/*"
    capabilities = ["read"]
  }
  rule {
    description = "Read attic user for github-actions"
    path        = "secret/data/nomad/job/attic/users/github-actions"
    capabilities = ["read"]
  }
}