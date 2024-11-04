# https://developer.hashicorp.com/nomad/tutorials/single-sign-on/sso-oidc-vault

resource "nomad_acl_policy" "admin" {
  name = "admin"
  rules_hcl = file("policies/admin.hcl")
}

resource "nomad_acl_role" "admin" {
  name = "admin"
  policy {
    name = nomad_acl_policy.admin.name
  }
}

#  nomad acl auth-method create \
#     -default=true \
#     -name=vault \
#     -token-locality=global \
#     -max-token-ttl="10m" \
#     -type=oidc \
#     -config @acl_auth_method.json

resource "nomad_acl_auth_method" "vault" {
  default        = true
  name           = "Vault"
  token_locality = "global"
  max_token_ttl  = "6h0m0s"
  type           = "OIDC"

  config {
    signing_algs = ["RS256", "EdDSA"]
    oidc_discovery_url = "${local.vault_addr}/v1/identity/oidc/provider/${vault_identity_oidc_provider.provider.name}"

    oidc_client_id = vault_identity_oidc_client.nomad.client_id
    bound_audiences = [vault_identity_oidc_client.nomad.client_id]

    oidc_scopes = ["groups", "name"]

    claim_mappings = {
      name         = "name"
      "default-ro" = "roles"
    }
    list_claim_mappings = {
      "groups" = "roles"
    }

    oidc_client_secret = vault_identity_oidc_client.nomad.client_secret

    allowed_redirect_uris = [
      "https://nomad.traefik/oidc/callback",
      "https://nomad.traefik/ui/settings/tokens",
      "http://localhost:4649/oidc/callback",
    ]
  }
}

#  nomad acl binding-rule create \
#     -auth-method=vault \
#     -bind-type=role \
#     -bind-name="engineering-read" \
#     -selector="engineering in list.roles"


resource "nomad_acl_binding_rule" "bind-admin" {
  # bind_name = nomad_acl_role.admin.name
  bind_name   = ""
  bind_type   = "management"
  selector    = "admins in list.roles"
  auth_method = nomad_acl_auth_method.vault.name
}