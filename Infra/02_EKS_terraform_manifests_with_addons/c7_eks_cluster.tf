# Create AWS EKS Cluster (control plane for Kubernetes on AWS)
resource "aws_eks_cluster" "main" {
  name = local.eks_cluster_name

  # Kuberneres version to use for the control plane
  version = var.cluster_version

  # IAM role used by EKS to manage the control plane
  role_arn = aws_iam_role.eks_cluster.arn

  # VPC configuration for control plane networking
  vpc_config {
    # Subnets where EKS control plane ENIs will be placed
    subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

    # Allow access to private endpoint (inside VPC)
    endpoint_private_access = var.cluster_endpoint_private_access

    # Allow access to public endpoint (from internet, controlled via CIDRs)
    endpoint_public_access = var.cluster_endpoint_public_access

    #List of CIDRs allowed to reach the public endpoint
    public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  }

  # Define the service CIDR range used by Kubernetes services
  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
  }

  # Enable EKS control plane logging for visibility and debugging
  enabled_cluster_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  # Ensure IAM policy attachments complete before cluster creation
  depends_on = [ 
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
   ]

   # Common tags applied to the EKS cluster
   tags = var.tags

   access_config {
     authentication_mode = "API_AND_CONFIG_MAP" # Three options: CONFIG_MAP, API, API_AND_CONFIG_MAP
     bootstrap_cluster_creator_admin_permissions = true
   }
}