variable "com_zone_id" {
  type = string
}

# resource "cloudflare_record" "dcotta-com-proton-txt" {
#   zone_id = var.com_zone_id
#   name    = "@"
#   type    = "TXT"
#   value   = "protonmail-verification=c7e23b185906de15c5d6db5d92e9647b97abbbc3"
#   ttl     = 60
#   comment = "tf managed"
#   proxied = false
# }
