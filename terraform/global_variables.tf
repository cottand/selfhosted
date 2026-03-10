locals {
  vault_addr = "https://${local.vault_host}"
  vault_host  = "vault.dcotta.com:8200"

  nomad_addr = "https://nomad.dcotta.com"
#   vault_host  = "inst-kzsrv-control.golden-dace.ts.net:8200"

  gcp = {
    project = "dcotta-com"
    region = "europe-west3"
  }

  oci = {
    tenancyOcid = "ocid1.tenancy.oc1..aaaaaaaa5umazgc4ircdizxgjixccyal2nkmemxnpzcrwgwjsrzcz4omw32q"
  }
}