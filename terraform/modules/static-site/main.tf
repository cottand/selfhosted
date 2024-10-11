variable "subdomain" {
  type = string
}

variable "cf_account_id" {}


# resource "cloudflare_r2_bucket" "site" {
#   account_id = var.cf_account_id
#   name = "${var.subdomain}-dcotta-web"
#   location = "weur"
# }

resource "cloudflare_pages_project" "nico-dcotta-com" {
  account_id        = var.cf_account_id
  name              = "nico-dcotta-com"
  production_branch = "master"
}
