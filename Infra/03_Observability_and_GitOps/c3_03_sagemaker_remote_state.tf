# Reference the Remote State from the SageMaker/Secrets/GitHub-OIDC stack
# (Infra/04_Sagemaker_minimal) - the single source of truth for the S3 bucket,
# SageMaker execution role, MLFLOW/config secrets, and the GitHub Actions OIDC role.

data "terraform_remote_state" "sagemaker" {
    backend = "s3"

    config = {
      bucket = "terraform-state-bucket-suraj-us"
      key = "sagemaker-minimal/dev/terraform.tfstate"
      region = "us-east-1"
    }
}