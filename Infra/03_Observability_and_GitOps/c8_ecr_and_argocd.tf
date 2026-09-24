# ECR Repository for Wine Quality Predictor
resource "aws_ecr_repository" "wine_quality_predictor" {
  name = "wine-quality-predictor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Lifecycle policy: keep last 10 images, delete older ones to save storage cost
resource "aws_ecr_lifecycle_policy" "wine_quality_predictor" {
  repository = aws_ecr_repository.wine_quality_predictor.name

  policy = jsonencode({
    rules = [{
        rulePriority = 1
        description = "Keep last 10 images"
        selection = {
            tagStatus = "any"
            countType = "imageCountMoreThan"
            countNumber = 10
        }
        action = { type = "expire" }
    }]
  })
}

# IAM Role for Wine Quality Predictor Pod (Secrets Manager access)
resource "aws_iam_role" "wine_quality_predictor" {
  name = "${local.name}-wine-quality-predictor-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Effect = "Allow"
        Principal = { Service = "pods.eks.amazonaws.com" }
        Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "wine_quality_predictor_secrets" {
  name = "${local.name}-wine-quality-predictor-secrets-policy"
  description = "Allow wine-quality-predictor pod to read MLFlow secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Effect = "Allow"
        Action = [
            "secretsmanager: GetSecretValue",
            "secretsmanager: DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:mlflow-tracking-secrets*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "wine_quality_predictor_secrets" {
  policy_arn = aws_iam_policy.wine_quality_predictor_secrets.arn
  role = aws_iam_role.wine_quality_predictor.name
}

resource "aws_eks_pod_identity_association" "wine_quality_predictor" {
  cluster_name = data.terraform_remote_state.eks.outputs.eks_cluster_id
  namespace = "mlops"
  service_account = "wine-quality-predictor"
  role_arn = aws_iam_role.wine_quality_predictor.arn
}

# ArgoCD Helm Install
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  depends_on = [ kubernetes_namespace_v1.argocd ]

  name = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  namespace = "argocd"
  version = "7.4.4"

  wait = true
  timeout = 600
  cleanup_on_fail = true

  set = [ 
    # Expose ArgoCD UI via LoadBalancer
      {
        name = "server.service.type"
        value = "LoadBalancer"
      },
        # Disable TLS on the server (ALB handles TLS termination)
      {
        name = "server.extraArgs[0]"
        value = "--insecure"
      },
      {
        name = "server.resources.requests.cpu"
        value = "100m"
      },
      {
        name = "server.resources.requests.memory"
        value = "128Mi"
      },
      {
        name = "server.resources.limits.cpu"
        value = "200m"
      },
      {
        name = "server.resources.limits.memory"
        value = "256Mi"
      }
   ]
   tags = var.tags
}

# Outputs
output "ecr_repository_url" {
  description = "ECR repository URL - use this in GitHub Actions and deployment.yaml"
  value = aws_ecr_repository.wine_quality_predictor.repository_url
}

output "wine_quality_predictor_iam_role_arn" {
  description = "IAM Role ARN - paste into mlops-gitops/k8s/serviceaccount.yaml"
  value = aws_iam_role.wine_quality_predictor.arn
}

output "argocd_ui_note" {
  description = "Retrieve ArgoCD LoadBalancer URL"
  value = "Run: kubectl get svc -n argocd argocd-server"
}