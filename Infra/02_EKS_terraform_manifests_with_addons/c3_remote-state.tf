# --------------------------------------------------------------------
# Reference the Remote State from VPC
# --------------------------------------------------------------------
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "terraform-state-bucket-suraj"
    key = "vpc/dev/terraform.tfstate"
    region = var.aws_region
  }
}

# Output the VPC ID from the remote VPC
output "vpc_id" {
  value = data.terraform_remote_state.vpc.outputs.vpc_id
}

# Output the list of private subnets from the VPC
output "private_subnet_ids" {
  value = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

# Output the list of public subnets from VPC
output "public_subnet_ids" {
  value = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}