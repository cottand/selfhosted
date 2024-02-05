variable "name" {
  type = string
}


resource "vault_identity_entity" "user" {
  name = var.name
  disabled = false
}

output "entity_id" {
  value = vault_identity_entity.user.id
}