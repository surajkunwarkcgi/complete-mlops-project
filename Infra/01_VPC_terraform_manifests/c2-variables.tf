variable "aws_region" {
  description = "AWS region to deploy resources"
  type = string
  default = "ap-northeast-1"
}

variable "environment_name" {
    description = "Environment name used in resource names and tags"
    type = string
    default = "dev"
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
    default = "10.0.0.0/16"
}

variable "tags" {
    description = "Global Tags to apply to all resources"
    type = map(string)
    default = {
        Terraform = "true"
    }
}

variable "subnet_newbits" {
    description = "Number of new bits to add to the VPC CIDR block to generate subnets"
    type = number
    default = 8
}