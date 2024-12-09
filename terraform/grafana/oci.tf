resource "oci_identity_user" "grafana" {
  description = "grafana"
  name        = "grafana"
  email       = "grafana.sa@dcotta.com"
}

resource "oci_identity_group" "metrics" {
  description = "grafana metrics"
  name        = "metrics"
}

resource "oci_identity_policy" "metrics" {
  compartment_id = local.ociRoot
  description    = "grafana metrics"
  name           = "metrics"
  statements = [
    "allow group metrics to read metrics in tenancy",
    "allow group metrics to inspect metrics in tenancy",
#     "allow group grafana to inspect metrics in compartment cottand9000",
    "allow group metrics to read compartments in tenancy",
  ]
}

resource "oci_identity_user_group_membership" "grafana" {
  group_id = oci_identity_group.metrics.id
  user_id  = oci_identity_user.grafana.id
}

data "vault_kv_secret_v2" "grafana_oci" {
  mount = "secret"
  name  = "nomad/job/grafana/oci_user"
}

resource "oci_identity_api_key" "grafana" {
  key_value = data.vault_kv_secret_v2.grafana_oci.data["publicKeyPem"]
  user_id   = oci_identity_user.grafana.id
}

resource "grafana_data_source" "oci" {
  name = "oci"
  type = "oci-metrics-datasource"
}


resource "grafana_data_source_config" "oci" {
  uid = grafana_data_source.oci.uid
  # https://github.com/oracle/oci-grafana-metrics/blob/master/docs/datasource_configuration.md
  json_data_encoded = jsonencode({
    "profile0" : "DEFAULT",
    "region0" : "eu-frankfurt-1",
    "tenancymode" : "single",
    "environment" : "local",
  })

  secure_json_data_encoded = jsonencode({
    user0 : oci_identity_user.grafana.id
    tenancy0 : local.ociTenancyOcid
    fingerprint0 : oci_identity_api_key.grafana.fingerprint
    privkey0 : data.vault_kv_secret_v2.grafana_oci.data["privateKey"]
  })
}