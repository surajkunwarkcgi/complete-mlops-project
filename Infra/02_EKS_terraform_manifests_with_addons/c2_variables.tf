variable "aws_region" {
  description = "AWS region to deploy resources"
  type = string
  default = "ap-northeast-1"
}

variable "environment_name" {
  description = "Environment name used in resources names and tags"
  type = string
  default = "dev"
}

variable "business_division" {
  description = "Business Division in the large organization this infra belongs to"
  type = string
  default = "retail"
}

# --------------------------------------------------------
# EKS Cluster Configuration
# --------------------------------------------------------

# Name of the EKS cluster
variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix in names of related resources."
  type = string
  default = "eksdemo"
}

# Kubernetes version for the EKS control plane
variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type = string
  default = null
}

# CIDR block used for kubernetes service networking
variable "cluster_service_ipv4_cidr" {
  description = "Service CIDR range for Kubernetes services."
  type = string
  default = null
}

# Enable access to the EKS API via private endpoint
variable "cluster_endpoint_private_access" {
  description = "Whether to enable private access to EKS control endpoint"
  type = string
  default = false
}

# Enable access to the EKS API via public endpoint
variable "cluster_endpoint_public_access" {
  description = "Whether to enable public access to EKS control endpoint"
  type = string
  default = true
}

# List of CIDRs allowed to reach the public EKS API endpoint
variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks allowed to access public EKS endpoint"
  type = list(string)
  default = [ "0.0.0.0/0" ]
}

# --------------------------------------------------------
# Common Tags
# --------------------------------------------------------

# Tags applied to all resources created by this configuration
variable "tags" {
  description = "Tags to apply to EKS and related resources"
  type = map(string)
  default = {
    Terraform = "true"
  }
}

# EC2 instance types for worker nodes
variable "node_instance_types" {
  description = "List of EC2 instance types for the node group"
  type = list(string)
  default = [ "t3.medium" ]
}

# Capacity type for node group
variable "node_capacity_type" {
  description = "Instance capacity type: ON_DEMAND or SPOT"
  type = string
  default = "SPOT"
}

#Root volume size for worker nodes
variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type = number
  default = 20
}