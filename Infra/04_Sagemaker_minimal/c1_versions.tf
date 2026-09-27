terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment below after first apply to store state in S3
  backend "s3" {
    bucket = "terraform-state-bucket-suraj-us"
    key = "sagemaker-minimal/dev/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Terraform   = "true"
      Environment = var.environment_name
      Project     = "MLOps"
      Module      = "SageMaker"
    }
  }
}