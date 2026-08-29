// How CI logs in
locals {
  vault_auth_jtw_github_backend_path = "jwt-github"
}

data "vault_auth_backend" "jwt-github" {
  path = local.vault_auth_jtw_github_backend_path
}

// we alias that logged-in identity to the github-actions entity
resource "vault_identity_entity_alias" "nomad-in-vault" {
  canonical_id   = vault_identity_entity.github_actions.id
  name           = "cottand"
  mount_accessor = data.vault_auth_backend.jwt-github.accessor
}

// -- a role in the /nomad mount that has a policy that allows it to acquire a nomad role called github actions
resource "vault_nomad_secret_role" "github-actions" {
  backend = local.vault_nomad_backend_name
  role    = "github-actions"
  type = "client"
  policies = [nomad_acl_policy.job-planner.name]
}

data "vault_policy_document" "be-nomad-github-actions" {
  rule {
    capabilities = ["read"]
    path = "${local.vault_nomad_backend_name}/creds/${nomad_acl_role.github-actions.name}"
  }
}
resource "vault_policy" "be-nomad-github-actions" {
  name   = "issue-nomad-job-planner-token"
  policy = data.vault_policy_document.be-nomad-github-actions.hcl
}

resource "vault_identity_entity" "github_actions" {
  name = "github-actions"

  policies = [vault_policy.be-nomad-github-actions.id]
}

