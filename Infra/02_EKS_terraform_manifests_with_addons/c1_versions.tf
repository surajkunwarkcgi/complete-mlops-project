terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = ">= 6.0"
    }

    kubernetes = {
        source = "hashicorp/kubernetes"
        version = "~> 2.38.0"
    }

    helm = {
        source = "hashicorp/helm"
        version = "~> 3.0"
    }

    http = {
        source = "hashicorp/http"
        version = "~> 3.5.0"
    }
  }

  # Remtote backend configuration using S3
  backend "s3" {
    bucket = "terraform-state-bucket-suraj"
    key = "eks/dev/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}