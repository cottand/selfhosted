resource "cloudflare_zero_trust_tunnel_cloudflared" "traefik" {
  name       = "traefik"
  account_id = local.cloudflare.account_id
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "traefik-tunnel-token" {
  account_id = local.cloudflare.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.traefik.id
}


resource "vault_kv_secret_v2" "cloudflared_secret" {
  mount = "secret"
  name  = "/nomad/job/traefik/cloudflared"
  data_json = jsonencode({
    token = data.cloudflare_zero_trust_tunnel_cloudflared_token.traefik-tunnel-token.token
  })
  custom_metadata {
    data = {
      "tf_managed" = "true"
    }
  }
  depends_on = [cloudflare_zero_trust_tunnel_cloudflared.traefik]
}

module "tunnel-files" {
  source = "../modules/cloudflared-tunnel-origin"

  vault_secret_path      = "/nomad/job/cloudreve/cloudflared"
  cloudflare_tunnel_name = "files"
  cloudflare_account_id  = local.cloudflare.account_id
}
