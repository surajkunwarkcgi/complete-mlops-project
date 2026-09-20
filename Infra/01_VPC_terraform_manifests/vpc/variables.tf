variable "environment_name" {
  type = string
  description = "Environment name used in resource names and tags"
  default = "dev"
}

variable "vpc_cidr" {
  type = string
  description = "CIDR block for the VPC"
  default = "10.0.0.0/16"
}

variable "tags" {
  type = map(string)
  description = "Global Tags to apply to all resources"
  default = {
    Terraform = "true"
  }
}

variable "subnet_newbits" {
  type = number
  description = "Number of new bits to add to the VPC CIDR block to generate subnets"
  default = 8
}