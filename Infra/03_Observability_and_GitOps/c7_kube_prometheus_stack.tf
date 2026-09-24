# Kubernetes Namespace: monitoring
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

# Helm Release: kube-prometheus-stack (Prometheus + Graphana + Alertmanager)
resource "helm_release" "kube_prometheus_stack" {
  depends_on = [ 
    kubernetes_namespace_v1.monitoring,
    aws_eks_addon.kube_state_metrics,
    aws_eks_addon.prometheus_node_exporter
   ]

   name = "kube-prometheus-stack"
   repository = "https://prometheus-community.github.io/helm-charts"
   chart = "kube-prometheus-stack"
   namespace = "monitoring"
   version = "65.1.1"

   wait = true
   timeout = 600
   cleanup_on_fail = true

   # Prometheus
   set = [ 
        {
        name = "prometheus.prometheusSpec.retention"
        value = "7d"
        },

        {
        name = "prometheus.prometheusSpec.resources.requests.cpu"
        value = "200m"
        },

        {
        name = "prometheus.prometheusSpec.resources.requests.memory"
        value = "512Mi"
        },

        {
        name = "prometheus.prometheusSpec.resources.limits.cpu"
        value = "500m"
        },

        {
        name = "prometheus.prometheusSpec.resources.limits.memory"
        value = "1Gi"
        },
        # Discover ServiceMonitors across all namespaces
        {
        name = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
        value = "false"
        },

        {
        name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
        value = "false"
        },
        # Grafana
        {
        name = "grafana.enabled"
        value = "true"
        },

        {
        name = "grafana.adminPassword"
        value = "Admin@123" # Change before production use
        },

        {
        name = "grafana.service.type"
        value = "LoadBalancer"
        },

        {
        name = "grafana.resources.requests.cpu"
        value = "100m"
        },

        {
        name = "grafana.resources.requests.memory"
        value = "128Mi"
        },

        {
        name = "grafana.resources.limits.cpu"
        value = "200m"
        },

        {
        name = "grafana.resources.limits.memory"
        value = "256Mi"
        },
        # node-exporter: use EKS addon, disable chart's own DaemonSet
        {
        name = "prometheus-node-exporter.enabled"
        value = "false"
        },
        # kube-state-metrics: use EKS addon, disable chart's own deployment
        {
        name = "kube-state-metrics.enabled"
        value = "false"
        },
        # Alertmanager: disabled for now
        {
        name = "alertmanager.enabled"
        value = "false"
        }
    ]

    tags = var.tags
}

# Outputs
output "prometheus_helm_metadata" {
  description = "kube-prometheus-stack Helm release metadata"
  value = helm_release.kube_prometheus_stack.metadata
}

output "graphana_service_note" {
  description = "Retrieve Graphana LoadBalancer URL"
  value = "Run: kubectl get svc -n monitoring kube-prometheus-stack-graphana"
}