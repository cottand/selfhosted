module "bucket-attic" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-attic"
  vault_secret_path_for_b2_creds = "nomad/job/attic/b2"
}

module "bucket-cloudreve" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-cloudreve"
  vault_secret_path_for_b2_creds = "nomad/job/cloudreve/b2"
  cors_any = true
}

module "bucket-gose" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-gose"
  vault_secret_path_for_b2_creds = "nomad/job/gose/b2"
  cors_any = true
  bucket_encryption = true
}

module "bucket-mealie" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-mealie"
  vault_secret_path_for_b2_creds = "nomad/job/mealie/b2"
  bucket_encryption = true
}
