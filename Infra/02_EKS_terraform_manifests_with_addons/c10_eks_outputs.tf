# Output the EKS Cluster API server endpoint
# Used by kubectl and external tools to communicate with the cluster
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
  description = "EKS API server endpoint"
}

# Output the EKS Cluster ID
# Used in AWS CLI commands and automation scripts to reference the EKS cluster
output "eks_cluster_id" {
  value = aws_eks_cluster.main.id
  description = "The name/id of the  EKS cluster."
}

# Output the EKS Cluster Version
output "eks_cluster_version" {
  value = aws_eks_cluster.main.version
  description = "EKS Kubernetes Version"
}

# Output the name of the EKS cluster
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
  description = "EKS cluster name"
}

# Output the EKS Cluster Certificate Authority data
# Needed when setting up kubeconfig or accessing EKS via API
output "eks_cluster_certificate_authority_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
  description = "Base64 encoded CA certificate for kubectl config"
}

# Output the logical name of the private node group
output "private_node_group_name" {
  value = aws_eks_node_group.private_nodes.node_group_name
  description = "Name of the EKS private node group"
}

# Output the IAM Role ARN used by the EKS Node Group
output "eks_node_instance_role_arn" {
  value = aws_iam_role.eks_nodegroup_role.arn
  description = "IAM Role ARN used by EKS node group (EC2 worker nodes)"
}

# Output command to configure kubectl for this EKS cluster
output "to_configure_kubectl" {
  value = "aws eks --region ${var.aws_region} update-kubeconfig --name ${local.eks_cluster_name}"
  description = "Command to update local kubeconfig to connect to the EKS cluster"
}

# Output the EKS Cluster Security Group ID
output "eks_cluster_security_group_id" {
  description = "Security group associated with the EKS cluster (used for control plane to node communication)"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}