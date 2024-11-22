resource "vault_policy" "gcp-bigquery-dataviewer" {
  name   = "gcp-bigquery-dataviewer"
  policy = <<-EOT
path "/gcp/roleset/bigquery-dataviewer/token" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "gcp-bigquery-dataeditor" {
  name   = "gcp-bigquery-dataeditor"
  policy = <<-EOT
path "/gcp/roleset/bigquery-dataeditor/token" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "nomad-workloads-base" {
  name = "nomad-workloads-base"
  policy = file("policies/nomad-workloads.hcl")
}
