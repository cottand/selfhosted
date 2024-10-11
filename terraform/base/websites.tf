module "nico-dcotta-com" {
  source        = "../modules/static-site"
  cf_account_id = "a0668acd2601331c666d054c71470a40"
  domains = ["nico.dcotta.com"]
}

resource "cloudflare_record" "nico-dcotta-com" {
  name    = "nico"
  type    = "CNAME"
  zone_id = local.zoneIds["com"]
  value = module.nico-dcotta-com.pages_domain
  proxied = true
}