terraform {
  backend "s3" {
    bucket                      = "cottand-selfhosted-tf"
    key                         = "base"
    region                      = "us-east-005"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    shared_credentials_files    = ["../../secret/b2/cottand-selfhosted-tf-rw"]
    use_path_style              = true
    endpoints = {
      s3 = "https://s3.us-east-005.backblazeb2.com"
    }
  }
}

data "terraform_remote_state" "metal" {
  backend = "s3"
  config = {
    bucket                      = "cottand-selfhosted-tf"
    key                         = "metal"
    region                      = "us-east-005"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    shared_credentials_files    = ["../../secret/b2/cottand-selfhosted-tf-rw"]
    use_path_style              = true
    endpoints = {
      s3 = "https://s3.us-east-005.backblazeb2.com"
    }
  }
}