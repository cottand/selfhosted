module "bucket-papra" {
  source = "../modules/b2-bucket"

  b2_bucket_name = "cottand-papra"
  vault_secret_path_for_b2_creds = "nomad/job/papra/b2"
}


module "bucket-papra-db" {
  source = "../modules/b2-bucket"

  b2_bucket_name = "cottand-papra-db"
  vault_secret_path_for_b2_creds = "nomad/job/papra/b2-db"
}
