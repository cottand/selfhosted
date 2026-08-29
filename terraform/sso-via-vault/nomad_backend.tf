
// TODO is clickops'd, as it has the nomad management token otherwise
# resource "vault_nomad_secret_backend" "nomad" {
#   token = "_"
#   backend = "nomad"
#   description = "Issues short-lived nomad tokens - not for human use via OIDC"
#   address = local.nomad_addr
#   default_lease_ttl_seconds = 1 * local.time_hours
#   max_lease_ttl_seconds = 1 * local.time_hours
#   ttl = 1 * local.time_hours
# }

locals {
  vault_nomad_backend_name = "nomad"
}
