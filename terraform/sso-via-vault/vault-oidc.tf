data "vault_identity_entity" "nico" {
  entity_name = "nico"
}

resource "vault_identity_group" "group" {
  name = "admins"
  member_entity_ids = [data.vault_identity_entity.nico.id]
}


data "vault_auth_backend" "userpass" {
  path = "userpass"
}

resource "vault_identity_oidc_assignment" "assign-admins" {
  name = "admins-assignment"
  entity_ids = [
    data.vault_identity_entity.nico.id,
  ]
  group_ids = [
    vault_identity_group.group.id,
  ]
}

resource "vault_identity_oidc_key" "key1" {
  name             = "key1"
  allowed_client_ids = ["*"]
  verification_ttl = 6 * 60 * 60
  rotation_period  = 1 * 60 * 60
  algorithm        = "RS256"
}

resource "vault_identity_oidc_client" "nomad" {
  name = "nomad"
  redirect_uris = [
    "${local.vault_addr}/ui/settings/tokens",
    "https://nomad.traefik/ui/settings/tokens",
    "https://nomad.traefik/oidc/callback",
    "https://nomad.traefik/ui/settings/tokens",
    "http://localhost:4649/oidc/callback",
  ]
  assignments = [
    "allow_all"
    # vault_identity_oidc_assignment.assign-admins.name
  ]

  key              = vault_identity_oidc_key.key1.name
  id_token_ttl     = 30 * 60
  access_token_ttl = 1 * 60 * 60
}

resource "vault_identity_oidc_client" "immich" {
  name = "immich"
  redirect_uris = [
    "app.immich:///oauth-callback",
    "${local.vault_addr}/ui/settings/tokens",
    "${var.immich_addr}/auth/login",
    "${var.immich_addr}/user-settings",
  ]
  assignments = [
    "allow_all"
    # vault_identity_oidc_assignment.assign-admins.name
  ]

  key              = vault_identity_oidc_key.key1.name
  id_token_ttl     = 30 * 60
  access_token_ttl = 6 * 60 * 60
}

resource "vault_identity_oidc_scope" "user" {
  name        = "user"
  description = "The user scope provides claims using Vault identity entity metadata"
  template    = <<EOT
  {"username": {{identity.entity.name}}}
  EOT
}

resource "vault_identity_oidc_scope" "email" {
  name        = "email"
  description = "The user scope provides claims using Vault identity entity metadata"
  template    = <<EOT
  {"email": {{identity.entity.metadata.email}}}
  EOT
}

resource "vault_identity_oidc_scope" "groups" {
  name        = "groups"
  description = "The groups scope provides the groups claim using Vault group membership"
  template    = (<<EOT
  {"groups": {{identity.entity.groups.names}}}
  EOT
  )
}
resource "vault_identity_oidc_provider" "provider" {
  issuer_host   = local.vault_host
  https_enabled = true
  name          = "default-provider"
  allowed_client_ids = [
    vault_identity_oidc_client.nomad.client_id,
    vault_identity_oidc_client.immich.client_id,
  ]
  scopes_supported = [
    vault_identity_oidc_scope.groups.name,
    vault_identity_oidc_scope.user.name,
    vault_identity_oidc_scope.email.name
  ]
}

resource "vault_kv_secret_v2" "immich_oidc_settings" {
  mount = "secret"
  name  = "/nomad/job/immich/vault_oidc"
  data_json = jsonencode({
    client_id     = vault_identity_oidc_client.immich.client_id
    client_secret = vault_identity_oidc_client.immich.client_secret
    issuer_url    = vault_identity_oidc_provider.provider.issuer
  })
}

