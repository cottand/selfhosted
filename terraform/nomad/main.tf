

resource "nomad_acl_policy" "anonymous" {
  name        = "anonymous"
  description = "Anonymous (unauthenticated) policy"
  rules_hcl   = file("policies/anonymous.hcl")
}

resource "nomad_acl_policy" "read-buckets" {
  name      = "read-buckets"
  rules_hcl = file("policies/read-buckets.hcl")
  job_acl {
    job_id = "traefik"
  }
}

resource "nomad_acl_policy" "mimir-read-buckets" {
  name      = "mimir-read-buckets"
  rules_hcl = file("policies/read-buckets.hcl")
  job_acl {
    job_id = "mimir"
  }
}

resource "nomad_acl_policy" "seaweedfs-backup-read-buckets" {
  name      = "seaweedfs-backup-read-buckets"
  rules_hcl = file("policies/read-buckets.hcl")
  job_acl {
    job_id = "seaweedfs-backup"
  }
}

resource "nomad_acl_policy" "lemmy-backup-read-buckets" {
  name      = "lemmy-backup-read-buckets"
  rules_hcl = file("policies/read-buckets.hcl")
  job_acl {
    job_id = "lemmy-backup"
  }
}

resource "nomad_acl_policy" "immich-backup-read-buckets" {
  name      = "immich-backup-read-buckets"
  rules_hcl = file("policies/read-buckets.hcl")
  job_acl {
    job_id = "immich-db-backup"
  }
}