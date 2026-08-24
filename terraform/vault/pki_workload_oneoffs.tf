resource "vault_pki_secret_backend_cert" "files-dcotta-com-cert" {
  issuer_ref  = vault_pki_secret_backend_issuer.workloads-intermediate_2.issuer_ref
  backend     = vault_mount.pki_workload_int.path
  name        = vault_pki_secret_backend_role.intermediate_role-workloads.name
  common_name = "files.dcotta.com"

  ttl         = 60*60*24*365*1 # 1yr
  auto_renew = true
  revoke     = true
}


resource "vault_kv_secret_v2" "files-dcotta-com-cert" {
  mount = vault_mount.kv-secret.path
  name  = "/nomad/job/cloudreve/cert"
  data_json = jsonencode({
    key   = vault_pki_secret_backend_cert.files-dcotta-com-cert.private_key
    chain = "${vault_pki_secret_backend_cert.files-dcotta-com-cert.certificate}\n${vault_pki_secret_backend_cert.files-dcotta-com-cert.ca_chain}"
    ca    = vault_pki_secret_backend_root_cert.root_2024.certificate
  })
}
