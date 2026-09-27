output "sagemaker_bucket_name" {
  description = "SageMaker S3 bucket name"
  value = aws_s3_bucket.sagemaker.bucket
}

output "sagemaker_execution_role_arn" {
  description = "SageMaker execution role ARN - use this in sagemaker_pipeline.py"
  value = aws_iam_role.sagemaker_execution.arn
}

output "github_actions_role_arn" {
  description = "GitHub Actions OIDC role ARN - add to .github/workflows/ci.yaml"
  value = aws_iam_role.github_actions.arn
}

output "mlflow_secret_arn" {
  description = "MLFlow secret ARN - GitHub Actions will populate this"
  value = aws_secretsmanager_secret.mlflow.arn
}

output "github_actions_config_secret_arn" {
  description = "GitHub Actions config secret ARN"
  value = aws_secretsmanager_secret.github_actions_config.arn
}