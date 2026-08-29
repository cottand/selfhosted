// How CI logs in
locals {
  vault_auth_jtw_github_backend_path = "jwt-github"
}

data "vault_auth_backend" "jwt-github" {
  path = local.vault_auth_jtw_github_backend_path
}

// -- a role in the /nomad mount that has a policy that allows it to acquire a nomad role called github actions
//
// This looks like a Nomad role (groups Nomad policies for a principal), but it is defined in Vault's domain,
// so it is not a nomad_acl_role
resource "vault_nomad_secret_role" "github-actions" {
  backend = local.vault_nomad_backend_name
  role    = "github-actions"
  type = "client"
  policies = [nomad_acl_policy.job-planner.name]
}

data "vault_policy_document" "be-nomad-github-actions" {
  rule {
    capabilities = ["read"]
    path = "${local.vault_nomad_backend_name}/creds/${vault_nomad_secret_role.github-actions.id}"
  }
}
resource "vault_policy" "be-nomad-github-actions" {
  name   = "issue-nomad-job-planner-token"
  policy = data.vault_policy_document.be-nomad-github-actions.hcl
}


