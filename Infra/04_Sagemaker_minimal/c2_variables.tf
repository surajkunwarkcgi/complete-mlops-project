variable "aws_region" {
  description = "AWS region to deploy resources"
  type = string
  default = "us-east-1"
}

variable "environment_name" {
  description = "Environment name used in resource names and tags"
  type = string
  default = "dev"
}

variable "business_division" {
  description = "Business Division in the organization"
  type = string
  default = "retail"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type = map(string)
  default = {
    Terraform = "true"
  }
}

variable "sagemaker_bucket_name" {
  description = "S3 bucket name for SageMaker artifacts"
  type = string
  default = "sagemaker-mlops-suraj-useast1"
}

variable "github_repo_owner" {
  description = "GitHub repository owner"
  type = string
  default = "surajkunwarkcgi"
}

variable "github_repo_name" {
  description = "GitHub repository name"
  type = string
  default = "complete-mlops-project"
}