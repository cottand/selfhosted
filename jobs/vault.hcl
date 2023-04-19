job "vault" {

    datacenters = ["dc1"]
    type        = "service"

    group "vault" {
        network {
            mode = "bridge"
            port "" {

            }
        }
    }
}