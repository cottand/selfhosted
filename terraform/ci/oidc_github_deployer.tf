resource "vault_jwt_auth_backend_role" "github_actions_deployer" {
  backend    = vault_jwt_auth_backend.jwt_github.path
  role_name  = "actions-deployer"
  user_claim = "actor"
  role_type  = "jwt"
  bound_claims = {
    repository = "cottand/selfhosted"
    # only allow running on master
    ref	= "refs/heads/master"
  }
  bound_audiences = ["https://github.com/cottand", "sigstore"]
  token_policies = [
    vault_policy.github_actions_ro.name,
    "issue-nomad-actions-job-deployer-token"
  ]
  token_max_ttl = 10 * 60
  token_ttl     = 10 * 60
}

