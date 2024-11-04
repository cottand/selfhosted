resource "oci_identity_user" "grafana" {
  description = ""
  name        = "grafana"
}

resource "oci_identity_group" "metrics" {
  description = "grafana"
  name        = "metrics"

}

resource "oci_identity_policy" "metrics" {
  compartment_id = local.ociRoot
  description    = ""
  name           = "metrics"
  statements = [
    "allow group grafana to read metrics in tenancy",
    "allow group grafana to read compartments in tenancy",
  ]
}
