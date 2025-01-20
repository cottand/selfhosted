locals {
  base_sub_cidr         = "10.2.0.0/24"
  lb_subnets_cidr        = "10.2.10.0/24"
  oci_control_pool_size = 3
  ADs                   = data.oci_identity_availability_domains.home.availability_domains
}
locals {
  zoneIds = jsondecode(data.bitwarden-secrets_secret.zoneIds.value)
  zoneIdsList = [local.zoneIds["eu"], local.zoneIds["com"]]
}

data "oci_identity_availability_domains" "home" {
  compartment_id = local.ociRoot
}

resource "oci_core_vcn" "base" {
  compartment_id = local.ociRoot
  dns_label      = "hub"

  cidr_blocks = [
    local.base_sub_cidr,
    local.lb_subnets_cidr,
  ]
  display_name = "base"

  is_ipv6enabled = true
}

resource "oci_core_subnet" "base" {
  compartment_id = local.ociRoot
  cidr_block     = local.base_sub_cidr
  ipv6cidr_blocks = [
    cidrsubnet(oci_core_vcn.base.ipv6cidr_blocks[0], 8, 0), # ends in /64
  ]
  vcn_id = oci_core_vcn.base.id
}

resource "oci_core_internet_gateway" "default" {
  compartment_id = local.ociRoot
  vcn_id         = oci_core_vcn.base.id
}

resource "oci_core_default_route_table" "default" {
  manage_default_resource_id = oci_core_vcn.base.default_route_table_id

  #   route_rules {
  #     network_entity_id = oci_load_balancer_load_balancer.public.id
  #     destination       = "${oci_load_balancer_load_balancer.public.ip_address_details[0].ip_address}/32"
  #   }
  route_rules {
#     network_entity_id = oci_core_nat_gateway.default.id
        network_entity_id = oci_core_internet_gateway.default.id
    destination = "0.0.0.0/0"
  }
  route_rules {
    network_entity_id = oci_core_internet_gateway.default.id
    destination       = "::/0"
  }
}

resource "oci_core_instance_configuration" "base" {
  compartment_id = local.ociRoot
  display_name   = "base"

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id = local.ociRoot
      shape          = "VM.Standard.A1.Flex"
      shape_config {
        # in free plan: 4 OCPUs@3GHz, 25 GB, per month
        ocpus         = 2
        memory_in_gbs = 6
      }
      create_vnic_details {
        subnet_id     = oci_core_subnet.base.id
        assign_ipv6ip = true
        ipv6address_ipv6subnet_cidr_pair_details {
          ipv6subnet_cidr = oci_core_subnet.base.ipv6cidr_blocks[0]
        }
      }
      source_details {
        source_type = "image"
        # from https://docs.oracle.com/en-us/iaas/images/image/2c243e52-ed4b-4bc5-b7ce-2a94063d2a19/index.htm
        #         image_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaanhfnlxfc6hoco52puzimxvge4emlmwyqtxw5sflqya4sewpko6dq" # oracle
        #         image_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa3rxaqcvwe2vxxffm4dfivmfb3apn4inqehxgntjrx3f7p4hzk5rq" # ubuntu
        image_id    = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa62wbair5a6s42sucffg4die3gdsaubtfgjq2tazt262bovnoeymq"
        # ubuntu 20.04
      }
      metadata = {
        ssh_authorized_keys : "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt"
        user_data = base64encode(file("oci/cloud_config.yml"))
      }
    }
  }
}

resource "oci_core_instance_pool" "control" {
  lifecycle {
    create_before_destroy = true
    ignore_changes = [load_balancers, freeform_tags]
    replace_triggered_by = [oci_core_instance_configuration.base.id]
  }
  compartment_id                  = local.ociRoot
  instance_configuration_id       = oci_core_instance_configuration.base.id
  display_name                    = "control"
  instance_display_name_formatter = ""


  placement_configurations {
    availability_domain = "zHzh:EU-FRANKFURT-1-AD-1"
    primary_vnic_subnets {
      subnet_id = oci_core_subnet.base.id
    }
  }
  size = local.oci_control_pool_size
}

module "nodes_oci_control" {
  count       = local.oci_control_pool_size
  cf_zone_ids = local.zoneIdsList
  source      = "../modules/node"
  name        = local.oci_servers_ips_list[count.index].name
  ip4_pub     = local.oci_servers_ips_list[count.index].ipv4
  ip6_pub     = local.oci_servers_ips_list[count.index].ipv6
  do_ip4_pub  = true
  do_ip6_pub  = true
}


resource "oci_core_default_security_list" "base_ipv6" {
  manage_default_resource_id = oci_core_vcn.base.default_security_list_id
  compartment_id             = local.ociRoot


  ingress_security_rules {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  #   ingress_security_rules {
  #     protocol = "6" // tcp
  #     source = "::/0"
  #     tcp_options {
  #       max = 22
  #       min = 22
  #     }
  #   }

  ingress_security_rules {
    protocol = "17" // udp
    source = "::/0"
    udp_options {
      max = 46461
      min = 46461
    }
  }

  ingress_security_rules {
    protocol = "17" // udp
    source = "0.0.0.0/0"
    udp_options {
      max = 46461
      min = 46461
    }
  }

  egress_security_rules {
    protocol = "6" // tcp
    destination = "0.0.0.0/0"
  }
  egress_security_rules {
    protocol = "6" // tcp
    destination = "::/0"
  }
  egress_security_rules {
    protocol = "17" // udp
    destination = "0.0.0.0/0"
  }
  egress_security_rules {
    protocol = "17" // udp
    destination = "::/0"
  }
}
