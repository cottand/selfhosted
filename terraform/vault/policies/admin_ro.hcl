path "*"
{
  capabilities = [ "read", "list", "sudo" ]
}

# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = [ "read", "list" ]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = [ "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = [ "read"]
}

# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = [ "read", "list", "sudo"]
}

# List ACL policies
path "sys/policies/acl"
{
  capabilities = [ "list"]
}

# Create and manage secrets engines broadly across Vault.
path "sys/mounts/*"
{
  capabilities = [ "read", "list"]
}

# List enabled secrets engines
path "sys/mounts"
{
  capabilities = ["read", "list"]
}

# List, create, update, and delete key/value secrets at secret/
path "secret/*"
{
  capabilities = [ "read", "list", "sudo" ]
}

# Manage transit secrets engine
path "transit/*"
{
  capabilities = [ "read", "list", "sudo"]
}

# Read health checks
path "sys/health"
{
  capabilities = ["read", "sudo"]
}