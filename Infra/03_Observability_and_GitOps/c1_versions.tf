terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.20"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.28"
    }
  }

  backend "s3" {
    bucket = "terraform-state-bucket-suraj"
    key = "opentelemetry/dev/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}