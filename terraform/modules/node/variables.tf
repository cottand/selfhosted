

variable "name" {
  type = string
}

variable "do_ip4_pub" {
  type = bool
}

variable "do_ip6_pub" {
  type = bool
}

variable "ip4_pub" {
  type      = string
  nullable  = true
  sensitive = true
}

variable "ip6_pub" {
  type      = string
  nullable  = true
  sensitive = true
}

variable "is_web_ipv4" {
  type    = bool
  default = false
}

variable "is_web_ipv6" {
  type    = bool
  default = false
}


variable "cf_zone_ids" {
  type      = list(string)
  sensitive = true
}