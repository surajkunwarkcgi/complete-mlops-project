# ============================================================================
# S3 Bucket for SageMaker artifacts + prediction captures
# ============================================================================

resource "aws_s3_bucket" "sagemaker" {
  bucket = var.sagemaker_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket_versioning" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Lifecycle: expire prediction captures after 15 days (Model Monitor only needs recent data)
resource "aws_s3_bucket_lifecycle_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  rule {
    id = "expire-prediction-captures"
    status = "Enabled"

    filter {
      prefix = "wine-quality/prediction-captures/"
    }

    expiration {
      days = 15
    }
  }
}

# ============================================================================
# IAM Role for SageMaker Training + Processing Jobs
# ============================================================================

resource "aws_iam_role" "sagemaker_execution" {
  name = "${local.name}-sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# AWS managed policy - covers Training, Processing, Model Monitor
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  role = aws_iam_role.sagemaker_execution.name
}

# S3 access scoped to SageMaker bucket only
resource "aws_iam_policy" "sagemaker_s3" {
  name = "${local.name}-sagemaker-s3-policy"
  description = "Allow SageMaker to read/write the MLOps S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sagemaker.arn,
          "${aws_s3_bucket.sagemaker.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_s3" {
  policy_arn = aws_iam_policy.sagemaker_s3.arn
  role = aws_iam_role.sagemaker_execution.name
}

# KMS permissions for encrypted S3 objects
resource "aws_iam_policy" "sagemaker_kms" {
    name = "${local.name}-sagemaker-kms-policy"
    description = "Allow SageMaker to decrypt S3 objects"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
                "kms:Decrypt",
                "kms:GenerateDataKey"
            ]
            Resource = "*"
          }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "sagemaker_kms" {
    policy_arn = aws_iam_policy.sagemaker_kms.arn
    role = aws_iam_role.sagemaker_execution.name
}

# Secrets Manager access - so SageMaker Training Job can read MLFlow creds
resource "aws_iam_policy" "sagemaker_secrets" {
  name = "${local.name}-sagemaker-secrets-policy"
  description = "Allow SageMaker Training Job to read MLFlow credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:mlflow-tracking-secrets*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_secrets" {
  policy_arn = aws_iam_policy.sagemaker_secrets.arn
  role = aws_iam_role.sagemaker_execution.name
}
# ============================================================================
# Secrets Manager - MLFlow credentials + GitHub Actions config
# ============================================================================

resource "aws_secretsmanager_secret" "mlflow" {
  name = "mlflow-tracking-secrets"
  description = "MLFlow DagsHub credentials - values populated by GitHub Actions via OIDC"
  recovery_window_in_days = 0 # Forces immediate deletion on destroy for development
  tags = var.tags
}

resource "aws_secretsmanager_secret" "github_actions_config" {
  name = "github-actions-config"
  description = "Non-sensitive config values read by GitHub Actions at runtime"
  recovery_window_in_days = 0 # Forces immediate deletion on destroy for development
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "github_actions_config" {
  secret_id = aws_secretsmanager_secret.github_actions_config.id
  secret_string = jsonencode({
    SAGEMAKER_ROLE_ARN = aws_iam_role.sagemaker_execution.arn
    SAGEMAKER_BUCKET = aws_s3_bucket.sagemaker.bucket
  })
}

# ============================================================================
# GitHub Actions OIDC Provider + IAM Role
# ============================================================================

# OIDC Provider - allows GitHub Actions to authenticate to AWS without keys
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint - stable, does not change
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags = var.tags
}

# IAM Role assumed by GitHub Actions via OIDC
resource "aws_iam_role" "github_actions" {
  name = "${local.name}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo_owner}*/${var.github_repo_name}*:*"
          }
        }
      }
    ]
  })
  tags = var.tags
}

# ============================================================================
# GitHub Actions IAM Policies
# ============================================================================

# ECR push/pull
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role = aws_iam_role.github_actions.name
}

# Secrets Manager - read MLFlow creds + config, write MLFlow creds
resource "aws_iam_policy" "github_actions_secrets" {
  name = "${local.name}-github-actions-secrets-policy"
  description = "Allow GitHub Actions to read/write secrets via OIDC"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.mlflow.arn,
          aws_secretsmanager_secret.github_actions_config.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_secrets" {
  policy_arn = aws_iam_policy.github_actions_secrets.arn
  role = aws_iam_role.github_actions.name
}

# S3 - upload training data, download model artifact
resource "aws_iam_policy" "github_actions_s3" {
  name = "${local.name}-github-actions-s3-policy"
  description = "Allow GitHub Actions to read/write SageMaker S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sagemaker.arn,
          "${aws_s3_bucket.sagemaker.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_s3" {
  policy_arn = aws_iam_policy.github_actions_s3.arn
  role = aws_iam_role.github_actions.name
}

# SageMaker - create/describe training jobs and pass roles
resource "aws_iam_policy" "github_actions_sagemaker" {
  name = "${local.name}-github-actions-sagemaker-policy"
  description = "Allow GitHub Actions to trigger SageMaker training jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:CreateModelPackageGroup",
          "sagemaker:CreateModelPackage",
          "sagemaker:DescribeModelPackage"
        ]
        Resource = "arn:aws:sagemaker:${var.aws_region}:${local.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.sagemaker_execution.arn
      },
      {
        Effect = "Allow"
        Action = [
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/sagemaker/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_sagemaker" {
  policy_arn = aws_iam_policy.github_actions_sagemaker.arn
  role = aws_iam_role.github_actions.name
}