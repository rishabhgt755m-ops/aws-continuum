terraform {
  required_version = ">= 1.16.0, < 1.18.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "continuum"
      Environment = "lab"
      ManagedBy   = "terraform"
      Owner       = "personal-lab"
    }
  }
}
