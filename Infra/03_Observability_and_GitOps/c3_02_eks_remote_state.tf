# Reference the Remote State from EKS
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "terraform-state-bucket-suraj"     # Name of the remote S3 bucket where the EKS state is stored
    key    = "eks/dev/terraform.tfstate"        # Path to the EKS tfstate file within the bucket
    region = var.aws_region                     # Region where the S3 bucket exist
  }
}
output "eks_cluster_name" {
  value = data.terraform_remote_state.eks.outputs.eks_cluster_name
}

output "eks_cluster_id" {
  value = data.terraform_remote_state.eks.outputs.eks_cluster_id
}