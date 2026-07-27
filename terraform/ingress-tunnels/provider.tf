data "external" "keychain-bw-token" {
  program = ["keychain-get", "bitwarden/secret/m3-cli"]
}

provider "bitwarden-secrets" {
  access_token = data.external.keychain-bw-token.result.value
}

data "bitwarden-secrets_secret" "b2-access" {
  id = "eb3a4c55-862c-4258-8e4d-b48c00d79177"
}
provider "b2" {
  application_key_id = jsondecode(data.bitwarden-secrets_secret.b2-access.value)["keyID"]
  application_key    = jsondecode(data.bitwarden-secrets_secret.b2-access.value)["applicationKey"]
}

provider "vault" {
  address = local.vault_addr
  #skip_tls_verify = true
}

provider "nomad" {
  address     = "https://nomad.mesh.dcotta.eu:4646"
  skip_verify = true
}

data "bitwarden-secrets_secret" "cloudflareToken" {
  id = "cb61fe49-b13d-412c-919e-ae6ed6866a78"
}

provider "cloudflare" {
  api_token = data.bitwarden-secrets_secret.cloudflareToken.value
}

data "bitwarden-secrets_secret" "awsTfUser" {
  id = "495fba0d-82a0-46c0-8946-532a7e3e6209"
}

provider "aws" {
  region     = "eu-west-1"
  access_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["access_key"]
  secret_key = jsondecode(data.bitwarden-secrets_secret.awsTfUser.value)["secret_key"]
}
