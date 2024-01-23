# resource "vault_token" "vault-prom-metrics-ro" {
#   role_name = "vault-prom-metrics-ro"

#   policies = [vault_policy.vault-prom-metrics_ro.name]

#   renewable = true
#   ttl = "24h"

#   renew_min_lease = 43200
#   renew_increment = 86400
# }

# resource "vault_policy" "vault-prom-metrics_ro" {
#     name = "vault-prom-metrics_ro"
#     policy =   <<EOT
#         path "/v1/sys/metrics" {
#             capabilities = ["read", "list"]
#         }
#     EOT
# }

# resource "vault_kv_secret_v2" "name" {
#  # TODO place in KV store, fetch from job file 
#  # before that, set up nomad to use vault secrets
# }