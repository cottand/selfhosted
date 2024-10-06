resource "oci_core_network_security_group" "instances_control" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id

  display_name = "instances_control"
}


# resource "oci_core_network_security_group_security_rule" "control_from_internet_tcp" {
#   direction                 = "INGRESS"
#   network_security_group_id = oci_core_network_security_group.lb.id
#   protocol = "6" // TCP
#
#   source_type = "CIDR_BLOCK"
#   source      = "0.0.0.0/0"
#
#   stateless = true
# }

resource "oci_core_network_security_group_security_rule" "control_to_internet_tcp" {
  for_each = toset(["0.0.0.0/0", "::/0"])
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.instances_control.id
  protocol = "6" // TCP

  destination_type = "CIDR_BLOCK"
  destination      = each.value

  stateless = false
}
resource "oci_core_network_security_group_security_rule" "control_to_internet_udp" {
  for_each = toset(["0.0.0.0/0", "::/0"])
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.instances_control.id
  protocol = "17" // UDP

  destination_type = "CIDR_BLOCK"
  destination      = each.value

  stateless = true
}

resource "oci_core_network_security_group_security_rule" "control_from_internet_ts" {
  for_each = toset(["0.0.0.0/0", "::/0"])
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.instances_control.id
  protocol = "17" // UDP

  source_type = "CIDR_BLOCK"
  source      = each.value

  udp_options {
    source_port_range {
      max = 46461
      min = 46461
    }
  }

  stateless = true
}

