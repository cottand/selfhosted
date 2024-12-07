resource "vault_policy" "nomad-workload-roach" {
  policy = "${file("policies/nomad-workloads.hcl")}\n${file("policies/roach.hcl")}"
  name   = "roach"
}

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

resource "vault_policy" "services-all-secrets-read" {
  name   = "services-all-secrets-read"
  policy = data.vault_policy_document.services-all-secrets-read.hcl
}

data "vault_policy_document" "services-all-secrets-read" {
  rule {
    path = "secret/data/services"
    capabilities = ["read"]
  }
  rule {
    path = "secret/data/services/*"
    capabilities = ["read"]
  }
}


resource "vault_policy" "service-self-secrets-read" {
  name   = "service-self-secrets-read"
  policy = data.vault_policy_document.services-self-secrets-read.hcl
}
data "vault_policy_document" "services-self-secrets-read" {
  rule {
    path = "secret/data/services/{{identity.entity.aliases.${vault_jwt_auth_backend.jwt-nomad.accessor}.metadata.nomad_job_id}}"
    capabilities = ["read"]
  }
  rule {
    path = "secret/data/services/{{identity.entity.aliases.${vault_jwt_auth_backend.jwt-nomad.accessor}.metadata.nomad_job_id}}/*"
    #                            ^^^^^^^^^^^^^^^^^^^
    # this resolves to the name of the nomad job
    capabilities = ["read"]
  }
}


resource "vault_policy" "vault-backup-maker" {
  name   = "vault-backup-maker"
  policy = data.vault_policy_document.vault-backup-maker.hcl
}
data "vault_policy_document" "vault-backup-maker" {
  rule {
    path = "sys/storage/raft/snapshot"
    capabilities = ["read"]
  }
  rule {
    path = "sys/ha-status"
    capabilities = ["read"]
  }
}