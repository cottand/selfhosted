job "photos" {
  datacenters = ["dc1"]
  type        = "service"
  group "immich" {

    network {
      mode = "bridge"
      port "http" {
        host_network = "vpn"
      }
      port "ws" {
        host_network = "vpn"
      }
    }
  }
}