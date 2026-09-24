# Local values used throughout the EKS configuration
locals {
  # Business division or team name
  owners = var.business_division

  # Environment name such as dev, staging, prod
  environment = var.environment_name

  # Standardized naming prefix: "<division>-<env>"
  name = "${local.owners}-${local.environment}"

  # Full EKS cluster name used for resource naming and tagging
  eks_cluster_name = "${local.name}-${var.cluster_name}"
}