module "bucket-papra" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-papra"
  vault_secret_path_for_b2_creds = "nomad/job/papra/b2"
  cors_any = true
}

module "bucket-papra-db" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-papra-db"
  vault_secret_path_for_b2_creds = "nomad/job/papra/b2-db"
}

module "bucket-safebucket" {
  source = "../modules/b2-bucket"

  b2_bucket_name                 = "cottand-safebucket"
  vault_secret_path_for_b2_creds = "nomad/job/safebucket/b2"
  cors_any = true
}

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
