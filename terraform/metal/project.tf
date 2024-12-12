resource "hcloud_network" "main" {
  name     = "my-net"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_ssh_key" "nico-m3" {
  name       = "Nico M3"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt nico.dc@outlook.com"
}
data "hcloud_image" "ubuntu22" {
  name              = "ubuntu-22.04"
  with_architecture = "x86"
}

resource "hcloud_network_subnet" "sub1" {
  ip_range     = "10.0.1.0/24"
  network_id   = hcloud_network.main.id
  network_zone = "eu-central"
  type         = "cloud"
}

// stateful servers
resource "hcloud_server" "hez1" {
  count       = 3
  name        = "hez${count.index + 1}"
  server_type = "cx32"
  location    = "nbg1"
  image       = data.hcloud_image.ubuntu22.id

  rebuild_protection = true
  delete_protection  = true
  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.${count.index + 1}"
    alias_ips  = []
  }
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  firewall_ids = [hcloud_firewall.ssh-wireguard.id]
  ssh_keys     = [hcloud_ssh_key.nico-m3.name]
  user_data    = <<EOT
#cloud-config

runcmd:
  - curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-24.05 bash 2>&1 | tee /tmp/infect.log
EOT

  depends_on = [hcloud_network.main]
}

resource "hcloud_firewall" "ssh-wireguard" {
  name = "my-firewall"
#   rule {
#     direction  = "in"
#     protocol   = "tcp"
#     port       = 22
#     source_ips = ["0.0.0.0/0", "::/0"]
#   }
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "55820"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "46461"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}