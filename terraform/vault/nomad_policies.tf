resource "vault_policy" "gcp-bigquery-dataviewer" {
  name   = "gcp-bigquery-dataviewer"
  policy = <<-EOT
path "/gcp/roleset/${vault_gcp_secret_roleset.bigquery-dataviewer.roleset}/token" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "gcp-bigquery-querier-editor" {
  name   = "gcp-bigquery-dataeditor"
  policy = <<-EOT
path "/gcp/roleset/${vault_gcp_secret_roleset.bigquery-querier-editor.roleset}/token" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "nomad-workloads-base" {
  name = "nomad-workloads-base"
  policy = file("policies/nomad-workloads.hcl")
}

resource "vault_policy" "services-all-secrets-ro" {
  name   = "services-all-secrets-ro"
  policy = <<-EOT
path "secret/data/services" {
  capabilities = ["read"]
}

path "secret/data/services/*" {
  capabilities = ["read"]
}
EOT
}
