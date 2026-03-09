

// --- vault ---
resource "vault_identity_entity" "nomad_entity" {
  name = "github-actions"
}

resource "vault_identity_group" "nomad_group" {
  member_entity_ids = [vault_identity_entity.nomad_entity]
}

# TODO pickup if we want to issue nomad tokens to gha
# resource "vault_nomad_secret_backend" "nomad" {
#   backend = "nomad"
#   default_lease_ttl_seconds = 60 * 5
#   max_lease_ttl_seconds = 60 * 5
# }

// --- nomad ---

