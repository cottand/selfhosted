# resource "google_compute_image" "nixos-base" {
#
#   name = ""
#
#
# }

resource "google_compute_instance_template" "nixos-worker5" {
  name         = "nixos-worker-v5"
  machine_type = "e2-small"
  region       = "europe-west3"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {}
  }

  lifecycle {
    create_before_destroy = false
  }

  metadata_startup_script = <<-EOF
#! /bin/bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.05 bash -x


echo '{pkgs, config, ...}: {
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt nico.dc@outlook.com-m3"
  ];
  services.openssh.openFirewall = ture;
  services.openssh.enable = true;

  # Use GCE udev rules for dynamic disk volumes
  services.udev.packages = [ pkgs.google-guest-configs ];
  services.udev.path = [ pkgs.google-guest-configs ];

}' >> /etc/temp.nix
EOF


  metadata = {
    enable-guest-attributes = "true"
    enable-osconfig         = "true"
  }
}


resource "google_compute_instance_template" "nixos-worker6" {
  name         = "nixos-worker-v6"
  machine_type = "e2-small"
  region       = "europe-west3"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {}
  }

  lifecycle {
    create_before_destroy = false
  }

  metadata_startup_script = <<-EOF
#! /bin/bash
echo '{pkgs, config, ...}: {
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt nico.dc@outlook.com-m3"
  ];
  services.openssh.openFirewall = ture;
  services.openssh.enable = true;

  # Use GCE udev rules for dynamic disk volumes
  services.udev.packages = [ pkgs.google-guest-configs ];
  services.udev.path = [ pkgs.google-guest-configs ];

}' >> /etc/nixos/temp.nix


curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIXOS_IMPORT=./temp.nix NIX_CHANNEL=nixos-24.05 bash -x
EOF


  metadata = {
    enable-guest-attributes = "true"
    enable-osconfig         = "true"
  }
}


resource "google_compute_instance_group_manager" "workers1" {
  name               = "workers1"
  base_instance_name = "worker"
  zone               = "europe-west3-a"
  target_size        = "1"

  version {
    instance_template = google_compute_instance_template.nixos-worker6.id
    target_size {
      fixed = 1
    }
  }

  version {
    instance_template = google_compute_instance_template.nixos-worker5.id
  }

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
  }
}