# AWS Region
variable "aws_region" {
  description = "AWS Region to deploy resources"
  type = string
  default = "ap-northeast-1"
}

# Environment & Business Division Info
variable "environment_name" {
  description = "Environment name used in resource names and tags"
  type = string
  default = "dev"
}

# Business unit or department
variable "business_division" {
  description = "Business Division in the large organization this infrastructure belongs to"
  type = string
  default = "retail"
}

variable "tags" {
  description = "Tags to apply to EKS and related resources"
  type        = map(string)
  default     = {
    Terraform = "true"
  }
}