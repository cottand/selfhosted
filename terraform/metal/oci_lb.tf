locals {
  # 2^4 = 16 available subnets
  lb_ingress_cidr = cidrsubnet(local.lb_subnets_cidr, 4, 0)
  lb_egress_cidr = cidrsubnet(local.lb_subnets_cidr, 4, 1)
}

resource "oci_core_subnet" "lb_egress" {
  compartment_id = local.ociRoot
  cidr_block     = local.lb_egress_cidr
  ipv6cidr_blocks = []
  vcn_id         = oci_core_vcn.base.id
  route_table_id = oci_core_route_table.lb_egress.id
  depends_on = [oci_core_vcn.base]
  display_name   = "lb_egress"
}
resource "oci_core_subnet" "lb_ingress" {
  compartment_id = local.ociRoot
  cidr_block     = local.lb_ingress_cidr
  ipv6cidr_blocks = []
  vcn_id         = oci_core_vcn.base.id
  route_table_id = oci_core_route_table.lb_ingress.id
  depends_on = [oci_core_vcn.base]
  display_name   = "lb_ingress"
}

resource "oci_network_load_balancer_network_load_balancer" "ingress" {
  compartment_id = local.ociRoot
  display_name   = "ingress"
  subnet_id      = oci_core_subnet.lb_ingress.id
  is_private     = false

  network_security_group_ids = [oci_core_network_security_group.lb_ingress.id]
  # todo experiment
  is_preserve_source_destination = false
  is_symmetric_hash_enabled      = false
}

resource "oci_network_load_balancer_backend_set" "to_egress_lb" {
  for_each = toset(["80", "443"])
  name                     = "to_egress_lb${each.value}"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.ingress.id
  policy                   = "TWO_TUPLE"

  health_checker {
    port        = "80"
    protocol    = "HTTP"
    url_path    = "/ping"
    return_code = 200
  }
}

resource "oci_network_load_balancer_backend" "egress_lb" {
  for_each = toset(["80", "443"])
  backend_set_name         = oci_network_load_balancer_backend_set.to_egress_lb[each.value].name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.ingress.id

  ip_address = oci_load_balancer_load_balancer.public_egress.ip_address_details[0].ip_address
  name       = "${oci_load_balancer_load_balancer.public_egress.display_name}-${each.value}"
  port = parseint(each.value, 10)
}

output "lb_ingress_ip" {
  value = oci_network_load_balancer_network_load_balancer.ingress.ip_addresses[0].ip_address
}


resource "oci_network_load_balancer_listener" "ingress" {
  for_each = toset(["80", "443"])
  default_backend_set_name = oci_network_load_balancer_backend_set.to_egress_lb[each.value].name
  name                     = "ingress${each.value}"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.ingress.id
  port = parseint(each.value, 10)
  protocol                 = "TCP"
}

resource "oci_load_balancer_load_balancer" "public_egress" {
  compartment_id = local.ociRoot
  display_name   = "public"
  subnet_ids = [oci_core_subnet.lb_egress.id]

  is_private = true

  network_security_group_ids = [oci_core_network_security_group.lb_egress.id]
  shape = "flexible"

  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
}

resource "oci_load_balancer_backend_set" "non_oci_traefik_nodes" {
  for_each = toset(["80", "443"])
  name             = "ingress_nodes_traefik${each.value}"
  load_balancer_id = oci_load_balancer_load_balancer.public_egress.id
  policy           = "LEAST_CONNECTIONS"

  health_checker {
    port              = "80"
    protocol          = "HTTP"
    timeout_in_millis = 3 * 1000
    interval_ms       = 9 * 1000
    retries           = 2
    url_path          = "/ping"
    return_code       = 200
  }
  depends_on = [oci_load_balancer_load_balancer.public_egress]
}

resource "oci_load_balancer_backend" "hez_80" {
  load_balancer_id = oci_load_balancer_load_balancer.public_egress.id
  backendset_name  = oci_load_balancer_backend_set.non_oci_traefik_nodes["80"].name
  for_each         = local.hez_server_ips
  ip_address       = each.value["ipv4"]
  port             = 80
  weight           = 1
  depends_on = [
    oci_load_balancer_listener.egress_80
  ]
}
resource "oci_load_balancer_backend" "hez_443" {
  load_balancer_id = oci_load_balancer_load_balancer.public_egress.id
  backendset_name  = oci_load_balancer_backend_set.non_oci_traefik_nodes["443"].name
  for_each         = local.hez_server_ips
  ip_address       = each.value["ipv4"]
  port             = 443
  weight           = 1
  depends_on = [
    oci_load_balancer_listener.egress_443
  ]
}

resource "oci_load_balancer_listener" "egress_443" {
  load_balancer_id         = oci_load_balancer_load_balancer.public_egress.id
  name                     = "public_443"
  default_backend_set_name = oci_load_balancer_backend_set.non_oci_traefik_nodes["443"].name
  port                     = 443
  protocol                 = "TCP"
  depends_on = [oci_load_balancer_backend_set.non_oci_traefik_nodes["443"]]
}

resource "oci_load_balancer_listener" "egress_80" {
  load_balancer_id         = oci_load_balancer_load_balancer.public_egress.id
  name                     = "public_80"
  default_backend_set_name = oci_load_balancer_backend_set.non_oci_traefik_nodes["80"].name
  port                     = 80
  protocol                 = "TCP"
  depends_on = [oci_load_balancer_backend_set.non_oci_traefik_nodes["80"]]

}

resource "oci_core_network_security_group" "lb_ingress" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id

  display_name = "ingress_to_lb"
}

data "cloudflare_ip_ranges" "cloudflare" {}


resource "oci_core_network_security_group_security_rule" "from_cloudflare" {
  for_each = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks)

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.lb_ingress.id
  protocol = "6" // TCP

  source_type = "CIDR_BLOCK"
  source      = each.value
  stateless   = true
  description = "cloudflare egress cidr"
}

# for debugging
resource "oci_core_network_security_group_security_rule" "from_vcn" {
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.lb_ingress.id
  protocol = "6" // TCP

  source_type = "CIDR_BLOCK"
  source      = local.base_sub_cidr
  stateless   = true
}


resource "oci_core_network_security_group" "lb_egress" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id

  display_name = "egress_lb_to_external"
}

resource "oci_core_network_security_group_security_rule" "to_internet443" {
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.lb_egress.id
  protocol = "6" // TCP

  destination_type = "CIDR_BLOCK"
  destination      = "0.0.0.0/0"
  stateless        = false
}


## Route tables:

resource "oci_core_route_table" "lb_egress" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id
  display_name   = "lb_egress"

  route_rules {
    network_entity_id = oci_core_nat_gateway.default.id
    destination_type  = "CIDR_BLOCK"
    destination       = "0.0.0.0/0"
  }
}

resource "oci_core_route_table" "lb_ingress" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id
  display_name   = "lb_ingress"

  route_rules {
    network_entity_id = oci_core_internet_gateway.default.id
    destination_type  = "CIDR_BLOCK"
    destination       = "0.0.0.0/0"
  }
}

resource "oci_core_nat_gateway" "default" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id
}

resource "cloudflare_record" "web" {
  for_each = toset(local.zoneIdsList)
  zone_id = each.value
  type    = "A"
  name    = "web"
  value   = oci_network_load_balancer_network_load_balancer.ingress.ip_addresses[0].ip_address
  ttl     = 1
  comment = "tf managed"
  proxied = true
}

