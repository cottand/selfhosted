locals {
  hez_server_ips = {
    for i in range(3) : hcloud_server.hez1[i].name => {
      ipv4 = hcloud_server.hez1[i].ipv4_address
      ipv6 = hcloud_server.hez1[i].ipv6_address
    }
  }
  server_ips = merge(local.hez_server_ips, local.oci_servers_ips)
}

// used in /base to create DNS records
output "hez_server_ips" {
  value = local.hez_server_ips
}

output "oci_control_pool_server_ips" {
  value = local.oci_servers_ips
}

# TODO ADAPT DNS

resource "bitwarden-secrets_secret" "ips" {
  key        = "hetzner/hez/ips"
  value      = jsonencode(local.hez_server_ips)
  project_id = var.bitwarden_project_id
}

output "bitwarden_ips_id" {
  value = bitwarden-secrets_secret.ips.id
}
