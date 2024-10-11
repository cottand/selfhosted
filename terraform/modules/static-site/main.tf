variable "domains" {
  type = list(string)
}

variable "cf_account_id" {}


resource "cloudflare_pages_project" "nico-dcotta-com" {
  account_id        = var.cf_account_id
  name              = "nico-dcotta-com"
  production_branch = "master"
}

resource "cloudflare_pages_domain" "domains" {
  for_each = toset(var.domains)
  account_id   = var.cf_account_id
  domain       = each.value
  project_name = cloudflare_pages_project.nico-dcotta-com.name
}

output "pages_domain" {
  value = cloudflare_pages_project.nico-dcotta-com.subdomain
}