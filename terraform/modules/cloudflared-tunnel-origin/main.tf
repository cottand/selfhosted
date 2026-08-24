variable "cloudflare_account_id" {
  type = string
}

variable "vault_secret_path" {
  type        = string
  description = "eg, `/nomad/job/traefik/cloudflared`"
}

variable "cloudflare_tunnel_name" {
  type = string
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  name       = var.cloudflare_tunnel_name
  account_id = var.cloudflare_account_id
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnel-token" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
}


resource "vault_kv_secret_v2" "cloudflared_secret" {
  mount = "secret"
  name  = var.vault_secret_path
  data_json = jsonencode({
    token = data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnel-token.token
  })
  custom_metadata {
    data = {
      "tf_managed"             = "true"
      "cloudflare_tunnel_name" = var.cloudflare_tunnel_name
    }
  }
  depends_on = [cloudflare_zero_trust_tunnel_cloudflared.tunnel]
}

output "cloudflare_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
}
