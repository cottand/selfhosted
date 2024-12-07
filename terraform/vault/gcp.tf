resource "google_service_account" "vault-secrets-engine" {
  account_id   = "vault-secret-engine"
  display_name = "Vault"
}

resource "google_service_account_key" "vault-secrets-engine" {
  service_account_id = google_service_account.vault-secrets-engine.id
}

# resource "google_project_iam_binding" "let-vault-create-sa-tokens" {
#   project = local.gcp.project
#   role    = "roles/iam.serviceAccountTokenCreator"
#   members = ["serviceAccount:${google_service_account.vault-secrets-engine.email}"]
# }

resource "google_project_iam_binding" "service-account-admin" {
  project = local.gcp.project
  role    = google_project_iam_custom_role.vault-sa-provisioner.id
  members = ["serviceAccount:${google_service_account.vault-secrets-engine.email}"]
}

resource "google_project_iam_custom_role" "vault-sa-provisioner" {
  # from https://github.com/devops-rob/terraform-vault-gcp-secrets-engine/blob/v0.1.2/examples/gcp_oauth_role/README.md
  permissions = [
    "iam.serviceAccountKeys.create",
    "iam.serviceAccountKeys.delete",
    "iam.serviceAccountKeys.get",
    "iam.serviceAccountKeys.list",
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.get",
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",
  ]
  role_id = "vaultServiceAccountProvisioner"
  title   = "Vault Service Accounts Provisioner"
}

resource "vault_gcp_secret_backend" "gcp" {
  path = "gcp"
  credentials = base64decode(google_service_account_key.vault-secrets-engine.private_key)

  default_lease_ttl_seconds = 60 * 60 * 6 // 6h
  max_lease_ttl_seconds = 60 * 60 * 6 // 6h
}

resource "vault_gcp_secret_roleset" "bq1" {
  backend     = vault_gcp_secret_backend.gcp.path
  project     = local.gcp.project
  roleset     = "bq1"
  secret_type = "access_token"
  binding {
    resource = "//cloudresourcemanager.googleapis.com/projects/${local.gcp.project}"
    roles = ["roles/bigquery.dataViewer"]
  }

  token_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

resource "vault_gcp_secret_roleset" "bigquery-dataviewer" {
  backend     = vault_gcp_secret_backend.gcp.path
  project     = local.gcp.project
  roleset     = "bigquery-dataviewer"
  secret_type = "access_token"
  binding {
    resource = "//cloudresourcemanager.googleapis.com/projects/${local.gcp.project}"
    roles = ["roles/bigquery.dataViewer"]
  }
  token_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

resource "vault_gcp_secret_roleset" "bigquery-jobuser" {
  backend     = vault_gcp_secret_backend.gcp.path
  project     = local.gcp.project
  roleset     = "bigquery-jobuser"
  secret_type = "access_token"
  binding {
    resource = "//cloudresourcemanager.googleapis.com/projects/${local.gcp.project}"
    roles = ["roles/bigquery.jobUser"]
  }
  token_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

resource "vault_gcp_secret_roleset" "bigquery-querier-editor" {
  backend     = vault_gcp_secret_backend.gcp.path
  project     = local.gcp.project
  roleset     = "bigquery-querier-editor"
  secret_type = "access_token"
  binding {
    resource = "//cloudresourcemanager.googleapis.com/projects/${local.gcp.project}"
    roles = [
      "roles/bigquery.jobUser",
      "roles/bigquery.dataEditor",
    ]
  }
  token_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}

resource "google_bigquery_dataset" "default" {
  dataset_id = "default"
  location   = "EU"
}