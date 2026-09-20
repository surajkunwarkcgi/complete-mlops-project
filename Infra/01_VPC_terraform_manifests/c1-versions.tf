terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-bucket-suraj"
    key = "vpc/dev/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
    use_lockfile = true
  }
}

provider "aws" {
    region = var.aws_region
}