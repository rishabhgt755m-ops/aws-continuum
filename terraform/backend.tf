terraform {
  backend "s3" {
    bucket       = "rishabh-bastion-tfstate-apsouth1"
    key          = "continuum/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
