path "secret/data/{{identity.entity.aliases.auth_jwt_f5c14826.metadata.nomad_namespace}}/{{identity.entity.aliases.auth_jwt_7db0c05c.metadata.nomad_job_id}}/*" {
  capabilities = ["read", "write"]
}

path "secret/data/{{identity.entity.aliases.auth_jwt_f5c14826.metadata.nomad_namespace}}/{{identity.entity.aliases.auth_jwt_7db0c05c.metadata.nomad_job_id}}" {
  capabilities = ["read", "write"]
}

path "secret/metadata/{{identity.entity.aliases.auth_jwt_f5c14826.metadata.nomad_namespace}}/*" {
  capabilities = ["list", "write"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}

path "secret/data/nomad/infra/root_ca/*" {
  capabilities = ["read"]
}

path "secret/data/nomad/infra/root_ca" {
  capabilities = ["read"]
}