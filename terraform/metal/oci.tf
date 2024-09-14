locals {
  base_sub_cidr  = "10.2.0.0/24"
  oci_pool1_size = 2
  ADs            = data.oci_identity_availability_domains.home.availability_domains
}

data "oci_identity_availability_domains" "home" {
  compartment_id = local.ociRoot
}

resource "oci_core_vcn" "base" {
  compartment_id = local.ociRoot
  dns_label      = "hub"

  cidr_blocks = [
    local.base_sub_cidr
  ]
  display_name = "base"

  is_ipv6enabled = true
}

resource "oci_core_subnet" "base" {
  compartment_id  = local.ociRoot
  cidr_block      = local.base_sub_cidr
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

  route_rules {
    network_entity_id = oci_core_internet_gateway.default.id
    destination       = "0.0.0.0/0"
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
        image_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaylcz7y7w6uolelzd6ruexuqkufkqqgg2nrr6xnvhtukysuolzv4q"
      }
      metadata = {
        ssh_authorized_keys : "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt"
        user_data = base64encode(file("oci/cloud_config.yml"))
      }
    }
  }
}

resource "oci_core_instance_pool" "pool1" {
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, freeform_tags]
    replace_triggered_by  = [oci_core_instance_configuration.base.id]
  }
  compartment_id                  = local.ociRoot
  instance_configuration_id       = oci_core_instance_configuration.base.id
  display_name                    = "pool1"
  instance_display_name_formatter = ""


  placement_configurations {
    availability_domain = "zHzh:EU-FRANKFURT-1-AD-1"
    primary_vnic_subnets {
      subnet_id = oci_core_subnet.base.id
    }
  }
  size = local.oci_pool1_size
}

resource "oci_core_default_security_list" "base_ipv6" {
  manage_default_resource_id = oci_core_vcn.base.default_security_list_id
  compartment_id             = local.ociRoot

  ingress_security_rules {
    protocol = "6" // tcp
    source = "0.0.0.0/0"
    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol = "6" // tcp
    source = "::/0"
    tcp_options {
      max = 22
      min = 22
    }
  }

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
}
