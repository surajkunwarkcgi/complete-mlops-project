# Reference the Remote State from VPC
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "terraform-state-bucket-suraj"     # Name of the remote S3 bucket where the VPC state is stored
    key    = "vpc/dev/terraform.tfstate"        # Path to the VPC tfstate file within the bucket
    region = var.aws_region
  }
}

output "vpc_id" {
  value = data.terraform_remote_state.vpc.outputs.vpc_id
}

output "private_subnet_ids" {
  value = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

output "public_subnet_ids" {
  value = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}