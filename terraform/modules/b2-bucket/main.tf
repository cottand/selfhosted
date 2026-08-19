terraform {
  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.13.1"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}

variable "vault_secret_path_for_b2_creds" {
  type = string
}

variable "b2_bucket_name" {
  type = string
}

variable "cors_any" {
  type    = bool
  default = false
}

resource "b2_bucket" "bucket" {
  bucket_name = var.b2_bucket_name
  bucket_type = "allPrivate"

  lifecycle_rules {
    file_name_prefix             = ""
    days_from_hiding_to_deleting = 10
  }

  dynamic "cors_rules" {
    for_each = var.cors_any ? ["some"] : []
    content {
      allowed_headers = ["*"]
      allowed_operations = [
        "s3_head",
        "s3_put",
        "s3_delete",
        "s3_post",
        "s3_get",
      ]
      allowed_origins = ["*"]
      cors_rule_name  = "cors-any"
      expose_headers = ["etag"]
      max_age_seconds = 3000
    }
  }
}

resource "b2_application_key" "app_key" {
  capabilities = ["deleteFiles", "listBuckets", "listFiles", "readBucketEncryption", "readBucketLifecycleRules", "readBucketLogging", "readBucketNotifications", "readBucketReplications", "readBuckets", "readFiles", "shareFiles", "writeBucketEncryption", "writeBucketLifecycleRules", "writeBucketLogging", "writeBucketNotifications", "writeBucketReplications", "writeBuckets", "writeFiles"]
  key_name     = "${var.b2_bucket_name}-rw"

  bucket_ids = [b2_bucket.bucket.id]
}

resource "vault_kv_secret_v2" "secret" {
  mount = "secret"
  name  = var.vault_secret_path_for_b2_creds
  data_json = jsonencode({
    keyID          = b2_application_key.app_key.application_key_id
    applicationKey = b2_application_key.app_key.application_key
    bucket         = b2_bucket.bucket.bucket_name
    endpoint       = "s3.us-east-005.backblazeb2.com"
    region         = "us-east-005"
  })
  custom_metadata {
    data = {
      "tf_managed" = "true"
    }
  }
}

