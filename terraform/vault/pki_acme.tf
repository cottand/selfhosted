
resource "vault_pki_secret_backend_config_cluster" "int-workload-config" {
  backend  = vault_mount.pki_workload_int.path
  path     = "https://vault.mesh.dcotta.eu:8200/v1/${vault_mount.pki_workload_int.path}"
  aia_path = "https://vault.mesh.dcotta.eu:8200/v1/${vault_mount.pki_workload_int.path}"
}

resource "vault_generic_endpoint" "pki_int_acme" {
  depends_on           = [vault_pki_secret_backend_role.intermediate_role-acme, vault_pki_secret_backend_config_cluster.int-workload-config]
  path                 = "${vault_mount.pki_workload_int.path}/config/acme"
  ignore_absent_fields = true
  disable_delete       = true

  data_json = jsonencode({
    enabled       = true
    allowed_roles = [vault_pki_secret_backend_role.intermediate_role-acme.name]
    dns_resolver  = "10.10.4.1:53" # same as traefik node - this is a SPOF we already had!
  })
}


resource "vault_pki_secret_backend_role" "intermediate_role-acme" {
  backend          = vault_mount.pki_workload_int.path
  issuer_ref       = vault_pki_secret_backend_issuer.workloads-intermediate.issuer_ref
  name             = "dcotta-dot-eu-acme"
  ttl              = 1292000
  max_ttl          = 1292000 # 1 months ish
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["traefik"]
  allow_subdomains = true
  generate_lease   = true
  no_store         = false
}

resource "vault_generic_endpoint" "pki_workloads_tune" {
  path                 = "sys/mounts/${vault_mount.pki_workload_int.path}/tune"
  ignore_absent_fields = true
  disable_delete       = true
  data_json            = <<EOT
{
  "allowed_response_headers": [
      "Last-Modified",
      "Location",
      "Replay-Nonce",
      "Link"
    ],
  "passthrough_request_headers": [
    "If-Modified-Since"
  ]
}
EOT
}

resource "vault_pki_secret_backend_config_urls" "pki_workloads_urls" {
  depends_on              = [vault_pki_secret_backend_config_cluster.int-workload-config]
  backend                 = vault_mount.pki_workload_int.path
  enable_templating       = true
  issuing_certificates    = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/der"]
  crl_distribution_points = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"]
  ocsp_servers            = ["{{cluster_path}}/ocsp"]
}

