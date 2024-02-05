# similar tutorial: https://github.com/hashicorp/learn-vault-codify/blob/main/community/auth.tf

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
  
  tune {
    max_lease_ttl      = "24h"
    listing_visibility = "unauth"
  }
}

# Create admin policy
resource "vault_policy" "admin_policy" {
  name   = "admins"
  policy = file("policies/admin.hcl")
}

# Create RO admin policy
resource "vault_policy" "admin_ro_policy" {
  name   = "admins_ro"
  policy = file("policies/admin_ro.hcl")
}