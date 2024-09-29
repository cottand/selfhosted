variable "name" {
  type = string
}

variable "email" {
  type = string
}


resource "vault_identity_entity" "user" {
  name     = var.name
  disabled = false
  metadata = {
    terraform = "true"
    email     = var.email
  }
}

output "entity_id" {
  value = vault_identity_entity.user.id
}

output "name" {
  value = var.name
}