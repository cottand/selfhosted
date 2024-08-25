path "secret/data/services/db-rw-default" {
  capabilities = ["read"]
}
path "secret/data/services/db-rw-default/*" {
  capabilities = ["read"]
}
