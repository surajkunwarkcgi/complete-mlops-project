# Data Source: AWS Account Info

data "aws_caller_identity" "current" {}

# Data Source: AWS Region
data "aws_region" "current" {}

# Data Source: AWS Partition
data "aws_partition" "current" {}

locals {
  # Business division or team name
  owners = var.business_division

  # Environment name (dev, staging, prod)
  environment = var.environment_name

  # Standardized naming prefix: "<division>-<env>"
  name = "${local.owners}-${local.environment}"

  # AWS Account ID
  account_id = data.aws_caller_identity.current.account_id
  
  # AWS Partition
  partition = data.aws_partition.current.partition
}