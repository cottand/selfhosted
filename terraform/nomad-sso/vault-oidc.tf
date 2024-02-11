data "vault_identity_entity" "nico" {
  entity_name = "nico"
  # entity_id = "ee9f9ce4-870d-e761-9eea-5ba740369d3a"
}

# resource "vault_identity_entity" "nico" {
#   name     = "nicodcotta"
#   disabled = false
# }

resource "vault_identity_group" "group" {
  name              = "admins"
  member_entity_ids = [data.vault_identity_entity.nico.id]
}


# resource "vault_identity_entity_alias" "nico" {
#   name           = "nicodcotta"
#   canonical_id   = vault_identity_entity.nico.id
#   mount_accessor = data.vault_auth_backend.userpass.accessor
# }


data "vault_auth_backend" "userpass" {
  path = "userpass"
}

resource "vault_identity_oidc_assignment" "assign-admins" {
  name       = "admins-assignment"
  entity_ids = [
    data.vault_identity_entity.nico.id,
    ]
  group_ids  = [
    vault_identity_group.group.id,
    ]
}

resource "vault_identity_oidc_key" "key1" {
  name               = "key1"
  allowed_client_ids = ["*"]
  verification_ttl   = 3 * 60 * 60
  rotation_period    = 1 * 60 * 60
  algorithm          = "RS256"
}

resource "vault_identity_oidc_client" "nomad" {
  name = "nomad"
  redirect_uris = [
    "https://nomad.mesh.dcotta.eu:4646/oidc/callback",
    "${var.vault_addr}/ui/settings/tokens",
    "https://nomad.traefik/ui/settings/tokens",
    "https://nomad.mesh.dcotta.eu:4646/ui/settings/tokens",
    "https://nomad.traefik/oidc/callback",
    "https://nomad.traefik/ui/settings/tokens",
    "https://openidconnect.net/callback",
    "http://localhost:4649/oidc/callback",
  ]
  assignments      = [
    "allow_all"
    # vault_identity_oidc_assignment.assign-admins.name
    ]

  key              = vault_identity_oidc_key.key1.name
  id_token_ttl     = 30 * 60
  access_token_ttl = 1 * 60 * 60
}

resource "vault_identity_oidc_scope" "user" {
  name        = "user"
  description = "The user scope provides claims using Vault identity entity metadata"
  template = <<EOT
  {"username": {{identity.entity.name}}}
  EOT
}

resource "vault_identity_oidc_scope" "groups" {
  name        = "groups"
  description = "The groups scope provides the groups claim using Vault group membership"
  template = (<<EOT
  {"groups": {{identity.entity.groups.names}}}
  EOT
  )
}
resource "vault_identity_oidc_provider" "provider" {
  issuer_host        = "vault.mesh.dcotta.eu:8200"
  https_enabled      = true
  name               = "default-provider"
  allowed_client_ids = [vault_identity_oidc_client.nomad.client_id]
  scopes_supported   = [
    vault_identity_oidc_scope.groups.name,
     vault_identity_oidc_scope.user.name,
     ]
     
}

